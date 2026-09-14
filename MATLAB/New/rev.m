function X = rev(array_obj, room_dim, source_pos, freq, gamma, Pt, varargin)
% REV 算法：通过三功率测量重建各阵元相对复数信号
%
% 原理：
%   对每个阵元依次施加 0°/90°/180° 相位扰动，测量合成功率 P0/P90/P180，
%   通过解析求解线性方程组反演出阵元相对复数场 k_m * e^(j*X_m)。
%
% 输入：
%   array_obj   : PhasedArray 对象
%   room_dim    : 房间尺寸 [Lx, Ly, Lz] (m)
%   source_pos  : 信源位置 [x, y, z] (m)
%   freq        : 载波频率 (Hz)
%   gamma       : 墙壁反射系数
%   Pt          : 发射功率 (W)
%   varargin    : 可选 'SNR_dB', 值 — 添加高斯白噪声 (dB)
%
% 输出：
%   X : 64×1 复数向量，X(i) 为第 i 个阵元的相对复数信号

% 解析可选 SNR 参数
snr_dB = [];
field_args = {};
if ~isempty(varargin)
    i = 1;
    while i <= length(varargin)
        if strcmpi(varargin{i}, 'SNR_dB')
            snr_dB = varargin{i+1};
            i = i + 2;
        else
            field_args = [field_args, varargin{i}];
            i = i + 1;
        end
    end
end

% 获取三功率数据 [P0, P90, P180] (64×3)
rev_data = array_obj.cal_rev_data(room_dim, source_pos, freq, gamma, Pt, field_args{:});

% 批量解算相对复数信号（解析解，避免逐阵元矩阵求逆）
X = solve_rev_batch(rev_data);

% 添加噪声（可选）
if ~isempty(snr_dB)
    sig_power   = mean(abs(X).^2);
    noise_power = sig_power / (10^(snr_dB/10));
    noise       = sqrt(noise_power/2) * (randn(64,1) + 1j*randn(64,1));
    X           = X + noise;
end
end


function X = solve_rev_batch(rev_data)
% 批量解析求解 REV 三功率 → 相对复数场
%
% 对线性系统 A*[x1; x2; x3] = [P0; P90; P180] 其中
%   A = [1,  1,   1;
%        1, -j,   j;
%        1, -1,  -1]
% 解析解（避免数值求逆）：
%   x1 = (P0 + P180) / 2
%   x2 = (P0 - P180)/4 + j*(2*P90 - P0 - P180)/4
%   从 x2 提取相位差，利用代数恒等式恢复幅度
%
% 输入：rev_data — N×3 矩阵
% 输出：X — N×1 复数向量

P0   = rev_data(:, 1);
P90  = rev_data(:, 2);
P180 = rev_data(:, 3);

% 解析解 (N×1)
x1 = (P0 + P180) / 2;
x2 = (P0 - P180)/4 + 1j * (2*P90 - P0 - P180)/4;

phi_diff = angle(x2);   % 相位差

% 数值稳定：abs(x1) - 2*abs(x2) 可能因噪声为负
diff_val = abs(x1) - 2 * abs(x2);
diff_val(diff_val < 0) = 0;   % clamp to zero

sqrt_plus  = sqrt(abs(x1) + 2 * abs(x2));
sqrt_minus = sqrt(diff_val);

E_m_bar = (sqrt_plus + sqrt_minus) / 2;   % 其余阵元合成场振幅
E_m     = (sqrt_plus - sqrt_minus) / 2;   % 本阵元场振幅

denom = E_m + E_m_bar .* exp(1j * phi_diff);
% 防止除零
denom(abs(denom) < 1e-15) = 1e-15;

X = E_m ./ denom;
end
