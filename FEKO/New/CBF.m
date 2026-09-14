% ==========================================
% 独立脚本：利用 main.m 输出的 REV 结果进行 3D 常规波束形成（CBF）定位
% 先运行你的 main.m，确保工作区已有 array1_information 等变量
% ==========================================

clc; close all; 
disp('检测到 main.m 运行结果，正在启动 3D 常规波束形成算法...');

%% 1. 提取 main.m 传过来的数据
% 将两个 4x16 的信息矩阵拼接，提取复数信号 (确保是 32x1 的列向量)
x_complex = [array1_information(1, :), array2_information(1, :)].'; 

% 提取 32 个接收阵元的三维坐标 (转置为 32x3 的矩阵: x, y, z)
pos_rx = [array1_information(2:4, :), array2_information(2:4, :)].'; 

% 从 coords 中提取真实的发射源坐标 (Port1)，用于最后计算误差
pos_tx = coords(1, :); 

%% 2. 基础物理参数
f = 2.4e9;      % 频率 2.4 GHz (请确保与 FEKO 仿真频率一致)
c = 3e8;        % 光速
lambda = c / f; % 波长

%% 3. 房间 3D 近场网格搜索
disp('开始进行 3D 空间 CBF 谱搜索...');
step = 0.1; % 网格步长(米)，0.1米精度
x_grid = 0:step:10;
y_grid = 0:step:8;
z_grid = 0:step:3;

P_bf = zeros(length(x_grid), length(y_grid), length(z_grid));

% 遍历整个房间的三维空间
for ix = 1:length(x_grid)
    for iy = 1:length(y_grid)
        for iz = 1:length(z_grid)
            p_search = [x_grid(ix), y_grid(iy), z_grid(iz)];
            
            % 计算当前搜索点到 32 个接收阵元的欧氏距离
            distances = sqrt(sum((pos_rx - p_search).^2, 2));
            
            % 构造 3D 近场导向矢量 (Steering Vector)
            a = exp(-1j * 2 * pi * distances / lambda);
            
            % 常规波束形成输出功率：|a^H * x|^2
            P_bf(ix, iy, iz) = abs(a' * x_complex)^2;
        end
    end
end

%% 4. 找出最大谱峰，锁定最终坐标
[~, max_idx] = max(P_bf(:));
[idx_x, idx_y, idx_z] = ind2sub(size(P_bf), max_idx);

est_x = x_grid(idx_x);
est_y = y_grid(idx_y);
est_z = z_grid(idx_z);

fprintf('\n========================================\n');
fprintf('FEKO 真实发射位置: x = %.2f, y = %.2f, z = %.2f\n', pos_tx(1), pos_tx(2), pos_tx(3));
fprintf('CBF 估算位置    : x = %.2f, y = %.2f, z = %.2f\n', est_x, est_y, est_z);
fprintf('绝对定位误差    : %.3f 米\n', norm([est_x, est_y, est_z] - pos_tx));
fprintf('==========================================\n');

%% 5. 绘制目标所在高度的 2D 切片热力图
figure('Name', 'CBF 3D 定位热力图', 'Color', 'w');
slice_2d = squeeze(P_bf(:, :, idx_z))';

% 绘制热力图
imagesc(x_grid, y_grid, slice_2d);
set(gca, 'YDir', 'normal'); % 让 Y 轴正方向朝上
colormap('jet');
c = colorbar;
c.Label.String = '波束形成输出功率 (|a^H x|^2)';
hold on;

% 标记估算点（红星）和真实点（白色三角）
h1 = plot(est_x, est_y, 'p', 'MarkerSize', 18, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'w', 'LineWidth', 1.5); 
h2 = plot(pos_tx(1), pos_tx(2), '^', 'MarkerSize', 10, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% 画出两个接收天线阵列的位置（小白点）
plot(pos_rx(:,1), pos_rx(:,2), 'o', 'MarkerSize', 4, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'none');

title(sprintf('近场 3D 常规波束形成空间谱 (Z = %.2f m)', est_z), 'FontSize', 14);
xlabel('X 轴 (m)', 'FontSize', 12); 
ylabel('Y 轴 (m)', 'FontSize', 12);
legend([h1, h2], {'CBF 估算位置', 'FEKO 真实位置'}, 'Location', 'best', 'FontSize', 11);
grid on;