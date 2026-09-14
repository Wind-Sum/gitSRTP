% ! 扫描定位误差曲面：固定 z 平面，遍历 (x, y) 网格计算两方案定位误差
%
% 性能优化：
%   1. PhasedArray.cal_rev_data 内部预计算镜像源并复用（避免 64 次重复生成）
%   2. REV 快拍数据在 MUSIC 和 BF 间复用
%   3. 可选用 parfor 并行扫描各网格点（需 Parallel Computing Toolbox）

clc; clear; close all;

%% ===================== 参数配置 =====================
room_dim = [10, 8, 3];
freq     = 2.4e9;
gamma    = 0.0;           % 墙壁反射系数（先设 0 验证无多径基线，再逐步加大）
Pt       = 0.1;
spacing  = (3e8 / freq) / 2;

z_fixed   = 1.5;          % 扫描固定高度
step      = 0.5;          % 扫描步长 (m) — 建议 0.5 快速跑通，再用 0.2 精细扫描
snapshots = 20;           % 快拍数
snr_dB    = [];           % SNR (dB)，留空 = 无噪声；设为 30 模拟低噪场景

use_parfor = false;       % 设为 true 以启用并行（需 Parallel Computing Toolbox）

% 扫描范围：网格边界距墙 step（避免信源贴在墙上导致镜像法异常）
x_range = step:step:(room_dim(1)-step);
y_range = step:step:(room_dim(2)-step);
[X, Y]  = meshgrid(x_range, y_range);
n_total = numel(X);

%% ===================== 阵列部署 =====================
% 两天花板阵列：法向量朝下，向房间中部靠拢以增大边角有效孔径
center1 = [3, 2, room_dim(3)];
normal1 = [0, 0, -1];
vec1    = [1, 0, 0];
PA1     = PhasedArray(center1, spacing, normal1, vec1);
p1      = mean(PA1.element_pos, 1)';

center2 = [room_dim(1)-3, room_dim(2)-2, room_dim(3)];
normal2 = [0, 0, -1];
vec2    = [1, 0, 0];
PA2     = PhasedArray(center2, spacing, normal2, vec2);
p2      = mean(PA2.element_pos, 1)';

%% ===================== 扫描 =====================
err_music = zeros(size(X));
err_bf    = zeros(size(X));

fprintf('开始扫描，共 %d 个网格点 (step=%.2f m, parfor=%d, SNR_dB=%s)...\n', ...
    n_total, step, use_parfor, mat2str(snr_dB));
t_start = tic;

if use_parfor
    % ---- 并行模式 ----
    parfor idx = 1:n_total
        src_pos = [X(idx), Y(idx), z_fixed];

        % REV 多快拍（仅计算一次，MUSIC 和 BF 复用）
        X1 = zeros(64, snapshots);
        X2 = zeros(64, snapshots);
        for n = 1:snapshots
            if isempty(snr_dB)
                X1(:, n) = rev(PA1, room_dim, src_pos, freq, gamma, Pt);
                X2(:, n) = rev(PA2, room_dim, src_pos, freq, gamma, Pt);
            else
                X1(:, n) = rev(PA1, room_dim, src_pos, freq, gamma, Pt, 'SNR_dB', snr_dB);
                X2(:, n) = rev(PA2, room_dim, src_pos, freq, gamma, Pt, 'SNR_dB', snr_dB);
            end
        end

        % MUSIC
        [az1, el1] = music_doa(X1, PA1, freq);
        [az2, el2] = music_doa(X2, PA2, freq);
        [~, err_m] = aoa_localize(az1, el1, p1, az2, el2, p2, src_pos);

        % Beamforming（复用同一批 REV 快拍）
        [az1, el1] = beamforming_doa(X1, PA1, freq);
        [az2, el2] = beamforming_doa(X2, PA2, freq);
        [~, err_b] = aoa_localize(az1, el1, p1, az2, el2, p2, src_pos);

        err_music(idx) = err_m;
        err_bf(idx)    = err_b;
    end
else
    % ---- 串行模式 ----
    for idx = 1:n_total
        src_pos = [X(idx), Y(idx), z_fixed];

        % REV 多快拍（仅计算一次，MUSIC 和 BF 复用）
        X1 = zeros(64, snapshots);
        X2 = zeros(64, snapshots);
        for n = 1:snapshots
            if isempty(snr_dB)
                X1(:, n) = rev(PA1, room_dim, src_pos, freq, gamma, Pt);
                X2(:, n) = rev(PA2, room_dim, src_pos, freq, gamma, Pt);
            else
                X1(:, n) = rev(PA1, room_dim, src_pos, freq, gamma, Pt, 'SNR_dB', snr_dB);
                X2(:, n) = rev(PA2, room_dim, src_pos, freq, gamma, Pt, 'SNR_dB', snr_dB);
            end
        end

        % MUSIC
        [az1, el1] = music_doa(X1, PA1, freq);
        [az2, el2] = music_doa(X2, PA2, freq);
        [~, err_m] = aoa_localize(az1, el1, p1, az2, el2, p2, src_pos);
        err_music(idx) = err_m;

        % Beamforming（复用同一批 REV 快拍）
        [az1, el1] = beamforming_doa(X1, PA1, freq);
        [az2, el2] = beamforming_doa(X2, PA2, freq);
        [~, err_b] = aoa_localize(az1, el1, p1, az2, el2, p2, src_pos);
        err_bf(idx) = err_b;

        % 进度报告（每 5% 输出一次）
        report_interval = max(1, floor(n_total / 20));
        if mod(idx, report_interval) == 0
            elapsed = toc(t_start);
            eta = elapsed / idx * (n_total - idx);
            fprintf('  进度: %5d / %d (%.1f%%),  已耗时 %.1f s,  ETA %.1f s\n', ...
                idx, n_total, idx/n_total*100, elapsed, eta);
        end
    end
end

elapsed_total = toc(t_start);
fprintf('扫描完成，总耗时 %.1f 秒 (平均 %.2f s/点)\n\n', elapsed_total, elapsed_total/n_total);

%% ===================== 统计汇总 =====================
fprintf('========== 误差统计 ==========\n');
valid_m = isfinite(err_music);
valid_b = isfinite(err_bf);
fprintf('MUSIC:   有效点 %d/%d, 均值=%.2f cm, 中位数=%.2f cm, 最大=%.2f cm\n', ...
    sum(valid_m(:)), n_total, mean(err_music(valid_m))*100, ...
    median(err_music(valid_m))*100, max(err_music(valid_m))*100);
fprintf('BF:      有效点 %d/%d, 均值=%.2f cm, 中位数=%.2f cm, 最大=%.2f cm\n', ...
    sum(valid_b(:)), n_total, mean(err_bf(valid_b))*100, ...
    median(err_bf(valid_b))*100, max(err_bf(valid_b))*100);

%% ===================== 可视化 =====================
% 过滤病态几何点
err_music_plot = err_music; err_music_plot(~isfinite(err_music_plot)) = NaN;
err_bf_plot    = err_bf;    err_bf_plot(~isfinite(err_bf_plot))       = NaN;

% 自动切换单位
% 获取有效值来确定单位
all_valid = [err_music_plot(isfinite(err_music_plot)); err_bf_plot(isfinite(err_bf_plot))];
if ~isempty(all_valid) && max(all_valid) < 1
    err_music_plot = err_music_plot * 100;
    err_bf_plot    = err_bf_plot    * 100;
    unit = 'cm';
else
    unit = 'm';
end

figure('Position', [100, 100, 1300, 520]);

% --- 左图：REV + MUSIC ---
ax1 = subplot(1,2,1);
contourf(X, Y, err_music_plot, 20, 'LineColor', 'none');
xlabel('X (m)'); ylabel('Y (m)');
title(sprintf('REV + MUSIC 定位误差 (%s)', unit));
colormap(ax1, jet);
caxis([0, prctile(err_music_plot(isfinite(err_music_plot)), 95)]);
cb1 = colorbar; ylabel(cb1, sprintf('误差 (%s)', unit));
hold on; plot(p1(1), p1(2), 'ws', 'MarkerSize', 12, 'MarkerFaceColor', 'w', 'LineWidth', 1);
plot(p2(1), p2(2), 'ws', 'MarkerSize', 12, 'MarkerFaceColor', 'w', 'LineWidth', 1);
hold off;
axis equal tight;

% --- 右图：REV + Beamforming ---
ax2 = subplot(1,2,2);
contourf(X, Y, err_bf_plot, 20, 'LineColor', 'none');
xlabel('X (m)'); ylabel('Y (m)');
title(sprintf('REV + Beamforming 定位误差 (%s)', unit));
colormap(ax2, jet);
caxis([0, prctile(err_bf_plot(isfinite(err_bf_plot)), 95)]);
cb2 = colorbar; ylabel(cb2, sprintf('误差 (%s)', unit));
hold on; plot(p1(1), p1(2), 'ws', 'MarkerSize', 12, 'MarkerFaceColor', 'w', 'LineWidth', 1);
plot(p2(1), p2(2), 'ws', 'MarkerSize', 12, 'MarkerFaceColor', 'w', 'LineWidth', 1);
hold off;
axis equal tight;

sgtitle(sprintf('定位误差热力图 (z = %.1f m, 步长 = %.1f m, 快拍 = %d)', z_fixed, step, snapshots));
