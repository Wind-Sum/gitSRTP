% 读取 S 参数文件
filename = '8x8_SParameter1.s129p';   % 请替换为实际文件名
sp = sparameters(filename);

% 假设只有一个频率点，取出 S 参数矩阵 (Nports × Nports)
S = squeeze(sp.Parameters);     % 若有多频率点，请改为 S = sp.Parameters(1,:,:); 

% 发射端口为 Port1（索引 1）
tx_idx = 1;

% 预定义相移角度（弧度）
phases = [0, pi/2, pi];         % 0°, 90°, 180°
num_angles = length(phases);
num_elements = 64;

% 提取发射端口到所有端口的复数响应（第一列）
all_resp = S(:, tx_idx);        % （num_elements*2+1）×1 列向量

% 去掉发射端口自身（S11）
all_resp(tx_idx) = [];          % 现在有 num_elements*2 个复数

% 按端口划分：端口2~num_elements+1 是相控阵1，端口num_elements+2~num_elements*2+1 是相控阵2
array1 = all_resp(1:num_elements);        % 端口2~num_elements+1 对应 num_elements 个阵元
array2 = all_resp(num_elements+1:2*num_elements);       % 端口num_elements+2~num_elements*2+1 对应 num_elements 个阵元

x1 = array1(1, :).';
x2 = array2(1, :).';
array1 = x1 / norm(x1);
array2 = x2 / norm(x2);

coords1 = read_feko_port_coords('8x8.out');%读取发射源坐标信息
coords2 = read_inc_coords('two_arrays_8x8.inc');%读取editfeko中批量创建的port的坐标信息
coords = [];
coords = [coords1;coords2];

array1_information=zeros(4,num_elements);%相控阵1的信息，第一行是阵元复数响应，第234行是坐标
for i=1:num_elements
    array1_information(1,i)=array_resp1(i);
    for j=1:3
        array1_information(j+1,i)=coords(i+1,j);
    end
end
array2_information=zeros(4,num_elements);%相控阵2的信息，第一行是阵元复数响应，第234行是坐标
for i=1:num_elements
    array2_information(1,i)=array_resp2(i);
    for j=1:3
        array2_information(j+1,i)=coords(i+1+num_elements,j);
    end
end

disp(array1_information)
disp(array2_information)