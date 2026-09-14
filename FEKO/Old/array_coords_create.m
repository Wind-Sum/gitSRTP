%============================================================
% 生成两个相控阵的坐标文件（合并到一个 .inc 文件中）
% ============================================================

clear; clc;

%% 参数设置
n = 8;                      % 阵列维数（n×n）
dx = 0.0625;                % X方向阵元间距（米）
dy = 0.0625;                % Y方向阵元间距（米）

% 阵列1起始坐标（左下角第一个阵元）
start1 = [4.5, 3.5, 0.1];   % [x0, y0, z0]
% 阵列2起始坐标（左下角第一个阵元）
start2 = [5.5, 4.5, 5.9];   % [x0, y0, z0]

filename = 'two_arrays_8x8.inc';   % 输出文件名

%% 生成坐标
% 阵列1坐标（行优先：先变X，后变Y）
coords1 = zeros(n*n, 3);
idx = 0;
for i = 1:n
    for j = 1:n
        idx = idx + 1;
        coords1(idx,:) = [start1(1) + (i-1)*dx, ...
                          start1(2) + (j-1)*dy, ...
                          start1(3)];
    end
end

% 阵列2坐标
coords2 = zeros(n*n, 3);
idx = 0;
for i = 1:n
    for j = 1:n
        idx = idx + 1;
        coords2(idx,:) = [start2(1) - (i-1)*dx, ...
                          start2(2) - (j-1)*dy, ...
                          start2(3)];
    end
end

% 合并坐标（先阵列1，后阵列2）
all_coords = [coords1; coords2];

%% 写入文件
fid = fopen(filename, 'w');
if fid == -1
    error('无法创建文件：%s', filename);
end

fprintf(fid, '# X Y Z (米) 两个 %d×%d 阵列，先阵列1后阵列2\n', n, n);
for k = 1:2*n*n
    fprintf(fid, '%.4f %.4f %.4f\n', all_coords(k,1), all_coords(k,2), all_coords(k,3));
end

fclose(fid);
fprintf('坐标文件已生成：%s，共 %d 个阵元（两个 %d×%d 阵列）\n', filename, 2*n*n, n, n);