function [est_az, est_el] = beamforming_doa(X_snapshots, array_obj, freq)
% 波束赋形 DOA 估计：通过扫描方向权向量，寻找使波束输出功率最大的方向
%
% 使用常规波束形成（CBF / Bartlett 波束形成器）：
%   w(θ,φ) = a(θ,φ) / N
%   P(θ,φ) = |a^H * X_avg|²
%
% 输入：
%   X_snapshots : 64×N 复数矩阵，N 列为 N 次快拍（REV 输出）
%   array_obj   : PhasedArray 对象
%   freq        : 载波频率 (Hz)
%
% 输出：
%   est_az : 来波方位角估计值 (°)
%   est_el : 来波俯仰角估计值 (°)

c      = 299792458;
lambda = c / freq;
k      = 2 * pi / lambda;

% 多快拍相干平均
X_avg = mean(X_snapshots, 2);   % 64×1

% 阵元相对坐标
rel_pos      = array_obj.element_pos - mean(array_obj.element_pos, 1);  % 64×3
array_normal = array_obj.normal(:);

%% 粗搜 → 精搜
az_coarse = -180:2:180;
el_coarse =  -90:2: 90;
[peak_az, peak_el] = bf_scan(az_coarse, el_coarse, rel_pos, X_avg, k, array_normal);

az_fine = (peak_az-3):0.2:(peak_az+3);
el_fine = (peak_el-3):0.2:(peak_el+3);
[est_az, est_el] = bf_scan(az_fine, el_fine, rel_pos, X_avg, k, array_normal);
end


function [best_az, best_el] = bf_scan(az_vec, el_vec, rel_pos, X, k, array_normal)
% 向量化波束扫描: P(θ,φ) = |a^H * X|²
% 对所有 (az, el) 组合同步计算导向矢量和功率

[AZ_grid, EL_grid] = meshgrid(az_vec, el_vec);
az_rad = deg2rad(AZ_grid(:));
el_rad = deg2rad(EL_grid(:));

% 所有方向的单位波矢 [ux; uy; uz]  (3 × M)
ux = cos(el_rad) .* cos(az_rad);
uy = cos(el_rad) .* sin(az_rad);
uz = sin(el_rad);
U  = [ux'; uy'; uz'];   % 3 × M

% 屏蔽背面方向
mask = (U' * array_normal) > 0;   % M × 1 logical

% 批量计算导向矢量矩阵  A = exp(1j*k * rel_pos * U)  → 64 × M
A = exp(1j * k * (rel_pos * U));

% 批量计算功率谱 (仅有效方向)
P = zeros(size(A, 2), 1);
P(mask) = abs(X' * A(:, mask)).^2;   % 1 × num_valid → num_valid × 1

% 取最大值
[max_power, idx] = max(P);
if max_power <= 0
    % 退化情况：所有方向都被屏蔽
    best_az = 0; best_el = 0;
else
    best_az = AZ_grid(idx);
    best_el = EL_grid(idx);
end
end
