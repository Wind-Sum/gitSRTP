function images = generate_image_sources(src, room_dim, max_reflections)
% 为给定信源位置生成镜像源列表（1~3 次反射的镜像法）
%
% 输入：
%   src             : 信源坐标 [x; y; z]
%   room_dim        : 房间尺寸 [Lx, Ly, Lz] (m)
%   max_reflections : 最大反射次数 (1~3)
%
% 输出：
%   images : cell 数组，每个元素为 struct('pos', [x;y;z], 'order', 反射阶数)

if nargin < 3, max_reflections = 3; end

Lx = room_dim(1); Ly = room_dim(2); Lz = room_dim(3);
images = {};

% 1 次反射：6 个墙面
orders_1 = {[1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1]};
for r = 1:6
    n = orders_1{r};
    images{end+1} = struct('pos', compute_image_pos(src, room_dim, n), 'order', 1);
end

if max_reflections >= 2
    % 2 次反射：相邻墙面组合（12 种）
    combos_2 = {[1,1,0],[1,-1,0],[-1,1,0],[-1,-1,0], ...
                [1,0,1],[1,0,-1],[-1,0,1],[-1,0,-1], ...
                [0,1,1],[0,1,-1],[0,-1,1],[0,-1,-1]};
    for c = 1:length(combos_2)
        n = combos_2{c};
        images{end+1} = struct('pos', compute_image_pos(src, room_dim, n), 'order', 2);
    end
end

if max_reflections >= 3
    % 3 次反射：对角角落（8 种）
    corners = [1,1,1; 1,1,-1; 1,-1,1; 1,-1,-1; ...
              -1,1,1; -1,1,-1; -1,-1,1; -1,-1,-1];
    for c = 1:size(corners, 1)
        n = corners(c, :);
        images{end+1} = struct('pos', compute_image_pos(src, room_dim, n), 'order', 3);
    end
end
end


function pos = compute_image_pos(src, room_dim, n)
% 根据反射次数向量计算镜像源坐标
Lx = room_dim(1); Ly = room_dim(2); Lz = room_dim(3);
x = src(1); y = src(2); z = src(3);

x_img = mirror_coord(x, Lx, n(1));
y_img = mirror_coord(y, Ly, n(2));
z_img = mirror_coord(z, Lz, n(3));

pos = [x_img; y_img; z_img];
end


function c_img = mirror_coord(c, L, n)
% 单轴镜像坐标计算
if mod(abs(n), 2) == 0
    c_img = n * L + c;
else
    c_img = n * L + (L - c);
end
end
