% 清空环境
clear; close all; clc;

%% 房间参数
Lx = 10;   % x方向长度
Ly = 8;    % y方向长度
Lz = 3;    % z方向高度

% 定义房间8个顶点坐标
vertices = [0,0,0; Lx,0,0; Lx,Ly,0; 0,Ly,0; ...  % 底面四个点
            0,0,Lz; Lx,0,Lz; Lx,Ly,Lz; 0,Ly,Lz];   % 顶面四个点

% 定义12条棱的顶点索引
edges = [1,2; 2,3; 3,4; 4,1; ...   % 底面
         5,6; 6,7; 7,8; 8,5; ...   % 顶面
         1,5; 2,6; 3,7; 4,8];      % 垂直棱

%% 绘制房间线框
figure('Color','white');
hold on; grid on; axis equal;
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
title('10×8×3 房间：对角线两端相控阵与内部点源');
view(3);                % 三维视角
box on;

% 绘制棱
for i = 1:size(edges,1)
    p1 = vertices(edges(i,1),:);
    p2 = vertices(edges(i,2),:);
    plot3([p1(1) p2(1)], [p1(2) p2(2)], [p1(3) p2(3)], 'k-', 'LineWidth', 1.5);
end

%% 相控阵1：位于左下前下角（原点附近）
% 定义相控阵矩形面的四个顶点（放在地板上，尺寸2×2）
PA1_width = 2;        % 宽度（x方向）
PA1_depth = 2;        % 深度（y方向）
x1 = 0;
y1 = 0;
z1 = 0;               % 地板平面
% 矩形四个顶点（逆时针顺序）
PA1_vertices = [x1, y1, z1;
                x1+PA1_width, y1, z1;
                x1+PA1_width, y1+PA1_depth, z1;
                x1, y1+PA1_depth, z1];
% 绘制相控阵面（带半透明红色）
patch('Faces', [1,2,3,4], 'Vertices', PA1_vertices, ...
      'FaceColor', 'r', 'EdgeColor', 'k', 'FaceAlpha', 0.6, 'LineWidth', 1.5);

%% 相控阵2：位于右上后上角（对角顶点）
% 放在天花板上，尺寸2×2
PA2_width = 2;
PA2_depth = 2;
x2 = Lx - PA2_width;   % 8
y2 = Ly - PA2_depth;   % 6
z2 = Lz;               % 天花板平面
PA2_vertices = [x2, y2, z2;
                x2+PA2_width, y2, z2;
                x2+PA2_width, y2+PA2_depth, z2;
                x2, y2+PA2_depth, z2];
patch('Faces', [1,2,3,4], 'Vertices', PA2_vertices, ...
      'FaceColor', 'b', 'EdgeColor', 'k', 'FaceAlpha', 0.6, 'LineWidth', 1.5);

%% 点源：位于房间内部某处（例如几何中心附近）
point_source = [3, 2, 1.5];   % x=5, y=4, z=1.5
% 绘制一个小球体表示点源
[sx, sy, sz] = sphere(20);     % 生成球面网格
r = 0.2;                       % 半径
sx = sx * r + point_source(1);
sy = sy * r + point_source(2);
sz = sz * r + point_source(3);
surf(sx, sy, sz, 'FaceColor', 'g', 'EdgeColor', 'none', 'FaceAlpha', 0.8);
% 可选：在球心加一个点
plot3(point_source(1), point_source(2), point_source(3), 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g');

%% 图形美化
% 设置坐标轴范围
xlim([-1, Lx+1]);
ylim([-1, Ly+1]);
zlim([-1, Lz+1]);
% 添加图例（手动创建）
% 注意：图例会受patch影响，这里简单添加文本说明
legend('房间棱边', '相控阵1 (原点)', '相控阵2 (对角)', '点源', 'Location', 'northeast');
% 调整视角使立体感更强
view(45, 30);
hold off;