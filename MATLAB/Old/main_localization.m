clc; clear; close all;

%% 1. 系统参数设置
room_dim = [10, 8, 3];  
freq = 2.4e9;           
gamma = 0.8;              % 先用0测试算法本身精度，测试成功后再加反射
Pt = 0.1;               
spacing = (3e8/freq)/2; 

true_source_pos = [3.5, 4, 2]; 

%% 2. 阵列部署
center1 = [0.5, 0.5, 1.5]; 
normal1 = [1, 1, 0];       
vec1_v = [0, 0, 1];        
PA1 = Phased_array(center1, spacing, normal1, vec1_v);

center2 = [9.5, 7.5, 1.5];
normal2 = [-1, -1, 0];
vec2_v = [0, 0, 1];
PA2 = Phased_array(center2, spacing, normal2, vec2_v);

%% 3. 多快拍数据采集 (解决结果不稳定)
fprintf('正在采集多快拍数据以消除噪声...\n');
snapshots = 50; % 收集50次数据求平均
R1 = zeros(64, 64);
R2 = zeros(64, 64);

for snap = 1:snapshots
    x1 = get_music_data(PA1, room_dim, true_source_pos, freq, gamma, Pt, 20);
    x2 = get_music_data(PA2, room_dim, true_source_pos, freq, gamma, Pt, 20);
    R1 = R1 + (x1 * x1');
    R2 = R2 + (x2 * x2');
end
R1 = R1 / snapshots; % 获取稳定的协方差矩阵
R2 = R2 / snapshots;

%% 4. 运行 MUSIC 算法
fprintf('正在运行 MUSIC 算法...\n');
[az1, el1] = run_music_doa(R1, PA1, freq);
[az2, el2] = run_music_doa(R2, PA2, freq);

fprintf('阵列1 估计方向: 方位角=%.2f°, 俯仰角=%.2f°\n', az1, el1);
fprintf('阵列2 估计方向: 方位角=%.2f°, 俯仰角=%.2f°\n', az2, el2);

%% 5. 双站交叉定位
u1 = [cosd(el1)*cosd(az1); cosd(el1)*sind(az1); sind(el1)];
% 注意：不能用 center_index，必须用实际生成的几何中心作为射线起点
p1 = mean(PA1.phase_index_array, 1)'; 

u2 = [cosd(el2)*cosd(az2); cosd(el2)*sind(az2); sind(el2)];
p2 = mean(PA2.phase_index_array, 1)'; 

% 最小二乘法求空间两条射线的最近交点
A_mat = [u1, -u2];
b_vec = p2 - p1;
x_sol = A_mat \ b_vec; 

t_est = x_sol(1);
k_est = x_sol(2);

pos_est1 = p1 + t_est * u1;
pos_est2 = p2 + k_est * u2;
estimated_pos = (pos_est1 + pos_est2) / 2;

%% 6. 结果展示
fprintf('\n------------------------------------------------\n');
fprintf('真实位置: [%.4f, %.4f, %.4f]\n', true_source_pos);
fprintf('估计位置: [%.4f, %.4f, %.4f]\n', estimated_pos);
error_dist = norm(true_source_pos(:) - estimated_pos(:));
fprintf('定位误差: %.4f m (%.2f cm)\n', error_dist, error_dist*100);
