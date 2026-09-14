% ! 房间与阵列部署三维可视化
%
% 绘制 10×8×3 m 房间线框、天花板两端相控阵面及信源位置。

clc; clear; close all;

%% ===================== 房间参数 =====================
Lx = 10; Ly = 8; Lz = 3;

% 房间 8 个顶点
vertices = [0,0,0;  Lx,0,0;  Lx,Ly,0;  0,Ly,0; ...
            0,0,Lz; Lx,0,Lz; Lx,Ly,Lz; 0,Ly,Lz];

% 12 条棱的端点索引
edges = [1,2; 2,3; 3,4; 4,1; ...   % 底面
         5,6; 6,7; 7,8; 8,5; ...   % 顶面
         1,5; 2,6; 3,7; 4,8];      % 垂直棱

%% ===================== 绘制 =====================
figure('Color', 'white', 'Position', [100, 100, 700, 600]);
hold on; grid on; axis equal;
xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
title(sprintf('%d×%d×%d m 房间：天花板相控阵部署与信源', Lx, Ly, Lz));
view(30, 20); box on;

% 房间线框
for i = 1:size(edges, 1)
    p1 = vertices(edges(i, 1), :);
    p2 = vertices(edges(i, 2), :);
    plot3([p1(1) p2(1)], [p1(2) p2(2)], [p1(3) p2(3)], 'k-', 'LineWidth', 1.2);
end

%% 相控阵 1（天花板中部偏左下，水平朝下）
PA_w = 1.5; PA_d = 1.5;
x1 = 2.25; y1 = 1.25; z1 = Lz;
pa1_vtx = [x1,        y1,        z1;
           x1+PA_w,   y1,        z1;
           x1+PA_w,   y1+PA_d,   z1;
           x1,        y1+PA_d,   z1];
patch('Faces', [1,2,3,4], 'Vertices', pa1_vtx, ...
    'FaceColor', 'r', 'EdgeColor', 'k', 'FaceAlpha', 0.5, 'LineWidth', 1.2);

%% 相控阵 2（天花板中部偏右上，水平朝下）
x2 = Lx - PA_w - 2.25; y2 = Ly - PA_d - 1.25; z2 = Lz;
pa2_vtx = [x2,        y2,        z2;
           x2+PA_w,   y2,        z2;
           x2+PA_w,   y2+PA_d,   z2;
           x2,        y2+PA_d,   z2];
patch('Faces', [1,2,3,4], 'Vertices', pa2_vtx, ...
    'FaceColor', 'b', 'EdgeColor', 'k', 'FaceAlpha', 0.5, 'LineWidth', 1.2);

%% 信源（房间内部）
src = [3.5, 4, 2];
[sx, sy, sz] = sphere(20);
r = 0.2;
surf(sx*r+src(1), sy*r+src(2), sz*r+src(3), ...
    'FaceColor', 'g', 'EdgeColor', 'none', 'FaceAlpha', 0.8);
plot3(src(1), src(2), src(3), 'go', 'MarkerSize', 8, 'MarkerFaceColor', 'g');

%% 图例与坐标范围
legend('房间棱边', '相控阵1', '相控阵2', '信源', 'Location', 'northeast');
xlim([-1, Lx+1]); ylim([-1, Ly+1]); zlim([-1, Lz+1]);
hold off;
