classdef Phased_array
    %8*8相控阵的定义与几何参数计算
    properties
        center_index      %中心位置坐标 1*3 [x,y,z] (m)
        spacing           %标量，阵元之间的距离      (m)
        normal            %相控阵所在平面的方向向量   1*3
        direct_vector1    %一列相控阵振元所在直线的方向向量（要求和normal垂直） 1*3
        direct_vector2    %一行相控阵振元所在直线的方向向量（要求和normal垂直） 1*3
        phase_index_array %每个相控阵的位置信息（64*3）
    end

    methods
        function obj = Phased_array(center_index,spacing,normal,direct_vector)
            %检测输入是否符合题意
            if dot(normal,direct_vector) > 1e-6
                error("请检测输入方向向量！");
            end
            %赋值
            obj.center_index= center_index;
            obj.spacing = spacing;
            obj.normal = normal/norm(normal);                          %归一化
            obj.direct_vector1 = direct_vector/norm(direct_vector);    %归一化
            obj.direct_vector2 = cross(obj.normal,obj.direct_vector1);   %三个向量两两垂直
            obj.phase_index_array = obj.cal_phase_index();
        end

        function phase_index_Array = cal_phase_index(obj)
            % 获取每个阵元的位置信息
            phase_index_Array = []; %空矩阵
            for i = 1:8
                for j = 1:8
                    % 【核心修复1】：必须乘以 obj.spacing，并且中心偏移是 4.5
                    phase_ij_index = obj.center_index + ...
                        (i-4.5) * obj.spacing * obj.direct_vector1 + ...
                        (j-4.5) * obj.spacing * obj.direct_vector2;
                    phase_index_Array = [phase_index_Array; phase_ij_index];    
                end
            end
        end

        function  [amplitude, phase] = get_field_at_phase(obj,index1,index2,room_dim, source_pos, freq, gamma, Pt, varargin)
            %计算（index1,index2)的阵元阵元处的振幅和相位
            %index1,index2为需要获取阵元的位置
            %room_dim,source_pos,freq,gamma,Pt均为calculate_indoor_field函数的参数

            rx_pos = obj.phase_index_array((index1-1)*8 + index2,:)'; %获取阵元的空间坐标

            [amplitude, phase, ~] =calculate_indoor_field(rx_pos,room_dim,source_pos,freq,gamma,Pt,varargin); %计算得出结果

        end


        function  [P1,P2,P3] = cal_rev_power_at_phase(obj,index1,index2,room_dim, source_pos, freq, gamma, Pt, varargin)
            %计算（index1,index2)的阵元阵元处对应的三功率
            %index1,index2为需要获取阵元的位置
            %room_dim,source_pos,freq,gamma,Pt均为calculate_indoor_field函数的参数

            E=[];%每处阵元的振幅与相位组成的复数信息
            for i = 1:8
                for j = 1:8
                    [amplitude, phase] = obj.get_field_at_phase(i,j,room_dim, source_pos, freq, gamma, Pt, varargin);
                    E_t=amplitude*exp(1i*phase);%(i,j)处的阵元接收信号复数信息（隐藏于物理过程中，模拟需要，但现实不能直接测）
                    E=[E;E_t];
                end
            end

            E_ALL=0;%计算所有阵元处接收到的信号的合信号场强
            for k=1:64
                E_ALL=E_ALL+E(k);
            end

            index=8*(index1-1)+index2;
            E_ALL1=E_ALL-E(index)+E(index)*exp(1i*0);%相位旋转0°时合场强
            P1=(abs(E_ALL1))^2;%相位旋转0°时合场强功率

            E_ALL2=E_ALL-E(index)+E(index)*exp(1i*pi/2);%相位旋转90°时合场强
            P2=(abs(E_ALL2))^2;%相位旋转09°时合场强功率

            E_ALL3=E_ALL-E(index)+E(index)*exp(1i*pi);%相位旋转180°时合场强
            P3=(abs(E_ALL3))^2;%相位旋转180°时合场强功率


        end

        function rev_data_array = cal_Rev_Data(obj, room_dim, source_pos, freq, gamma, Pt, varargin)
            % 输出为 64×3：第i行 = 第i个阵元的 [P0, P90, P180]
            % 优化：先一次性算好全部64个阵元的复数场强E，再逐元计算三功率
            % 避免原来每个阵元都重算64次场强的冗余（原来复杂度O(64^2)，现在O(64)）

            % Step1：一次性计算全部64个阵元的复数场强
            E = zeros(64, 1);
            for i = 1:8
                for j = 1:8
                    [amp, ph] = obj.get_field_at_phase(i, j, room_dim, source_pos, freq, gamma, Pt, varargin);
                    E(8*(i-1)+j) = amp * exp(1i*ph);
                end
            end

            % 全部阵元合场强（只算一次）
            E_ALL = sum(E);

            % Step2：逐阵元计算三功率，直接用已有的E和E_ALL
            rev_data_array = zeros(64, 3);
            for idx = 1:64
                E_m = E(idx);
                E_rest = E_ALL - E_m;   % 其余63个阵元的合场强

                P0   = abs(E_rest + E_m * exp(1i*0))^2;
                P90  = abs(E_rest + E_m * exp(1i*pi/2))^2;
                P180 = abs(E_rest + E_m * exp(1i*pi))^2;

                rev_data_array(idx, :) = [P0, P90, P180];
            end
        end
    end

    
end