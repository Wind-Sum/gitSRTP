function coords = read_inc_coords(filename)
% READ_INC_COORDS 读取 FEKO 格式的坐标文件（.inc）
%   coords = read_inc_coords(filename) 返回一个 N×3 的矩阵，
%   每一行对应一个阵元的 [x, y, z] 坐标（单位：米）。
%   文件中的注释行（以 # 开头）会被自动忽略。

    fid = fopen(filename, 'r');
    if fid == -1
        error('无法打开文件: %s', filename);
    end

    coords = [];
    while ~feof(fid)
        line = fgetl(fid);
        % 去除行首尾空格
        line = strtrim(line);
        % 跳过空行和注释行
        if isempty(line) || line(1) == '#'
            continue;
        end
        % 按空白字符分割（空格或制表符）
        tokens = regexp(line, '\s+', 'split');
        if length(tokens) < 3
            continue; % 格式错误，跳过
        end
        % 转换为数值
        x = str2double(tokens{1});
        y = str2double(tokens{2});
        z = str2double(tokens{3});
        if any(isnan([x, y, z]))
            warning('坐标转换失败，跳过该行: %s', line);
            continue;
        end
        coords = [coords; x, y, z];
    end

    fclose(fid);

    if isempty(coords)
        warning('未找到任何有效坐标，请检查文件格式。');
    end
end
