function [amplitude, phase, power_dBm] = calculate_indoor_field(rx_pos, room_dim, source_pos, freq, gamma, Pt, varargin)
%% 1. 参数处理
if nargin < 5
    gamma = 0.8;  % 小型室内典型值
end
if nargin < 6
    Pt = 0.1;  % 0.1W = 20dBm
end

% 确保gamma是复数（包含相位）
if isreal(gamma)
    % 电壁反射：幅度为gamma，相位π跳变
    gamma_complex = gamma * exp(1j*pi);
else
    gamma_complex = gamma;
end

% 解析可选参数
max_pathloss_dB = 50;  % 小型室内可提高一些
max_reflections = 5;   % 小型房间通常不超过5次反射
if ~isempty(varargin)
    for i = 1:2:length(varargin)
        if strcmpi(varargin{i}, 'MaxPathLoss')
            max_pathloss_dB = varargin{i+1};
        elseif strcmpi(varargin{i}, 'MaxReflections')
            max_reflections = varargin{i+1};
        end
    end
end

% 物理常数
c = 299792458;          % 光速
lambda = c / freq;      % 波长
k = 2 * pi / lambda;    % 波数

%% 2. 计算直达路径
rx_pos = rx_pos(:);
source_pos = source_pos(:);
direct_distance = norm(rx_pos - source_pos);

% 完整的球面波场强计算
if direct_distance > 0
    % 方法1：标准电磁场公式
    E_direct = sqrt(60 * Pt) * exp(-1j * k * direct_distance) / direct_distance;

    % 方法2：使用自由空间路径损耗公式验证
    % Pt_dBm = 10*log10(Pt*1000);
    % PL_dB = 20*log10(direct_distance) + 20*log10(freq) - 147.55;
    % Pr_dBm = Pt_dBm - PL_dB;
    % Pr = 10^((Pr_dBm-30)/10);
    % E_direct = sqrt(Pr * 240 * pi^2) / lambda;  % 另一种换算
else
    E_direct = 0;
end

% 总场初始化
E_total = E_direct;

%% 3. 生成镜像源（优化生成方法）
% 对于小型房间，生成所有可能的3次以内反射
images = generate_images_small_room(source_pos, room_dim, max_reflections);

%% 4. 计算所有反射路径贡献
path_info = cell(1, length(images) + 1);
path_info{1} = struct('type', 'direct', 'distance', direct_distance, ...
    'order', 0, 'E', E_direct);

% 计算直达路径的接收功率（作为参考）
Pr_direct = (abs(E_direct)^2) / (240*pi) * (lambda^2/(4*pi));
Pr_direct_dBm = 10*log10(Pr_direct * 1000);

% fprintf('直达路径: 距离=%.2fm, 接收功率=%.2fdBm\n', direct_distance, Pr_direct_dBm);

for i = 1:length(images)
    img = images{i};
    distance = norm(rx_pos - img.pos);

    % 跳过无效路径
    if distance == 0 || distance > 3*direct_distance
        continue;
    end

    % 计算该路径场强
    E_path = sqrt(60 * Pt) * exp(-1j * k * distance) / distance;

    % 应用反射系数
    E_path = E_path * (gamma_complex ^ img.order);

    % 重要：添加路径的有效性检查
    path_loss_dB = 20*log10(direct_distance/distance) - 10*log10(abs(gamma_complex)^img.order*2);

    % 只添加显著贡献的路径（比如比直达路径弱30dB以内）
    if abs(E_path) > 0.03 * abs(E_direct)  % 约-30dB
        E_total = E_total + E_path;

        path_info{end+1} = struct('type', 'reflected', ...
            'distance', distance, ...
            'order', img.order, ...
            'E', E_path);
    end
end

%% 5. 计算结果
amplitude = abs(E_total);
phase = angle(E_total);

% 计算接收功率
if amplitude > 0
    % 电场强度 -> 功率密度 -> 接收功率
    % P = |E|² / (2*η)  [W/m²]，其中η=120π≈377Ω
    Pr = (amplitude^2) / (240 * pi) * (lambda^2 / (4*pi));
    power_dBm = 10 * log10(Pr * 1000);
else
    power_dBm = -Inf;
end

% 输出路径信息（可选）
if nargout > 3
    varargout{1} = path_info(~cellfun(@isempty, path_info));
end

end

%% 辅助函数：针对小型房间优化的镜像生成
function images = generate_images_small_room(source_pos, room_dim, max_reflections)
% 小型房间只需考虑前几次反射
Lx = room_dim(1); Ly = room_dim(2); Lz = room_dim(3);
images = {};

% 对于小型房间，我们可以枚举主要反射
% 1次反射：6个面
reflection_orders = {
    [1,0,0], [-1,0,0],  % ±x方向
    [0,1,0], [0,-1,0],  % ±y方向
    [0,0,1], [0,0,-1]   % ±z方向
    };

for order = 1:min(max_reflections, 2)  % 先考虑1-2次反射
    if order == 1
        % 1次反射：6个镜像
        for r = 1:6
            n = reflection_orders{r};
            img_pos = calculate_simple_image(source_pos, room_dim, n);

            img_info.pos = img_pos;
            img_info.order = 1;
            img_info.reflections = abs(n);

            images{end+1} = img_info;
        end
    elseif order == 2
        % 2次反射：主要考虑相邻墙面
        % 例如：x-y平面、x-z平面、y-z平面
        combos = {[1,1,0], [1,-1,0], [-1,1,0], [-1,-1,0], ...
            [1,0,1], [1,0,-1], [-1,0,1], [-1,0,-1], ...
            [0,1,1], [0,1,-1], [0,-1,1], [0,-1,-1]};

        for c = 1:length(combos)
            n = combos{c};
            img_pos = calculate_simple_image(source_pos, room_dim, n);

            img_info.pos = img_pos;
            img_info.order = 2;
            img_info.reflections = abs(n);

            images{end+1} = img_info;
        end
    end
end

% 如果有需要，添加3次反射
if max_reflections >= 3
    corners = [1,1,1; 1,1,-1; 1,-1,1; 1,-1,-1; ...
        -1,1,1; -1,1,-1; -1,-1,1; -1,-1,-1];

    for c = 1:size(corners, 1)
        n = corners(c, :);
        img_pos = calculate_simple_image(source_pos, room_dim, n);

        img_info.pos = img_pos;
        img_info.order = 3;
        img_info.reflections = [1,1,1];  % 三个方向各1次

        images{end+1} = img_info;
    end
end
end

%% 简单的镜像坐标计算
function img_pos = calculate_simple_image(src, room_dim, n)
% n = [nx, ny, nz]，每个分量表示在该方向的反射次数
Lx = room_dim(1); Ly = room_dim(2); Lz = room_dim(3);

x = src(1); y = src(2); z = src(3);

% x方向镜像
if mod(abs(n(1)), 2) == 0
    x_img = n(1) * Lx + x;
else
    x_img = n(1) * Lx + (Lx - x);
end

% y方向镜像
if mod(abs(n(2)), 2) == 0
    y_img = n(2) * Ly + y;
else
    y_img = n(2) * Ly + (Ly - y);
end

% z方向镜像
if mod(abs(n(3)), 2) == 0
    z_img = n(3) * Lz + z;
else
    z_img = n(3) * Lz + (Lz - z);
end

img_pos = [x_img; y_img; z_img];
end