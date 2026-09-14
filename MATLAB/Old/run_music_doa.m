function [est_az, est_el] = run_music_doa(X_snapshots, array_obj, freq)
% run_music_doa  基于REV多快拍数据的MUSIC来波方向估计
%
% 功能：
%   对单个相控阵的REV输出快拍矩阵，用MUSIC算法估计该阵列观测到的
%   来波方向（方位角 + 俯仰角）。两个阵列分别调用本函数，得到两个
%   方向角后在主函数中做射线交叉定位（AOA）。
%
% 输入：
%   X_snapshots : 64×N 复数矩阵，N 列每列为一次 REV() 输出的 64×1 相对复数信号
%   array_obj   : Phased_array 对象（提供阵元位置和法向量）
%   freq        : 载波频率 (Hz)
%
% 输出：
%   est_az : 来波方位角估计值 (°)，全局坐标系
%   est_el : 来波俯仰角估计值 (°)，全局坐标系
%
% 算法：
%   1. 由多快拍构造协方差矩阵 R = X * X' / N
%   2. 特征分解 R，取最小 63 个特征值对应特征向量构成噪声子空间 En
%   3. 扫描全空间方向 u，计算 MUSIC 谱 P(u) = 1 / |a^H * En * En^H * a|
%   4. 谱峰对应的 (az, el) 即为来波方向估计

    c      = 299792458;
    lambda = c / freq;
    k      = 2 * pi / lambda;

    %% Step1：由快拍矩阵构造协方差矩阵
    N = size(X_snapshots, 2);
    R = (X_snapshots * X_snapshots') / N;    % 64×64

    %% Step2：特征分解，构造噪声子空间投影矩阵
    [V, D]   = eig(R);
    [~, idx] = sort(diag(D), 'ascend');      % 特征值升序
    V        = V(:, idx);

    % 单信源：信号子空间维数=1，噪声子空间取前63个特征向量
    En = V(:, 1:end-1);                      % 64×63
    Gn = En * En';                           % 64×64 噪声子空间投影矩阵

    %% Step3：阵元相对坐标（以本阵列几何中心为原点）
    element_pos  = array_obj.phase_index_array;   % 64×3 绝对坐标
    array_center = mean(element_pos, 1);          % 1×3
    rel_pos      = element_pos - array_center;    % 64×3 相对坐标

    array_normal = array_obj.normal(:);           % 3×1 阵面法向量

    %% Step4：粗搜（2°步进）→ 精搜（0.1°步进）
    az_coarse = -180 : 2 : 180;
    el_coarse =  -90 : 2 :  90;
    [peak_az, peak_el] = music_scan_core(az_coarse, el_coarse, rel_pos, Gn, k, array_normal);

    az_fine = (peak_az - 3) : 0.1 : (peak_az + 3);
    el_fine = (peak_el - 3) : 0.1 : (peak_el + 3);
    [est_az, est_el] = music_scan_core(az_fine, el_fine, rel_pos, Gn, k, array_normal);
end


function [best_az, best_el] = music_scan_core(az_vec, el_vec, rel_pos, Gn, k, array_normal)
% MUSIC 空间谱扫描核心
% P_MUSIC(u) = 1 / (a^H * Gn * a)
% 当搜索方向与真实来波方向一致时，a 落入信号子空间，与噪声子空间近似正交，谱值趋于极大

    max_spec = -inf;
    best_az  = 0;
    best_el  = 0;

    for ia = 1 : length(az_vec)
        az = deg2rad(az_vec(ia));
        for ie = 1 : length(el_vec)
            el = deg2rad(el_vec(ie));

            % 全局坐标系下的搜索方向单位向量
            u = [cos(el)*cos(az); cos(el)*sin(az); sin(el)];  % 3×1

            % 屏蔽阵列背面方向（法向量夹角 > 90°），消除镜像模糊
            if u' * array_normal <= 0
                continue;
            end

            % 构造该方向的导向矢量 a(u)
            % phases(i) = k * r_i · u，r_i 为第 i 个阵元相对阵列中心的位移
            phases = k * (rel_pos * u);   % 64×1
            a      = exp(1j * phases);    % 64×1

            % MUSIC 谱
            denom = abs(a' * Gn * a);
            if denom < 1e-15, denom = 1e-15; end
            val = 1 / denom;

            if val > max_spec
                max_spec = val;
                best_az  = az_vec(ia);
                best_el  = el_vec(ie);
            end
        end
    end
end