function X = get_music_data(Phased_array, room_dim, source_pos, freq, gamma, Pt, snr_dB, varargin)
    % get_music_data 获取用于MUSIC算法的复数信号向量
    % 输出:
    %   X: 64x1 复数向量 (包含振幅和相位信息)
    
    X = REV(Phased_array, room_dim, source_pos, freq, gamma,Pt,varargin);
    
    % 添加高斯白噪声 (为了模拟真实情况并避免奇异性)
    if exist('snr_dB', 'var') && ~isempty(snr_dB)
        sig_power = mean(abs(X).^2);
        noise_power = sig_power / (10^(snr_dB/10));
        noise = sqrt(noise_power/2) * (randn(size(X)) + 1j*randn(size(X)));
        X = X + noise;
    end
end
