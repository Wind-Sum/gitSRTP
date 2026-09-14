% ! 三维多平面定位误差扫描 + 多径反射系数对比
%   z 平面 × y-grid × x-grid × gamma 四维扫描
%   合理权衡计算量与覆盖度：5个z层 × 15×19网格 × 4个gamma = 5700点预计~10min

clc; clear; close all;

%% ===================== 参数配置 =====================
room_dim = [10, 8, 3];
freq     = 2.4e9;
Pt       = 0.1;
spacing  = (3e8 / freq) / 2;

step      = 0.5;                    % 网格步长 (m)
snapshots = 20;                     % 快拍数 (扫描用较少的快拍加速)
gamma_list = [0.0, 0.1, 0.2, 0.3]; % 反射系数扫描（>0.3 后算法基本失效）
z_list     = [0.5, 1.0, 1.5, 2.0, 2.5];  % 5个z平面

use_parfor = false;

% 网格
x_range = step:step:(room_dim(1)-step);
y_range = step:step:(room_dim(2)-step);
[X, Y]  = meshgrid(x_range, y_range);
n_grid  = numel(X);
n_gamma = length(gamma_list);
n_z     = length(z_list);
n_total = n_grid * n_gamma * n_z;
fprintf('总扫描点数: %d × %d × %d = %d 点\n', n_grid, n_gamma, n_z, n_total);

%% ===================== 阵列部署 =====================
center1 = [3, 2, room_dim(3)];
PA1     = PhasedArray(center1, spacing, [0, 0, -1], [1, 0, 0]);
p1      = mean(PA1.element_pos, 1)';

center2 = [room_dim(1)-3, room_dim(2)-2, room_dim(3)];
PA2     = PhasedArray(center2, spacing, [0, 0, -1], [1, 0, 0]);
p2      = mean(PA2.element_pos, 1)';

%% ===================== 扫描 =====================
% 四维结果: (n_y × n_x × n_z × n_gamma) for each method
err_music_all = NaN(size(Y,1), size(X,2), n_z, n_gamma);
err_bf_all    = NaN(size(Y,1), size(X,2), n_z, n_gamma);

fprintf('开始四维扫描...\n');
t_start = tic;
point_count = 0;

for g_idx = 1:n_gamma
    gamma = gamma_list(g_idx);
    for iz = 1:n_z
        z_fixed = z_list(iz);
        fprintf('\n=== gamma=%.1f, z=%.1f m ===\n', gamma, z_fixed);
    
    for idx = 1:n_grid
        [iy, ix] = ind2sub(size(X), idx);   % 计算网格 (row, col)
        src_pos = [X(idx), Y(idx), z_fixed];
        
        % REV 快拍
        X1 = zeros(64, snapshots); X2 = zeros(64, snapshots);
        for n = 1:snapshots
            X1(:, n) = rev(PA1, room_dim, src_pos, freq, gamma, Pt);
            X2(:, n) = rev(PA2, room_dim, src_pos, freq, gamma, Pt);
        end
        
        % MUSIC
        [az1, el1] = music_doa(X1, PA1, freq);
        [az2, el2] = music_doa(X2, PA2, freq);
        [~, err_m] = aoa_localize(az1, el1, p1, az2, el2, p2, src_pos);
        err_music_all(iy, ix, iz, g_idx) = err_m;
        
        % BF
        [az1, el1] = beamforming_doa(X1, PA1, freq);
        [az2, el2] = beamforming_doa(X2, PA2, freq);
        [~, err_b] = aoa_localize(az1, el1, p1, az2, el2, p2, src_pos);
        err_bf_all(iy, ix, iz, g_idx) = err_b;
        
        point_count = point_count + 1;
        if mod(point_count, max(1, floor(n_total/40))) == 0
            elapsed = toc(t_start);
            eta = elapsed / point_count * (n_total - point_count);
            fprintf('  总进度: %5d/%d (%.1f%%), 已耗时 %.0f s, ETA %.0f s\n', ...
                point_count, n_total, point_count/n_total*100, elapsed, eta);
        end
    end
    end
end

elapsed_total = toc(t_start);
fprintf('\n扫描完成，总耗时 %.1f 秒 (%.1f 分钟)\n\n', elapsed_total, elapsed_total/60);

%% ===================== 统计汇总 =====================
fprintf('============================================================\n');
fprintf('                   多径扫描统计汇总\n');
fprintf('============================================================\n');
fprintf('%-6s %-6s | %-5s %-7s %-7s %-7s | %-5s %-7s %-7s %-7s\n', ...
    'gamma', 'z(m)', '有效', '均值cm', '中位cm', '最大cm', '有效', '均值cm', '中位cm', '最大cm');
fprintf('----------------------------------------------------------------\n');

for g_idx = 1:n_gamma
    gamma = gamma_list(g_idx);
    for iz = 1:n_z
        z_fixed = z_list(iz);
        
        em = err_music_all(:, :, iz, g_idx); em = em(:);
        eb = err_bf_all(:, :, iz, g_idx);    eb = eb(:);
        vm = isfinite(em); vb = isfinite(eb);
        
        if any(vm)
            fprintf('%-6.1f z=%-4.1f | %-5d %7.1f %7.1f %7.1f | %-5d %7.1f %7.1f %7.1f\n', ...
                gamma, z_fixed, sum(vm), mean(em(vm))*100, median(em(vm))*100, max(em(vm))*100, ...
                sum(vb), mean(eb(vb))*100, median(eb(vb))*100, max(eb(vb))*100);
        end
    end
end
fprintf('============================================================\n');

%% ===================== 可视化 =====================
% 图1: 每z层每gamma的热力图矩阵
n_rows = n_z; n_cols = n_gamma;
figure('Position', [50, 50, 280*n_cols, 220*n_rows], 'Name', '全平面定位误差热力图矩阵');
tlayout = tiledlayout(n_rows, n_cols, 'TileSpacing', 'compact', 'Padding', 'compact');

% 统一色标
all_valid_m = err_music_all(isfinite(err_music_all));
all_valid_b = err_bf_all(isfinite(err_bf_all));
c_max = prctile([all_valid_m(:)*100; all_valid_b(:)*100], 95);

for iz = 1:n_z
    for g_idx = 1:n_gamma
        nexttile;
        em = err_music_all(:,:,iz,g_idx) * 100;  % cm
        em(~isfinite(em)) = NaN;
        contourf(X, Y, em, 15, 'LineColor', 'none');
        xlabel('X (m)'); ylabel('Y (m)');
        title(sprintf('z=%.1f \\gamma=%.1f MUSIC', z_list(iz), gamma_list(g_idx)));
        colormap(gca, jet); caxis([0, c_max]); colorbar;
        axis equal tight;
    end
end
sgtitle(sprintf('REV+MUSIC 定位误差热力图 (步长%.1fm, %d快拍) — 多z平面×多gamma', step, snapshots));

% 图2: 误差随gamma变化的趋势 (所有z层汇总)
figure('Position', [100, 100, 900, 550]);
hold on;
colors_m = lines(n_z); colors_b = lines(n_z);
hs = []; labels = {};

for iz = 1:n_z
    mean_m = zeros(1, n_gamma);
    mean_b = zeros(1, n_gamma);
    for g_idx = 1:n_gamma
        em = err_music_all(:,:,iz,g_idx); em = em(isfinite(em));
        eb = err_bf_all(:,:,iz,g_idx);    eb = eb(isfinite(eb));
        mean_m(g_idx) = mean(em)*100;
        mean_b(g_idx) = mean(eb)*100;
    end
    h1 = plot(gamma_list, mean_m, 'o-', 'Color', colors_m(iz,:), 'LineWidth', 1.8, 'MarkerSize', 8);
    h2 = plot(gamma_list, mean_b, 's--', 'Color', colors_b(iz,:), 'LineWidth', 1.8, 'MarkerSize', 8);
    hs = [hs, h1, h2];
    labels{end+1} = sprintf('MUSIC z=%.1f', z_list(iz));
    labels{end+1} = sprintf('BF    z=%.1f', z_list(iz));
end
xlabel('墙壁反射系数 \gamma'); ylabel('平均定位误差 (cm)');
title(sprintf('多径反射系数对定位精度的影响 (%d~%d快拍, 多z平面对比)', snapshots, snapshots));
grid on; legend(hs, labels, 'Location', 'northwest');

% 图3: 3D散点图 — 所有有效点的误差在空间中的分布 (取gamma=0.2, 最有代表性)
figure('Position', [100, 100, 900, 700], 'Name', '3D空间误差分布');
g_show = find(gamma_list == 0.2, 1);
if isempty(g_show), g_show = 3; end

err_3d = [];
pos_3d = [];
for iz = 1:n_z
    for iy = 1:size(Y,1)
        for ix = 1:size(X,2)
            e = err_music_all(iy, ix, iz, g_show);
            if isfinite(e) && e < 2
                err_3d(end+1) = e * 100;
                pos_3d(end+1, :) = [X(iy,ix), Y(iy,ix), z_list(iz)];
            end
        end
    end
end
scatter3(pos_3d(:,1), pos_3d(:,2), pos_3d(:,3), 40, err_3d, 'filled');
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
title(sprintf('MUSIC 定位误差3D分布 (\\gamma=%.1f, 误差<200cm)', gamma_list(g_show)));
colormap jet; cb = colorbar; ylabel(cb, '误差 (cm)');
view(35, 25); grid on; axis equal;
hold on;
plot3(p1(1), p1(2), p1(3), 'ws', 'MarkerSize', 15, 'MarkerFaceColor', 'w', 'LineWidth', 1.5);
plot3(p2(1), p2(2), p2(3), 'ws', 'MarkerSize', 15, 'MarkerFaceColor', 'w', 'LineWidth', 1.5);
text(p1(1), p1(2), p1(3), 'PA1', 'Color', 'w', 'FontWeight', 'bold');
text(p2(1), p2(2), p2(3), 'PA2', 'Color', 'w', 'FontWeight', 'bold');
hold off;

fprintf('\n可视化完成。\n');
