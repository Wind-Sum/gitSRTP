function [amplitude, phase, power_dBm] = calculate_indoor_field(rx_pos, room_dim, source_pos, freq, gamma, Pt, varargin)
% 室内电磁场计算 —— 基于镜像法的直达路径 + 多径反射合成
%
% 输入：
%   rx_pos      : 接收点坐标 [x, y, z] (m)
%   room_dim    : 房间尺寸 [Lx, Ly, Lz] (m)
%   source_pos  : 信源位置 [x, y, z] (m)
%   freq        : 载波频率 (Hz)
%   gamma       : 墙壁反射系数（实数或复数）
%   Pt          : 发射功率 (W)
%   varargin    : 可选参数（键值对）
%       'Images', cell数组    — 预计算的镜像源列表（批量计算时复用，大幅加速）
%       'MaxReflections', N   — 最大反射次数（需生成镜像时使用，默认3）
%       'MaxPathLoss', dB     — 路径损耗阈值（默认50 dB）
%
% 输出：
%   amplitude   : 合成场幅度 (V/m)
%   phase       : 合成场相位 (rad)
%   power_dBm   : 接收功率 (dBm)

%% 参数处理
if nargin < 5, gamma = 0.8; end
if nargin < 6, Pt   = 0.1; end

if isreal(gamma)
    gamma_complex = gamma * exp(1j*pi);   % 反射引入 180° 相移
else
    gamma_complex = gamma;
end

precomputed_images = [];
max_reflections    = 3;

if ~isempty(varargin)
    k = 1;
    while k <= length(varargin)
        switch lower(varargin{k})
            case 'images'
                precomputed_images = varargin{k+1};
                k = k + 2;
            case 'maxreflections'
                max_reflections = varargin{k+1};
                k = k + 2;
            case 'maxpathloss'
                k = k + 2;   % 预留接口
            otherwise
                k = k + 1;
        end
    end
end

%% 物理常数
c      = 299792458;
lambda = c / freq;
k      = 2 * pi / lambda;

rx_pos     = rx_pos(:);
source_pos = source_pos(:);

%% 直达路径
direct_dist = norm(rx_pos - source_pos);
if direct_dist > 0
    E_direct = sqrt(60 * Pt) * exp(-1j * k * direct_dist) / direct_dist;
else
    E_direct = 0;
end
E_total = E_direct;

%% 镜像源与反射路径叠加
if isempty(precomputed_images)
    images = generate_image_sources(source_pos, room_dim, max_reflections);
else
    images = precomputed_images;
end

% 自适应阈值：直达路径功率的 0.1%（-30 dB），兼顾远场弱直达情况
if abs(E_direct) > 0
    amp_threshold = 0.001 * abs(E_direct);
    % 同时限制距离不超过房间对角线长度的 3 倍，避免无限远镜像参与
    max_dist = 3 * norm(room_dim);
else
    amp_threshold = 1e-12;
    max_dist = 3 * norm(room_dim);
end

for idx = 1:length(images)
    img  = images{idx};
    dist = norm(rx_pos - img.pos);
    if dist == 0 || dist > max_dist
        continue;
    end

    E_path = sqrt(60 * Pt) * exp(-1j * k * dist) / dist;
    E_path = E_path * (gamma_complex ^ img.order);

    if abs(E_path) > amp_threshold
        E_total = E_total + E_path;
    end
end

%% 输出
amplitude = abs(E_total);
phase     = angle(E_total);

if amplitude > 0
    Pr        = (amplitude^2) / (240 * pi) * (lambda^2 / (4 * pi));
    power_dBm = 10 * log10(Pr * 1000);
else
    power_dBm = -Inf;
end
end
