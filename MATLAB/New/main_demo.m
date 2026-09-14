% ! 主演示脚本：REV + MUSIC / Beamforming 双方案 AOA 定位对比
% 
% 技术链路：
%   REV（能量→相位）→ MUSIC/Beamforming（相位→角度）→ AOA 交叉定位（角度→位置）
%
% 部署：房间对角线两端各放置一个 8×8 相控阵，对室内单信源进行定位

clc; clear; close all;

%% ===================== 1. 系统参数 =====================
room_dim        = [10, 8, 3];           % 房间尺寸 [Lx, Ly, Lz] (m)
freq            = 2.4e9;                % 载波频率 (Hz)
gamma           = 0.0;                  % 墙壁反射系数（先设 0 验证无多径时的算法精度，再加反射）
Pt              = 0.1;                  % 发射功率 (W)
spacing         = (3e8 / freq) / 2;     % 阵元间距 = λ/2
snapshots       = 50;                   % 快拍次数
true_source_pos = [3.5, 4, 2];          % 真实信源位置

fprintf('==================== 系统参数 ====================\n');
fprintf('房间尺寸       : %.1f × %.1f × %.1f m\n', room_dim);
fprintf('载波频率       : %.2f GHz\n', freq/1e9);
fprintf('墙壁反射系数   : %.2f\n', gamma);
fprintf('快拍次数       : %d\n', snapshots);
fprintf('真实信源位置   : [%.2f, %.2f, %.2f] m\n\n', true_source_pos);

%% ===================== 2. 阵列部署 =====================
% 两天花板阵列：法向量朝下，向房间中部靠拢以增大边角有效孔径
center1 = [3, 2, room_dim(3)];
normal1 = [0, 0, -1];
vec1    = [1, 0, 0];
PA1     = PhasedArray(center1, spacing, normal1, vec1);

center2 = [room_dim(1)-3, room_dim(2)-2, room_dim(3)];
normal2 = [0, 0, -1];
vec2    = [1, 0, 0];
PA2     = PhasedArray(center2, spacing, normal2, vec2);

% 阵列几何中心（AOA 射线起点）
p1 = mean(PA1.element_pos, 1)';
p2 = mean(PA2.element_pos, 1)';

fprintf('PA1 中心: [%.2f, %.2f, %.2f] m\n', p1);
fprintf('PA2 中心: [%.2f, %.2f, %.2f] m\n\n', p2);

%% ===================== 3. REV 多快拍数据采集 =====================
fprintf('===== REV 多快拍数据采集（每阵列 %d 次）=====\n', snapshots);
t_rev = tic;
X1 = zeros(64, snapshots);
X2 = zeros(64, snapshots);

for n = 1:snapshots
    X1(:, n) = rev(PA1, room_dim, true_source_pos, freq, gamma, Pt);
    X2(:, n) = rev(PA2, room_dim, true_source_pos, freq, gamma, Pt);
    if mod(n, 10) == 0
        fprintf('  进度: %d / %d\n', n, snapshots);
    end
end
fprintf('采集完成 (耗时 %.1f s)。\n\n', toc(t_rev));

%% ===================== 4. 方案A：REV + MUSIC =====================
fprintf('========== 方案A：REV + MUSIC ==========\n');
[az1_m, el1_m] = music_doa(X1, PA1, freq);
[az2_m, el2_m] = music_doa(X2, PA2, freq);
fprintf('  PA1 DOA: 方位角 = %.2f°,  俯仰角 = %.2f°\n', az1_m, el1_m);
fprintf('  PA2 DOA: 方位角 = %.2f°,  俯仰角 = %.2f°\n', az2_m, el2_m);

[pos_music, err_music] = aoa_localize(az1_m, el1_m, p1, az2_m, el2_m, p2, true_source_pos);
fprintf('  估计位置: [%.4f, %.4f, %.4f] m\n', pos_music);
fprintf('  定位误差: %.4f m (%.2f cm)\n\n', err_music, err_music*100);

%% ===================== 5. 方案B：REV + Beamforming =====================
fprintf('========== 方案B：REV + Beamforming ==========\n');
[az1_b, el1_b] = beamforming_doa(X1, PA1, freq);
[az2_b, el2_b] = beamforming_doa(X2, PA2, freq);
fprintf('  PA1 DOA: 方位角 = %.2f°,  俯仰角 = %.2f°\n', az1_b, el1_b);
fprintf('  PA2 DOA: 方位角 = %.2f°,  俯仰角 = %.2f°\n', az2_b, el2_b);

[pos_bf, err_bf] = aoa_localize(az1_b, el1_b, p1, az2_b, el2_b, p2, true_source_pos);
fprintf('  估计位置: [%.4f, %.4f, %.4f] m\n', pos_bf);
fprintf('  定位误差: %.4f m (%.2f cm)\n\n', err_bf, err_bf*100);

%% ===================== 6. 地面真值对比 =====================
% 计算理论 DOA 角度（直接从几何关系得出，用于检验算法是否正确）
v1 = true_source_pos(:) - p1;
v2 = true_source_pos(:) - p2;
az1_true = atan2d(v1(2), v1(1));
el1_true = atan2d(v1(3), sqrt(v1(1)^2 + v1(2)^2));
az2_true = atan2d(v2(2), v2(1));
el2_true = atan2d(v2(3), sqrt(v2(1)^2 + v2(2)^2));

fprintf('========== 地面真值 DOA（理论值）==========\n');
fprintf('  PA1 (位于 [%.1f, %.1f, %.1f]):  方位角 = %.2f°,  俯仰角 = %.2f°\n', p1, az1_true, el1_true);
fprintf('  PA2 (位于 [%.1f, %.1f, %.1f]):  方位角 = %.2f°,  俯仰角 = %.2f°\n', p2, az2_true, el2_true);

fprintf('\n========== DOA 估计误差 ==========\n');
fprintf('  PA1 MUSIC:      Δaz = %+.4f°,  Δel = %+.4f°\n', az1_m - az1_true, el1_m - el1_true);
fprintf('  PA1 BF:         Δaz = %+.4f°,  Δel = %+.4f°\n', az1_b - az1_true, el1_b - el1_true);
fprintf('  PA2 MUSIC:      Δaz = %+.4f°,  Δel = %+.4f°\n', az2_m - az2_true, el2_m - el2_true);
fprintf('  PA2 BF:         Δaz = %+.4f°,  Δel = %+.4f°\n', az2_b - az2_true, el2_b - el2_true);

if gamma > 0
    fprintf('\n*** 注意：当前 gamma = %.1f，存在多径反射。***\n', gamma);
    fprintf('*** 若 PA2 误差很大，建议将 gamma 改为 0 先验证无多径时的精度。***\n');
end

%% ===================== 7. 结果汇总 =====================
fprintf('\n======================= 算法对比汇总 =======================\n');
fprintf('真实位置:           [%.4f, %.4f, %.4f] m\n', true_source_pos);
fprintf('REV+MUSIC     估计: [%.4f, %.4f, %.4f] m  误差: %.2f cm\n', ...
    pos_music, err_music*100);
fprintf('REV+BF        估计: [%.4f, %.4f, %.4f] m  误差: %.2f cm\n', ...
    pos_bf, err_bf*100);

if err_music < err_bf
    fprintf('>> REV+MUSIC 精度更高，优势 %.2f cm\n', (err_bf-err_music)*100);
elseif err_bf < err_music
    fprintf('>> REV+BF 精度更高，优势 %.2f cm\n', (err_music-err_bf)*100);
else
    fprintf('>> 两方案精度相同\n');
end
fprintf('============================================================\n');
