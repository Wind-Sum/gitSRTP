% ! 批量生成 FEKO .pre 文件 —— 多点发射源仿真
%
%  对网格中每个源位置生成一个 .pre 文件，用 TG 将 source_dipole
%  移动到目标位置，其余配置（阵列、UTD、S参数）保持不变。
%
%  运行方式：
%   1. 在 MATLAB 中修改下方 GRID 参数
%   2. 运行本脚本 → 生成 N 个 .pre + run_all.bat
%   3. 在终端执行 run_all.bat → 批量 FEKO 求解

clc; clear;

%% ===================== 网格参数 (可修改) =====================
% 源位置网格 — 参考 MATLAB 扫描参数，这里用稀疏采样
% 余弦间距 (边角密集, 中间稀疏) — 4x×5y×5z = 100点
x_list = 0.5 + 4.5 * (1 - cos(linspace(0, pi, 4)));   % 0.5, 2.75, 7.25, 9.5
y_list = 0.5 + 3.5 * (1 - cos(linspace(0, pi, 5)));   % 0.5, 1.53, 4.0, 6.47, 7.5
z_list = 0.3 + 1.2 * (1 - cos(linspace(0, pi, 5)));   % 0.3, 0.65, 1.5, 2.35, 2.7

% 源参考位置 (source_dipole 在 CADFEKO 中的原始坐标)
src_ref = [5, 4, 1.5];

% FEKO 公共文件
mesh_file = '8x8x2.cfm';
inc_file  = 'two_arrays_8x8.inc';

%% ===================== 生成所有 .pre 文件 =====================
[X, Y, Z] = meshgrid(x_list, y_list, z_list);
positions = [X(:), Y(:), Z(:)];
n_total = size(positions, 1);

fprintf('共 %d 个源位置 (%d x × %d y × %d z)\n', ...
    n_total, length(x_list), length(y_list), length(z_list));

% 生成 run_all.bat
bat_fid = fopen('run_all.bat', 'w');
fprintf(bat_fid, '@echo off\r\n');
fprintf(bat_fid, 'echo ===== FEKO 多点批量仿真 (%d 个位置) =====\r\n\r\n', n_total);

for i = 1:n_total
    tx = positions(i, 1);
    ty = positions(i, 2);
    tz = positions(i, 3);
    
    % 生成 .pre 文件名
    pre_name = sprintf('8x8x2_pos%d.pre', i);
    
    % 生成 .pre 内容
    gen_single_pre(pre_name, mesh_file, inc_file, src_ref, [tx, ty, tz]);
    
    % 添加到批处理脚本
    fprintf(bat_fid, 'echo [%%date%% %%time%%] 位置 %d/%d: (%.2f, %.2f, %.2f)\r\n', ...
        i, n_total, tx, ty, tz);
    fprintf(bat_fid, ...
        'D:\\Software\\FEKO2022\\feko\\bin\\runfeko.exe %s\r\n', pre_name);
    fprintf(bat_fid, 'if %%errorlevel%% neq 0 echo ERROR at position %d  && pause\r\n\r\n', i);
end

fprintf(bat_fid, 'echo ===== 全部完成 =====\r\n');
fprintf(bat_fid, 'pause\r\n');
fclose(bat_fid);

fprintf('\n已生成 %d 个 .pre 文件 + run_all.bat\n', n_total);
fprintf('源位置参考: (%.1f, %.1f, %.1f) m\n', src_ref);
fprintf('请在终端运行: run_all.bat\n');

% 保存位置参数供后处理使用
save('source_positions.mat', 'positions', 'x_list', 'y_list', 'z_list', 'src_ref', 'n_total');
fprintf('位置参数已保存到 source_positions.mat\n');


%% ===================== 子函数: 生成单个 .pre =====================
function gen_single_pre(filename, mesh_file, inc_file, src_ref, target)
% 参数:
%   filename - 输出 .pre 文件名
%   mesh_file - .cfm 网格文件
%   inc_file  - 阵列坐标 .inc 文件
%   src_ref   - source_dipole 原始位置 [x0, y0, z0]
%   target    - 目标源位置 [tx, ty, tz]

    tx = target(1); ty = target(2); tz = target(3);
    
    % 计算平移量 (目标 - 原始)
    dx = tx - src_ref(1);
    dy = ty - src_ref(2);
    dz = tz - src_ref(3);

    fid = fopen(filename, 'w');
    if fid == -1
        error('无法创建文件: %s', filename);
    end

    % 导入网格
    fwrite_str(fid, '** Import mesh model\n');
    fwrite_str(fid, 'IN   8 1055  "%s"\n', mesh_file);
    fwrite_str(fid, '\n');

    % 阵列复制 (128个阵元)
    fwrite_str(fid, '** Generate the array (128 elements)\n');
    fwrite_str(fid, '!!for #i=1 to 128 \n');
    fwrite_str(fid, '#x=fileread("%s",#i+1,1)+1\n', inc_file);
    fwrite_str(fid, '#y=fileread("%s",#i+1,2)\n', inc_file);
    fwrite_str(fid, '#z=fileread("%s",#i+1,3)\n', inc_file);
    fwrite_str(fid, 'TG:1 : dipole.Wire1 : dipole.Wire1 : #i : 2 : : : : #x : #y : #z \n');
    fwrite_str(fid, 'TG:1 : dipole.Wire1.Port1 : dipole.Wire1.Port1 : #i : 2 : : : : #x : #y : #z \n');
    fwrite_str(fid, '!!next\n');
    fwrite_str(fid, '\n');

    % 检查是否为参考点 (平移量≈0)
    is_ref = (abs(dx) < 1e-4 && abs(dy) < 1e-4 && abs(dz) < 1e-4);
    if is_ref
        src_port_label = 'source_dipole.SWire1.SPort1';
    else
        src_port_label = 'source_dipole.SWire1.SPort100';
    end

    % 发射源移动到目标位置 (TG索引=99, 参考点跳过TG)
    if ~is_ref
        fwrite_str(fid, '** Move source to target position\n');
        fwrite_str(fid, '#sx = %.6f\n', dx);
        fwrite_str(fid, '#sy = %.6f\n', dy);
        fwrite_str(fid, '#sz = %.6f\n', dz);
        fwrite_str(fid, 'TG:1 : source_dipole.SWire1 : source_dipole.SWire1 : 99 : 2 : : : : #sx : #sy : #sz \n');
        fwrite_str(fid, 'TG:1 : source_dipole.SWire1.SPort1 : source_dipole.SWire1.SPort1 : 99 : 2 : : : : #sx : #sy : #sz \n');
        fwrite_str(fid, '\n');
    else
        fwrite_str(fid, '** Source at reference position (no TG needed)\n');
        fwrite_str(fid, '\n');
    end

    % UTD 参数
    fwrite_str(fid, '** UTD parameters\n');
    fwrite_str(fid, 'UT: 1 :  : 0 : 0 : 7\n');
    fwrite_str(fid, '\n');

    % FEKO 求解参数
    fwrite_str(fid, '** Feko solution parameters\n');
    fwrite_str(fid, 'FP: 0 : 0\n');
    fwrite_str(fid, '\n');

    % 几何结束
    fwrite_str(fid, '** End of geometry\n');
    fwrite_str(fid, 'EG: 1 : 0 : 0 :  :  : 1e-06 :  :  :  :  :  :  : 1\n');
    fwrite_str(fid, '\n');

    % 求解控制
    fwrite_str(fid, '** Solution control\n');
    fwrite_str(fid, 'PS: 0 : 0 : 3 : 1 :  : 1\n');
    fwrite_str(fid, 'CG: -1 :  : -1\n');
    fwrite_str(fid, '\n');

    % 介质和涂层 (混凝土墙)
    fwrite_str(fid, '** Set medium properties, coatings and skin effects\n');
    fwrite_str(fid, 'DI: Concrete : 0 : -1 :  :  : 5.5 :  :  :  : 0.2 : 1000\n');
    fwrite_str(fid, 'DI: 0 :  : -1 :  :  : 1 :  :  :  : 0 : 1000\n');
    fwrite_str(fid, 'DL: Concrete_Wall : 0 : 1 : Concrete :  : 0.3\n');
    fwrite_str(fid, 'SK: Rectangle1.Face1 : 4 : -1 : Concrete_Wall\n');
    fwrite_str(fid, 'SK: Rectangle2.Face2 : 4 : -1 : Concrete_Wall\n');
    fwrite_str(fid, 'SK: Rectangle3.Face3 : 4 : -1 : Concrete_Wall\n');
    fwrite_str(fid, 'SK: Rectangle4.Face4 : 4 : -1 : Concrete_Wall\n');
    fwrite_str(fid, 'SK: Rectangle5.Face5 : 4 : -1 : Concrete_Wall\n');
    fwrite_str(fid, 'SK: Rectangle6.Face6 : 4 : -1 : Concrete_Wall\n');
    fwrite_str(fid, '\n');

    % 源功率
    fwrite_str(fid, '** Source power\n');
    fwrite_str(fid, 'PW: 0\n');
    fwrite_str(fid, '\n');

    % StandardConfiguration1
    fwrite_str(fid, '** StandardConfiguration1\n');
    fwrite_str(fid, '** Set frequency\n');
    fwrite_str(fid, 'FR:  :  :  :  :  : 2400000000\n');
    fwrite_str(fid, '\n');
    fwrite_str(fid, 'A1: 0 : %s : 0 :  :  : 1 : 0 :  :  :  : 50   ** Source at (%.1f,%.1f,%.1f)\n', src_port_label, tx, ty, tz);
    fwrite_str(fid, '\n');
    fwrite_str(fid, 'NC: StandardConfiguration1\n');
    fwrite_str(fid, 'DA:  :  :  :  : 0\n');
    fwrite_str(fid, '\n');
    fwrite_str(fid, 'OS:0\n');
    fwrite_str(fid, '\n');

    % SParameterConfiguration1
    fwrite_str(fid, '** SParameterConfiguration1\n');
    fwrite_str(fid, '\n');
    fwrite_str(fid, 'NC: SParameterConfiguration1\n');
    fwrite_str(fid, 'DA:  :  :  :  : 0\n');
    fwrite_str(fid, '\n');
    fwrite_str(fid, '** S-parameters: SParameter1\n');
    fwrite_str(fid, 'DA:  :  :  :  : 0 : 1\n');
    fwrite_str(fid, 'A1: 0 : %s : 0 :  :  : 1 : 0 :  :  :  : 50   ** TxPort\n', src_port_label);
    fwrite_str(fid, '!!for #i=2 to 129\n');
    fwrite_str(fid, 'A1: 1 : dipole.Wire1.Port#i : 0 :  :  : 0 : 0 :  :  :  : 50   ** |Port#i\n');
    fwrite_str(fid, '!!next\n');
    fwrite_str(fid, 'SP: 1 : 1   ** SParameter1\n');
    fwrite_str(fid, 'DA: 0\n');
    fwrite_str(fid, '\n');

    % 结束
    fwrite_str(fid, '** End of file\n');
    fwrite_str(fid, 'EN\n');

    fclose(fid);
end

function fwrite_str(fid, format, varargin)
    % 辅助: 写入字符串, 自动处理换行
    fprintf(fid, format, varargin{:});
end
