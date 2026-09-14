function [est_az, est_el] = run_beamforming_doa(X_snapshots, array_obj, freq)
% run_beamforming_doa  基于REV多快拍数据的延迟叠加波束成形来波方向估计
%
% 接口与 run_music_doa 完全一致，可直接替换对比。
%
% 输入：
%   X_snapshots : 64×N 复数矩阵，每列为一次 REV() 输出的 64×1 相对复数信号
%   array_obj   : Phased_array 对象
%   freq        : 载波频率 (Hz)
%
% 输出：
%   est_az : 来波方位角估计值 (°)
%   est_el : 来波俯仰角估计值 (°)

    c      = 299792458;
    lambda = c / freq;
    k      = 2 * pi / lambda;

    % 多快拍相干平均，提升 SNR
    X_avg = mean(X_snapshots, 2);   % 64×1

    % 阵元相对坐标（以阵列几何中心为原点）
    element_pos  = array_obj.phase_index_array;       % 64×3
    array_center = mean(element_pos, 1);              % 1×3
    rel_pos      = element_pos - array_center;        % 64×3

    array_normal = array_obj.normal(:);               % 3×1

    % 粗搜（2°步进）
    az_coarse = -180 : 2 : 180;
    el_coarse =  -90 : 2 :  90;
    [peak_az, peak_el] = bf_scan(az_coarse, el_coarse, rel_pos, X_avg, k, array_normal);

    % 精搜（0.2°步进）
    az_fine = (peak_az - 3) : 0.2 : (peak_az + 3);
    el_fine = (peak_el - 3) : 0.2 : (peak_el + 3);
    [est_az, est_el] = bf_scan(az_fine, el_fine, rel_pos, X_avg, k, array_normal);
end


function [best_az, best_el] = bf_scan(az_vec, el_vec, rel_pos, X, k, array_normal)
    max_power = -inf;
    best_az   = 0;
    best_el   = 0;

    for ia = 1 : length(az_vec)
        az = deg2rad(az_vec(ia));
        for ie = 1 : length(el_vec)
            el = deg2rad(el_vec(ie));

            u = [cos(el)*cos(az); cos(el)*sin(az); sin(el)];

            % 屏蔽阵列背面方向
            if u' * array_normal <= 0
                continue;
            end

            % 导向矢量与波束成形谱
            a     = exp(1j * k * (rel_pos * u));   % 64×1
            power = abs(a' * X)^2;

            if power > max_power
                max_power = power;
                best_az   = az_vec(ia);
                best_el   = el_vec(ie);
            end
        end
    end
end