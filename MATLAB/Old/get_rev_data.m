function rev_arr = get_rev_data(Phased_array,room_dim, source_pos, freq, gamma, Pt, varargin)
    %Phased_array为相控阵类
    %   rx_center    : 测量中心点坐标 [x, y, z] (m)
    %   room_dim     : 房间尺寸 [Lx, Ly, Lz] (m)
    %   source_pos   : 信源位置 [x_s, y_s, z_s] (m)
    %   freq         : 频率 (Hz)
    %   gamma        : 反射系数
    %   Pt           : 发射功率 (W)
    %   varargin     : 可选参数（传递给原有函数）
    %
    % 输出参数：
    %   P1, P2, P3 : 三功率 64*3
    rev_arr = Phased_array.cal_Rev_Data(room_dim, source_pos, freq, gamma, Pt, varargin);
end