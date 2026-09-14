function [err_music, err_bf] = compute_error(true_source_pos)
% 输入：真实源位置 true_source_pos = [x, y, z]
% 输出：两种定位方法的误差（单位：米）

    %% 1. 系统参数（与原主文件一致）
    room_dim        = [10, 8, 3];
    freq            = 2.4e9;
    gamma           = 0.9;
    Pt              = 0.1;
    spacing         = (3e8/freq)/2;
    snapshots       = 5;          % 若扫描点很多可适当减小此值以加速

    %% 2. 分布式相控阵部署
    center1 = [0.5, 0.5, 1];
    normal1 = [1, 1, 0];
    vec1_v  = [0, 0, 1];
    PA1 = Phased_array(center1, spacing, normal1, vec1_v);

    center2 = [9.5, 7.5, 2];
    normal2 = [-1, -1, 0];
    vec2_v  = [0, 0, 1];
    PA2 = Phased_array(center2, spacing, normal2, vec2_v);

    p1 = mean(PA1.phase_index_array, 1)';
    p2 = mean(PA2.phase_index_array, 1)';

    %% 3. 采集 REV 快拍数据
    X1 = zeros(64, snapshots);
    X2 = zeros(64, snapshots);
    for n = 1:snapshots
        X1(:,n) = REV(PA1, room_dim, true_source_pos, freq, gamma, Pt);
        X2(:,n) = REV(PA2, room_dim, true_source_pos, freq, gamma, Pt);
    end

    %% 4. 方案A：REV + MUSIC AOA
    [az1_music, el1_music] = run_music_doa(X1, PA1, freq);
    [az2_music, el2_music] = run_music_doa(X2, PA2, freq);
    u1 = [cosd(el1_music)*cosd(az1_music); cosd(el1_music)*sind(az1_music); sind(el1_music)];
    u2 = [cosd(el2_music)*cosd(az2_music); cosd(el2_music)*sind(az2_music); sind(el2_music)];
    x_sol = [u1, -u2] \ (p2 - p1);
    pos_music = (p1 + x_sol(1)*u1 + p2 + x_sol(2)*u2) / 2;
    err_music = norm(true_source_pos(:) - pos_music);

    %% 5. 方案B：REV + Beamforming AOA
    [az1_bf, el1_bf] = run_beamforming_doa(X1, PA1, freq);
    [az2_bf, el2_bf] = run_beamforming_doa(X2, PA2, freq);
    u1 = [cosd(el1_bf)*cosd(az1_bf); cosd(el1_bf)*sind(az1_bf); sind(el1_bf)];
    u2 = [cosd(el2_bf)*cosd(az2_bf); cosd(el2_bf)*sind(az2_bf); sind(el2_bf)];
    x_sol = [u1, -u2] \ (p2 - p1);
    pos_bf = (p1 + x_sol(1)*u1 + p2 + x_sol(2)*u2) / 2;
    err_bf = norm(true_source_pos(:) - pos_bf);

end