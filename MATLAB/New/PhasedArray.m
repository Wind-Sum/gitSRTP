classdef PhasedArray
    % 8×8 矩形平面相控阵的几何定义与阵元位置计算
    %
    % 属性：
    %   center         - 阵列几何中心坐标 [x, y, z] (m)
    %   spacing        - 相邻阵元间距 (m)，通常取 λ/2
    %   normal         - 阵面法向量（归一化），指向阵列前方
    %   dir_vec1       - 阵元列方向向量（归一化），与 normal 垂直
    %   dir_vec2       - 阵元行方向向量（归一化），dir_vec2 = cross(normal, dir_vec1)
    %   element_pos    - 64×3 矩阵，每行为一个阵元的 (x, y, z) 坐标

    properties
        center
        spacing
        normal
        dir_vec1
        dir_vec2
        element_pos    % 64×3
    end

    methods
        function obj = PhasedArray(center, spacing, normal, dir_vector)
            % 构造函数
            %   center      : [x, y, z] 阵列中心坐标
            %   spacing     : 阵元间距 (m)
            %   normal      : 阵面法向量方向
            %   dir_vector  : 阵元列方向（须与 normal 垂直）

            % 输入验证
            if spacing <= 0
                error('PhasedArray: 阵元间距必须 > 0，当前值: %.2e', spacing);
            end
            if abs(dot(normal, dir_vector)) > 1e-6
                error('PhasedArray: normal 与 dir_vector 不垂直，请检查输入。');
            end

            obj.center      = center;
            obj.spacing     = spacing;
            obj.normal      = normal / norm(normal);
            obj.dir_vec1    = dir_vector / norm(dir_vector);
            obj.dir_vec2    = cross(obj.normal, obj.dir_vec1);
            obj.element_pos = obj.compute_element_positions();
        end

        function rev_data = cal_rev_data(obj, room_dim, source_pos, freq, gamma, Pt, varargin)
            % 计算 REV 三功率数据（64 个阵元依次施加 0°/90°/180° 相位扰动）
            % 输出：64×3 矩阵，每行 [P0, P90, P180]
            %
            % 优化：
            %   1. 预计算镜像源一次，所有 64 个阵元复用
            %   2. 先批量计算所有阵元复场强，再逐元算三功率

            N = 64;

            % 预计算镜像源（核心优化：避免 64 次重复生成）
            images = generate_image_sources(source_pos, room_dim);

            % 批量计算所有阵元复场强
            E = zeros(N, 1);
            for k = 1:N
                rx_pos = obj.element_pos(k, :)';
                [amp, ph] = calculate_indoor_field(rx_pos, room_dim, source_pos, ...
                    freq, gamma, Pt, 'Images', images);
                E(k) = amp * exp(1j * ph);
            end

            % 逐阵元计算三功率（O(N) 批量操作）
            E_all   = sum(E);
            rev_data = zeros(N, 3);

            for idx = 1:N
                E_m    = E(idx);
                E_rest = E_all - E_m;

                rev_data(idx, 1) = abs(E_rest + E_m * exp(1j*0))^2;       % P0
                rev_data(idx, 2) = abs(E_rest + E_m * exp(1j*pi/2))^2;    % P90
                rev_data(idx, 3) = abs(E_rest + E_m * exp(1j*pi))^2;      % P180
            end
        end
    end

    methods (Access = private)
        function pos = compute_element_positions(obj)
            % 向量化计算 64 个阵元的空间坐标（8×8 网格，中心在 obj.center）
            % 网格基准：i_offset = (i-4.5), j_offset = (j-4.5) for i,j=1..8
            [I, J] = meshgrid(1:8, 1:8);
            offset1 = I(:) - 4.5;   % 64×1 沿 dir_vec1 的偏移
            offset2 = J(:) - 4.5;   % 64×1 沿 dir_vec2 的偏移

            pos = obj.center + offset1 * obj.spacing * obj.dir_vec1 ...
                             + offset2 * obj.spacing * obj.dir_vec2;
        end
    end
end
