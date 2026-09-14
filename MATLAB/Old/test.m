clc; clear; close all;

%% 1. 系统参数
room_dim        = [10, 8, 3];
freq            = 2.4e9;
gamma           = 0.9;
Pt              = 0.1;
spacing         = (3e8/freq)/2;
snapshots       = 50;
true_source_pos = [0.1, 2.1, 1.5];

%% 2. 分布式相控阵部署（房间对角线两端）
center1 = [0.5, 0.5, 1];
normal1 = [1, 1, 0];
vec1_v  = [0, 0, 1];
PA1 = Phased_array(center1, spacing, normal1, vec1_v);

center2 = [9.5, 7.5, 2];
normal2 = [-1, -1, 0];
vec2_v  = [0, 0, 1];
PA2 = Phased_array(center2, spacing, normal2, vec2_v);

% 两阵列几何中心（AOA射线起点）
p1 = mean(PA1.phase_index_array, 1)';
p2 = mean(PA2.phase_index_array, 1)';

%% 3. 采集 REV 快拍数据（两算法共用同一组数据）
fprintf('正在采集 REV 快拍数据（每阵列 %d 次）...\n', snapshots);
X1 = zeros(64, snapshots);
X2 = zeros(64, snapshots);
for n = 1:snapshots
    X1(:,n) = REV(PA1, room_dim, true_source_pos, freq, gamma, Pt);
    X2(:,n) = REV(PA2, room_dim, true_source_pos, freq, gamma, Pt);
    if mod(n,10)==0, fprintf('  %d / %d\n', n, snapshots); end
end
fprintf('采集完成。\n\n');

%% ================================================================
%% 方案A：REV + MUSIC AOA
%% ================================================================
fprintf('========== 方案A：REV + MUSIC (AOA) ==========\n');

[az1_music, el1_music] = run_music_doa(X1, PA1, freq);
[az2_music, el2_music] = run_music_doa(X2, PA2, freq);
fprintf('  PA1: 方位角=%.2f°, 俯仰角=%.2f°\n', az1_music, el1_music);
fprintf('  PA2: 方位角=%.2f°, 俯仰角=%.2f°\n', az2_music, el2_music);

% AOA 射线交叉定位（最小二乘求两射线最近交点）
u1 = [cosd(el1_music)*cosd(az1_music); cosd(el1_music)*sind(az1_music); sind(el1_music)];
u2 = [cosd(el2_music)*cosd(az2_music); cosd(el2_music)*sind(az2_music); sind(el2_music)];
x_sol = [u1, -u2] \ (p2 - p1);
pos_music = ( (p1 + x_sol(1)*u1) + (p2 + x_sol(2)*u2) ) / 2;
err_music = norm(true_source_pos(:) - pos_music);

fprintf('  估计位置: [%.4f, %.4f, %.4f] m\n', pos_music(1), pos_music(2), pos_music(3));
fprintf('  定位误差: %.4f m (%.2f cm)\n\n', err_music, err_music*100);

%% ================================================================
%% 方案B：REV + Beamforming AOA
%% ================================================================
fprintf('========== 方案B：REV + Beamforming (AOA) ==========\n');

[az1_bf, el1_bf] = run_beamforming_doa(X1, PA1, freq);
[az2_bf, el2_bf] = run_beamforming_doa(X2, PA2, freq);
fprintf('  PA1: 方位角=%.2f°, 俯仰角=%.2f°\n', az1_bf, el1_bf);
fprintf('  PA2: 方位角=%.2f°, 俯仰角=%.2f°\n', az2_bf, el2_bf);

% AOA 射线交叉定位
u1 = [cosd(el1_bf)*cosd(az1_bf); cosd(el1_bf)*sind(az1_bf); sind(el1_bf)];
u2 = [cosd(el2_bf)*cosd(az2_bf); cosd(el2_bf)*sind(az2_bf); sind(el2_bf)];
x_sol = [u1, -u2] \ (p2 - p1);
pos_bf = ( (p1 + x_sol(1)*u1) + (p2 + x_sol(2)*u2) ) / 2;
err_bf = norm(true_source_pos(:) - pos_bf);

fprintf('  估计位置: [%.4f, %.4f, %.4f] m\n', pos_bf(1), pos_bf(2), pos_bf(3));
fprintf('  定位误差: %.4f m (%.2f cm)\n\n', err_bf, err_bf*100);

%% ================================================================
%% 对比汇总
%% ================================================================
fprintf('=================== 算法对比汇总 ===================\n');
fprintf('真实位置:          [%.4f, %.4f, %.4f] m\n', true_source_pos(1), true_source_pos(2), true_source_pos(3));
fprintf('REV+MUSIC  估计值: [%.4f, %.4f, %.4f] m  误差: %.4f m (%.2f cm)\n', pos_music(1), pos_music(2), pos_music(3), err_music, err_music*100);
fprintf('REV+BF     估计值: [%.4f, %.4f, %.4f] m  误差: %.4f m (%.2f cm)\n', pos_bf(1),    pos_bf(2),    pos_bf(3),    err_bf,    err_bf*100);
if err_music < err_bf
    fprintf('>> REV+MUSIC 精度更高，优势 %.2f cm\n', (err_bf-err_music)*100);
else
    fprintf('>> REV+BF 精度更高，优势 %.2f cm\n', (err_music-err_bf)*100);
end
fprintf('=====================================================\n');