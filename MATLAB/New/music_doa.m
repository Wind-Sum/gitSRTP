function [est_az, est_el] = music_doa(X_snapshots, array_obj, freq, num_sources)
% MUSIC 算法：基于信号子空间分解的高分辨来波方向估计
%
% 原理：
%   对接收数据协方差矩阵做特征分解 → 信号子空间 / 噪声子空间分离 →
%   利用导向矢量与噪声子空间的正交性，构造 MUSIC 伪谱 →
%   谱峰位置即为 DOA 估计。
%
% 输入：
%   X_snapshots : 64×N 复数矩阵，N 列为 N 次快拍（REV 输出）
%   array_obj   : PhasedArray 对象
%   freq        : 载波频率 (Hz)
%   num_sources : 信源数（默认 1）
%
% 输出：
%   est_az : 来波方位角估计值 (°)
%   est_el : 来波俯仰角估计值 (°)

if nargin < 4, num_sources = 1; end

c      = 299792458;
lambda = c / freq;
k      = 2 * pi / lambda;

%% 协方差矩阵
N = size(X_snapshots, 2);
R = (X_snapshots * X_snapshots') / N;   % 64×64

%% 特征分解 → 噪声子空间
[V, D]   = eig(R);
[~, idx] = sort(diag(D), 'ascend');
V        = V(:, idx);

% 噪声子空间：最小的 N_elems - num_sources 个特征向量
N_elems = size(V, 1);
n_noise = N_elems - num_sources;
if n_noise <= 0
    error('music_doa: 信源数 (%d) 不得 ≥ 阵元数 (%d)', num_sources, N_elems);
end
En = V(:, 1:n_noise);       % N_elems × n_noise
% 不显式构造 64×64 投影矩阵，改为向量化计算 a^H*En*En^H*a = sum(abs(En'*a).^2)

%% 阵元相对坐标
rel_pos      = array_obj.element_pos - mean(array_obj.element_pos, 1);  % 64×3
array_normal = array_obj.normal(:);

%% 粗搜 → 精搜
az_coarse = -180:2:180;
el_coarse =  -90:2: 90;
[peak_az, peak_el] = music_scan(az_coarse, el_coarse, rel_pos, En, k, array_normal);

az_fine = (peak_az-3):0.1:(peak_az+3);
el_fine = (peak_el-3):0.1:(peak_el+3);
[est_az, est_el] = music_scan(az_fine, el_fine, rel_pos, En, k, array_normal);
end


function [best_az, best_el] = music_scan(az_vec, el_vec, rel_pos, En, k, array_normal)
% 向量化 MUSIC 空间谱扫描: P(θ,φ) = 1 / (a^H * En * En^H * a)
% 使用 sum(abs(En'*a).^2) 避免显式构造 64×64 投影矩阵

[AZ_grid, EL_grid] = meshgrid(az_vec, el_vec);
az_rad = deg2rad(AZ_grid(:));
el_rad = deg2rad(EL_grid(:));

% 所有方向的单位波矢 (3 × M)
ux = cos(el_rad) .* cos(az_rad);
uy = cos(el_rad) .* sin(az_rad);
uz = sin(el_rad);
U  = [ux'; uy'; uz'];   % 3 × M

% 屏蔽背面方向
mask = (U' * array_normal) > 0;   % M × 1 logical

% 批量计算导向矢量矩阵  A = exp(1j*k * rel_pos * U)  → N_elems × M
A = exp(1j * k * (rel_pos * U));

% 批量计算 MUSIC 伪谱 (仅有效方向)
% denom = |a^H * En * En^H * a| = sum(|En^H * a|.^2)  = sum(abs(En'*a).^2)
num_valid = sum(mask);
if num_valid == 0
    best_az = 0; best_el = 0; return;
end

A_valid = A(:, mask);              % N_elems × num_valid
EnH_A   = En' * A_valid;           % n_noise × num_valid
denom   = sum(abs(EnH_A).^2, 1);   % 1 × num_valid
denom   = max(denom, 1e-15);       % 防除零
val_all = zeros(size(A, 2), 1);
val_all(mask) = 1 ./ denom(:);

[max_spec, idx] = max(val_all);
if max_spec <= 0
    best_az = 0; best_el = 0;
else
    best_az = AZ_grid(idx);
    best_el = EL_grid(idx);
end
end
