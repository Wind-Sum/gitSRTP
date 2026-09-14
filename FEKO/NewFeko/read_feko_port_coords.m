%注意：仅能读取手动创建的port坐标，EDITFEKO中利用已有坐标文件创建的port无法从out文件中读取坐标

function port_coords = read_feko_port_coords(filename)
% 从 FEKO .out 文件提取端口坐标，每个端口只保留一个坐标
% 输入：filename - .out 文件路径
% 输出：port_coords - n×3 矩阵，按端口编号排序（Port1, Port2, ...）

    fid = fopen(filename, 'r');
    if fid == -1
        error('无法打开文件: %s', filename);
    end

    % 使用 containers.Map 存储端口名 -> 坐标
    port_map = containers.Map();

    while ~feof(fid)
        line = fgetl(fid);
        % 查找端口名所在行
        if contains(line, 'Attached to port:')
            % 提取端口名（如 Port1）
            port_name = extract_port_name(line);
            if isempty(port_name)
                continue;
            end
            % 继续读直到找到坐标行
            while ~feof(fid)
                loc_line = fgetl(fid);
                if contains(loc_line, 'Location of the port in m:')
                    % 提取 x, y, z 坐标
                    x = extract_number(loc_line, 'x');
                    y = extract_number(loc_line, 'y');
                    z = extract_number(loc_line, 'z');
                    if ~isnan(x) && ~isnan(y) && ~isnan(z)
                        % 存入 map，如果端口已存在则覆盖（保留最后一次）
                        port_map(port_name) = [x, y, z];
                    end
                    break;
                end
            end
        end
    end
    fclose(fid);

    if port_map.Count == 0
        warning('未找到任何端口坐标信息。');
        port_coords = [];
        return;
    end

    % 按端口编号排序（假设端口名为 Port1, Port2, ...）
    keys_list = keys(port_map);
    % 提取数字部分排序
    nums = zeros(1, length(keys_list));
    for i = 1:length(keys_list)
        num_str = regexp(keys_list{i}, '\d+', 'match');
        if ~isempty(num_str)
            nums(i) = str2double(num_str{1});
        else
            nums(i) = inf;
        end
    end
    [~, idx] = sort(nums);
    sorted_keys = keys_list(idx);
    % 按排序后的键提取坐标
    coords_cell = values(port_map, sorted_keys);
    % 垂直堆叠为矩阵
    port_coords = vertcat(coords_cell{:});
end

function port_name = extract_port_name(line)
% 从 "Attached to port: Port1" 中提取端口名
    tokens = regexp(line, 'Attached to port:\s*(\S+)', 'tokens');
    if isempty(tokens)
        port_name = '';
    else
        port_name = tokens{1}{1};
    end
end

function val = extract_number(line, var)
% 从 "x = 3.50000E+00, y = 6.00000E+00, z = 2.00000E+00" 中提取 var 对应的数值
    pattern = [var, ' = '];
    idx = strfind(line, pattern);
    if isempty(idx)
        val = NaN;
        return;
    end
    rest = line(idx+length(pattern):end);
    [num_str, ~] = strtok(rest, ',');
    val = str2double(num_str);
end
