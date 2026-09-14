%% 扫描定位误差曲面
% 源位置：z=1.5 固定，x 范围 0~10，y 范围 0~8，步长 0.1 米

step=1;
x_range = 0.1:step:9.9;
y_range = 0.1:step:7.9;
[X, Y] = meshgrid(x_range, y_range);
Z = 1.5;   % 固定高度

% 预分配误差矩阵
err_music = zeros(size(X));
err_bf    = zeros(size(X));

fprintf('开始扫描，共 %d 个点...\n', numel(X));
tic;
for i = 1:numel(X)
    pos = [X(i), Y(i), Z];
    [err_music(i), err_bf(i)] = compute_error(pos);
    if mod(i, 200) == 0
        fprintf('已完成 %d / %d 点，耗时 %.1f 秒\n', i, numel(X), toc);
    end
end
fprintf('扫描完成，总耗时 %.1f 秒\n', toc);

%% 设定颜色轴上限（例如取误差的 95% 分位数）
max_err_music = prctile(err_music(:), 95);
max_err_bf    = prctile(err_bf(:), 95);
% 也可手动指定一个合理的上限，如 0.5 米
% max_err_music = 0.5;
% max_err_bf = 0.5;

figure;
subplot(1,2,1);
surf(X, Y, err_music, 'EdgeColor', 'none');
clim([0, max_err_music]);   % 限制颜色映射范围
zlim([0, max_err_music]);    % 限制 Z 轴显示范围（可选）
xlabel('x (m)'); ylabel('y (m)'); zlabel('误差 (m)');
title('REV + MUSIC 定位误差');
colorbar;
view(3);

subplot(1,2,2);
surf(X, Y, err_bf, 'EdgeColor', 'none');
clim([0, max_err_bf]);
zlim([0, max_err_bf]);
xlabel('x (m)'); ylabel('y (m)'); zlabel('误差 (m)');
title('REV + Beamforming 定位误差');
colorbar;
view(3);

sgtitle(sprintf('定位误差曲面 (z=%.1f m, 网格步长 %.1f m)', Z, step));