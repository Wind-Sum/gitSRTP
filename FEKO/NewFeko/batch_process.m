% ! 批量处理 FEKO S 参数 → REV + MUSIC + CBF 定位汇总
%
%  运行方式：
%   1. 先跑完所有 FEKO 仿真（run_all.bat 或 gen_multi_pre.m）
%   2. 在本目录运行本脚本
%   3. 输出汇总表格 + 误差热力图

clc; close all;

%% ===================== 加载位置参数 =====================
if ~isfile('source_positions.mat')
    error('请先运行 gen_multi_pre.m 生成 source_positions.mat');
end
load('source_positions.mat', 'positions', 'x_list', 'y_list', 'z_list', 'n_total');

%% ===================== 物理常量 =====================
num_elements = 64;
phases = [0, pi/2, pi];
num_angles = length(phases);
f = 2.4e9;
c = 3e8;
lambda = c / f;
tx_idx = 1;

%% ===================== 阵列坐标 (共用) =====================
coords_src = read_feko_port_coords('8x8x2.out');
if isempty(coords_src)
    warning('无法从 8x8x2.out 读取坐标, 使用 gen_multi_pre 中定义的参考位置');
    pos_tx_ref = [5, 4, 1.5];
else
    pos_tx_ref = coords_src(1, :);
end

coords_array = read_inc_coords('two_arrays_8x8.inc');
coords1 = coords_array(1:num_elements, :);
coords2 = coords_array(num_elements+1:2*num_elements, :);
pos_rx = [coords1; coords2];

%% ===================== 搜索网格 =====================
step = 0.2;
x_grid = 0:step:10;
y_grid = 0:step:8;
z_grid = 0:step:3;
[n_x, n_y, n_z] = deal(length(x_grid), length(y_grid), length(z_grid));

fprintf('===== 批量处理 %d 个位置 (网格 %d×%d×%d = %d 点) =====\n\n', ...
    n_total, n_x, n_y, n_z, n_x*n_y*n_z);

%% ===================== 逐位置处理 =====================
err_music_all = zeros(n_total, 1);
err_cbf_all    = zeros(n_total, 1);
est_music_all  = zeros(n_total, 3);
est_cbf_all    = zeros(n_total, 3);

for idx = 1:n_total
    s_file = sprintf('8x8x2_pos%d_SParameter1.s129p', idx);
    
    if ~isfile(s_file)
        fprintf('[%3d/%3d] 跳过: S参数文件不存在 (%s)\n', idx, n_total, s_file);
        err_music_all(idx) = NaN;
        err_cbf_all(idx)    = NaN;
        continue;
    end
    
    fprintf('[%3d/%3d] 处理 (%.1f, %.1f, %.1f) ... ', idx, n_total, positions(idx, :));
    t_start = tic;
    
    try
        % 读取 S 参数
        sp = sparameters(s_file);
        S = squeeze(sp.Parameters);
        all_resp = S(:, tx_idx);
        all_resp(tx_idx) = [];
        
        array1_raw = all_resp(1:num_elements);
        array2_raw = all_resp(num_elements+1:2*num_elements);
        
        % REV 三功率
        power_m1 = zeros(num_angles, num_elements);
        power_m2 = zeros(num_angles, num_elements);
        for arr_idx = 1:2
            c = array1_raw; if arr_idx == 2, c = array2_raw; end
            E_all = sum(c);
            for k = 1:num_elements
                for ang_idx = 1:num_angles
                    c_rot = c;
                    c_rot(k) = c_rot(k) * exp(1j * phases(ang_idx));
                    P = abs(sum(c_rot))^2;
                    if arr_idx == 1, power_m1(ang_idx, k) = P;
                    else, power_m2(ang_idx, k) = P; end
                end
            end
        end
        
        array_resp1 = REV_calculate(power_m1);
        array_resp2 = REV_calculate(power_m2);
        x_complex = [array_resp1, array_resp2].';
        
        pos_tx = positions(idx, :);
        
        % ---- MUSIC ----
        R = x_complex * x_complex';
        [E, D] = eig(R);
        [~, s_idx] = sort(abs(diag(D)), 'descend');
        En = E(:, s_idx(2:end));
        
        P_music = zeros(n_x, n_y, n_z);
        for ix = 1:n_x
            for iy = 1:n_y
                for iz = 1:n_z
                    p_s = [x_grid(ix), y_grid(iy), z_grid(iz)];
                    dists = sqrt(sum((pos_rx - p_s).^2, 2));
                    a_vec = exp(-1j * 2 * pi * dists / lambda);
                    P_music(ix, iy, iz) = 1 / abs(a_vec' * En * En' * a_vec);
                end
            end
        end
        [~, mi] = max(P_music(:));
        [imx, imy, imz] = ind2sub(size(P_music), mi);
        est_m = [x_grid(imx), y_grid(imy), z_grid(imz)];
        err_m = norm(est_m - pos_tx);
        
        % ---- CBF ----
        P_cbf = zeros(n_x, n_y, n_z);
        for ix = 1:n_x
            for iy = 1:n_y
                for iz = 1:n_z
                    p_s = [x_grid(ix), y_grid(iy), z_grid(iz)];
                    dists = sqrt(sum((pos_rx - p_s).^2, 2));
                    a_vec = exp(-1j * 2 * pi * dists / lambda);
                    P_cbf(ix, iy, iz) = abs(a_vec' * x_complex)^2;
                end
            end
        end
        [~, bi] = max(P_cbf(:));
        [ibx, iby, ibz] = ind2sub(size(P_cbf), bi);
        est_b = [x_grid(ibx), y_grid(iby), z_grid(ibz)];
        err_b = norm(est_b - pos_tx);
        
        err_music_all(idx) = err_m;
        err_cbf_all(idx)    = err_b;
        est_music_all(idx, :)  = est_m;
        est_cbf_all(idx, :)     = est_b;
        
        fprintf('MUSIC=%.1f cm  CBF=%.1f cm (%.1f s)\n', err_m*100, err_b*100, toc(t_start));
        
    catch ME
        fprintf('错误: %s\n', ME.message);
        err_music_all(idx) = NaN;
        err_cbf_all(idx)    = NaN;
    end
end

%% ===================== 汇总输出 =====================
fprintf('\n==================== 批量定位汇总 ====================\n');
fprintf('共 %d 个位置, 有效点: MUSIC %d, CBF %d\n', ...
    n_total, sum(isfinite(err_music_all)), sum(isfinite(err_cbf_all)));
fprintf('%-6s %-6s %-6s %-8s %-8s %-8s %-8s\n', ...
    'X', 'Y', 'Z', 'MUSIC(cm)', 'CBF(cm)', 'Δ(cm)', '优胜');
fprintf('----------------------------------------------------\n');

valid_m = isfinite(err_music_all);
valid_b = isfinite(err_cbf_all);

for i = 1:n_total
    if valid_m(i) && valid_b(i)
        delta = (err_music_all(i) - err_cbf_all(i)) * 100;
        if delta > 0.1
            winner = 'CBF';
        elseif delta < -0.1
            winner = 'MUSIC';
        else
            winner = 'TIE';
        end
        fprintf('%-6.1f %-6.1f %-6.1f %-8.1f %-8.1f %-+8.1f %-8s\n', ...
            positions(i,1), positions(i,2), positions(i,3), ...
            err_music_all(i)*100, err_cbf_all(i)*100, delta, winner);
    elseif valid_m(i)
        fprintf('%-6.1f %-6.1f %-6.1f %-8.1f %-8s\n', ...
            positions(i,:), err_music_all(i)*100, 'N/A(CBF)');
    end
end
fprintf('----------------------------------------------------\n');

if any(valid_m)
    fprintf('MUSIC: 均值=%.1f cm  中位=%.1f cm  最大=%.1f cm\n', ...
        mean(err_music_all(valid_m))*100, ...
        median(err_music_all(valid_m))*100, ...
        max(err_music_all(valid_m))*100);
end
if any(valid_b)
    fprintf('CBF:   均值=%.1f cm  中位=%.1f cm  最大=%.1f cm\n', ...
        mean(err_cbf_all(valid_b))*100, ...
        median(err_cbf_all(valid_b))*100, ...
        max(err_cbf_all(valid_b))*100);
end

%% ===================== 保存结果 =====================
save('batch_results.mat', 'positions', 'err_music_all', 'err_cbf_all', ...
    'est_music_all', 'est_cbf_all', 'x_list', 'y_list', 'z_list');
fprintf('\n结果已保存到 batch_results.mat\n');

%% ===================== 导出文本汇总 =====================
fid = fopen('results_summary.txt', 'w');
fprintf(fid, '===== FEKO 多点定位汇总 =====\n');
fprintf(fid, '有效点: MUSIC=%d, CBF=%d\n\n', ...
    sum(isfinite(err_music_all)), sum(isfinite(err_cbf_all)));
fprintf(fid, 'MUSIC: 均值=%.1f cm  中位=%.1f cm  最大=%.1f cm  最小=%.1f cm\n', ...
    mean(err_music_all(valid_m))*100, median(err_music_all(valid_m))*100, ...
    max(err_music_all(valid_m))*100, min(err_music_all(valid_m))*100);
fprintf(fid, 'CBF:   均值=%.1f cm  中位=%.1f cm  最大=%.1f cm  最小=%.1f cm\n\n', ...
    mean(err_cbf_all(valid_b))*100, median(err_cbf_all(valid_b))*100, ...
    max(err_cbf_all(valid_b))*100, min(err_cbf_all(valid_b))*100);
fprintf(fid, '%-4s %-7s %-7s %-7s %-8s %-8s\n', 'No.', 'X', 'Y', 'Z', 'MUSICcm', 'CBFcm');
for i = 1:size(positions,1)
    fprintf(fid, '%-4d %-7.2f %-7.2f %-7.2f %-8.1f %-8.1f\n', i, positions(i,:), ...
        err_music_all(i)*100, err_cbf_all(i)*100);
end
fclose(fid);
fprintf('文本汇总已导出到 results_summary.txt\n');

%% ===================== 可视化 =====================
figure('Position', [50, 50, 1400, 500], 'Name', '多点定位误差', 'Color', 'w');

% 为每个 z 层绘制误差对比
unique_z = unique(positions(:,3));
n_z_plot = length(unique_z);

for iz = 1:n_z_plot
    z_val = unique_z(iz);
    mask = abs(positions(:,3) - z_val) < 0.01;
    
    % MUSIC
    subplot(2, n_z_plot, iz);
    em = err_music_all(mask) * 100;
    px = positions(mask, 1);
    py = positions(mask, 2);
    if any(isfinite(em))
        scatter(px, py, 120, em, 'filled', 's');
        xlabel('X (m)'); ylabel('Y (m)');
        title(sprintf('MUSIC z=%.1f (均值 %.1f cm)', z_val, mean(em(isfinite(em)))));
        colormap(gca, jet); colorbar; caxis([0, max(200, prctile(em(isfinite(em)), 95))]);
        axis equal tight; grid on;
    end
    
    % CBF
    subplot(2, n_z_plot, n_z_plot + iz);
    eb = err_cbf_all(mask) * 100;
    if any(isfinite(eb))
        scatter(px, py, 120, eb, 'filled', 's');
        xlabel('X (m)'); ylabel('Y (m)');
        title(sprintf('CBF z=%.1f (均值 %.1f cm)', z_val, mean(eb(isfinite(eb)))));
        colormap(gca, jet); colorbar; caxis([0, max(200, prctile(eb(isfinite(eb)), 95))]);
        axis equal tight; grid on;
    end
end

sgtitle('FEKO 多点定位误差 (UTD + 混凝土墙)', 'FontSize', 14);
