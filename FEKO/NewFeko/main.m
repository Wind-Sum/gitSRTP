% ! 整合版主脚本：REV + 3D MUSIC + 3D CBF 一键定位
%   输入: FEKO S参数文件 + 坐标文件
%   输出: MUSIC / CBF 定位结果对比
%
%   流程：
%     1. 读取 S 参数 (129端口, Port1=发射, Port2~129=接收)
%     2. REV 算法 → 64个阵元的复数响应 (x2阵列)
%     3. 3D MUSIC 近场搜索 → 定位
%     4. 3D CBF 近场搜索 → 定位
%     5. 对比输出

clc; close all;

%% ===================== 1. 文件路径配置 =====================
s_param_file = '8x8x2_SParameter1.s129p';
out_file     = '8x8x2.out';
inc_file     = 'two_arrays_8x8.inc';

%% ===================== 2. 读取 S 参数 & 提取阵列响应 =====================
fprintf('===== 读取 S 参数文件 =====\n');
sp = sparameters(s_param_file);
S = squeeze(sp.Parameters);

tx_idx = 1;               % Port1: 发射源
num_elements = 64;        % 每个阵列 64 个阵元 (8×8)

% 提取发射端口到所有端口的复数响应
all_resp = S(:, tx_idx);  % (num_elements*2+1) × 1
all_resp(tx_idx) = [];    % 去掉 S11

% 分离两个阵列
array1_raw = all_resp(1:num_elements);
array2_raw = all_resp(num_elements+1:2*num_elements);

fprintf('阵列1响应 (前5): '); disp(array1_raw(1:5).');
fprintf('阵列2响应 (前5): '); disp(array2_raw(1:5).');

%% ===================== 3. REV 算法: 功率 → 复数响应 =====================
fprintf('\n===== REV 相位恢复 =====\n');
phases = [0, pi/2, pi];   % 0°, 90°, 180°
num_angles = length(phases);

% 对阵列1逐阵元施加相移，计算合成功率
power_matrix1 = zeros(num_angles, num_elements);
power_matrix2 = zeros(num_angles, num_elements);

for arr_idx = 1:2
    if arr_idx == 1
        c = array1_raw;
    else
        c = array2_raw;
    end
    
    E_all = sum(c);
    for k = 1:num_elements
        for ang = 1:num_angles
            delta_phi = phases(ang);
            c_rot = c;
            c_rot(k) = c_rot(k) * exp(1j * delta_phi);
            P = abs(sum(c_rot))^2;
            if arr_idx == 1
                power_matrix1(ang, k) = P;
            else
                power_matrix2(ang, k) = P;
            end
        end
    end
end

% REV 解算
array_resp1 = REV_calculate(power_matrix1);
array_resp2 = REV_calculate(power_matrix2);

fprintf('阵列1 REV响应 (前5): '); disp(array_resp1(1:5).');
fprintf('阵列2 REV响应 (前5): '); disp(array_resp2(1:5).');

%% ===================== 4. 读取坐标 =====================
fprintf('\n===== 读取坐标 =====\n');

% 发射源坐标 (从 .out 读 Port1)
coords_src = read_feko_port_coords(out_file);
if isempty(coords_src)
    error('无法从 %s 读取端口坐标', out_file);
end
pos_tx = coords_src(1, :);  % Port1 = 发射源
fprintf('发射源位置: [%.2f, %.2f, %.2f] m\n', pos_tx);

% 阵列阵元坐标 (从 .inc 读，坐标值即房间实际位置)
coords_array = read_inc_coords(inc_file);
if size(coords_array, 1) ~= 2 * num_elements
    warning('.inc 文件阵元数(%d) 不等于预期(%d)', size(coords_array, 1), 2*num_elements);
end

% 分离两个阵列的坐标
coords1 = coords_array(1:num_elements, :);           % 阵列1
coords2 = coords_array(num_elements+1:2*num_elements, :); % 阵列2

fprintf('阵列1 中心: [%.2f, %.2f, %.2f] m\n', mean(coords1, 1));
fprintf('阵列2 中心: [%.2f, %.2f, %.2f] m\n', mean(coords2, 1));

% 合并所有接收阵元 (64+64=128)
pos_rx = [coords1; coords2];

% 复数信号向量 (128×1)
x_complex = [array_resp1, array_resp2].';

%% ===================== 5. 物理参数 =====================
f = 2.4e9;
c = 3e8;
lambda = c / f;

%% ===================== 6. 3D 空间搜索网格 =====================
step  = 0.1;  % 网格步长 (m)，改小精度更高但更慢
x_grid = 0:step:10;
y_grid = 0:step:8;
z_grid = 0:step:3;

n_x = length(x_grid);
n_y = length(y_grid);
n_z = length(z_grid);

fprintf('\n===== 3D 空间谱搜索 (网格 %d×%d×%d = %d 点, 步长 %.1f m) =====\n', ...
    n_x, n_y, n_z, n_x*n_y*n_z, step);

%% ===================== 7. MUSIC 算法 =====================
fprintf('\n--- MUSIC ---\n');
t_music = tic;

% 协方差矩阵 & 特征分解
R = x_complex * x_complex';
[E, D] = eig(R);
[~, idx] = sort(abs(diag(D)), 'descend');
E = E(:, idx);
En = E(:, 2:end);  % 噪声子空间

% 3D 搜索
P_music = zeros(n_x, n_y, n_z);
for ix = 1:n_x
    for iy = 1:n_y
        for iz = 1:n_z
            p_search = [x_grid(ix), y_grid(iy), z_grid(iz)];
            distances = sqrt(sum((pos_rx - p_search).^2, 2));
            a = exp(-1j * 2 * pi * distances / lambda);
            P_music(ix, iy, iz) = 1 / abs(a' * En * En' * a);
        end
    end
end

[~, max_idx] = max(P_music(:));
[ix_m, iy_m, iz_m] = ind2sub(size(P_music), max_idx);
est_music = [x_grid(ix_m), y_grid(iy_m), z_grid(iz_m)];
err_music = norm(est_music - pos_tx);

fprintf('真实位置  : [%.2f, %.2f, %.2f] m\n', pos_tx);
fprintf('MUSIC估计 : [%.2f, %.2f, %.2f] m\n', est_music);
fprintf('MUSIC误差 : %.3f m (%.1f cm)\n', err_music, err_music*100);
fprintf('MUSIC耗时 : %.1f s\n', toc(t_music));

%% ===================== 8. CBF (常规波束形成) =====================
fprintf('\n--- CBF ---\n');
t_cbf = tic;

P_cbf = zeros(n_x, n_y, n_z);
for ix = 1:n_x
    for iy = 1:n_y
        for iz = 1:n_z
            p_search = [x_grid(ix), y_grid(iy), z_grid(iz)];
            distances = sqrt(sum((pos_rx - p_search).^2, 2));
            a = exp(-1j * 2 * pi * distances / lambda);
            P_cbf(ix, iy, iz) = abs(a' * x_complex)^2;
        end
    end
end

[~, max_idx] = max(P_cbf(:));
[ix_b, iy_b, iz_b] = ind2sub(size(P_cbf), max_idx);
est_cbf = [x_grid(ix_b), y_grid(iy_b), z_grid(iz_b)];
err_cbf = norm(est_cbf - pos_tx);

fprintf('真实位置  : [%.2f, %.2f, %.2f] m\n', pos_tx);
fprintf('CBF 估计  : [%.2f, %.2f, %.2f] m\n', est_cbf);
fprintf('CBF 误差  : %.3f m (%.1f cm)\n', err_cbf, err_cbf*100);
fprintf('CBF 耗时  : %.1f s\n', toc(t_cbf));

%% ===================== 9. 结果汇总 =====================
fprintf('\n==================== 结果汇总 ====================\n');
fprintf('真实发射位置: [%.4f, %.4f, %.4f] m\n', pos_tx);
fprintf('REV+MUSIC   : [%.4f, %.4f, %.4f] m  误差: %.2f cm\n', est_music, err_music*100);
fprintf('REV+CBF     : [%.4f, %.4f, %.4f] m  误差: %.2f cm\n', est_cbf, err_cbf*100);

if err_music < err_cbf
    fprintf('>> REV+MUSIC 精度更高, 优势: %.2f cm\n', (err_cbf-err_music)*100);
elseif err_cbf < err_music
    fprintf('>> REV+CBF 精度更高, 优势: %.2f cm\n', (err_music-err_cbf)*100);
else
    fprintf('>> 两方案精度相同\n');
end
fprintf('==================================================\n');

%% ===================== 10. 可视化 =====================
figure('Position', [100, 100, 1300, 500], 'Name', 'FEKO 定位结果', 'Color', 'w');

% MUSIC 热力图
ax1 = subplot(1,2,1);
slice_2d_music = squeeze(P_music(:, :, iz_m))';
imagesc(x_grid, y_grid, slice_2d_music);
set(gca, 'YDir', 'normal');
colormap(ax1, jet);
colorbar;
hold on;
plot(est_music(1), est_music(2), 'p', 'MarkerSize', 18, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'w', 'LineWidth', 1.5);
plot(pos_tx(1), pos_tx(2), '^', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
plot(pos_rx(:,1), pos_rx(:,2), 'o', 'MarkerSize', 3, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'none');
title(sprintf('MUSIC (z=%.2f m, 误差=%.1f cm)', est_music(3), err_music*100), 'FontSize', 12);
xlabel('X (m)'); ylabel('Y (m)');
axis equal tight; grid on;
legend({'MUSIC估计', '真实位置'}, 'Location', 'best');

% CBF 热力图
ax2 = subplot(1,2,2);
slice_2d_cbf = squeeze(P_cbf(:, :, iz_b))';
imagesc(x_grid, y_grid, slice_2d_cbf);
set(gca, 'YDir', 'normal');
colormap(ax2, jet);
colorbar;
hold on;
plot(est_cbf(1), est_cbf(2), 'p', 'MarkerSize', 18, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'w', 'LineWidth', 1.5);
plot(pos_tx(1), pos_tx(2), '^', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
plot(pos_rx(:,1), pos_rx(:,2), 'o', 'MarkerSize', 3, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'none');
title(sprintf('CBF (z=%.2f m, 误差=%.1f cm)', est_cbf(3), err_cbf*100), 'FontSize', 12);
xlabel('X (m)'); ylabel('Y (m)');
axis equal tight; grid on;
legend({'CBF估计', '真实位置'}, 'Location', 'best');

sgtitle('REV + 3D 近场定位 (FEKO 仿真数据)', 'FontSize', 14);
