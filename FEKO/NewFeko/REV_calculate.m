function rev_output=REV_calculate(power_matrix)
    Size=size(power_matrix);
    n=Size(2);%n是阵元个数
    rev_output = zeros(1, n);
    for i = 1 : n
    P0   = power_matrix(1, i);   % 第 i 阵元，相位扰动 0°   时的合成场功率
    P90  = power_matrix(2, i);   % 第 i 阵元，相位扰动 90°  时的合成场功率
    P180 = power_matrix(3, i);   % 第 i 阵元，相位扰动 180° 时的合成场功率
    [E_mr, ~, ~, ~] = single_rev(P0, P90, P180);
    rev_output(i) = E_mr;
    end
end

function [E_mr, E_m, E_m_bar, phi_diff] = single_rev(P0, P90, P180)
% single_rev  由单个阵元的三功率解算其相对复数场
%
% 输入：P0, P90, P180 — 相位扰动 0°/90°/180° 时测得的合成场功率 (W)
% 输出：
%   E_mr     - 阵元相对场 k_m × e^(jX_m)（复数）
%   E_m      - 阵元场振幅
%   E_m_bar  - 其余阵元合成场振幅
%   phi_diff - 阵元与其余合成场的相位差 (rad)

% 步骤1：构建并求解线性方程组 A*X = P
A = [1,  1,   1 ;
     1, -1j,  1j;
     1, -1,  -1 ];
P = [P0; P90; P180];
X = A \ P;
x1 = X(1);
x2 = X(2);

% 步骤2：计算相位差
phi_diff = angle(x2);

% 步骤3：求解振幅
E_m_bar   = (sqrt(abs(x1) + 2*abs(x2)) + sqrt(abs(x1) - 2*abs(x2))) / 2;
sqrt_term =  sqrt(abs(x1) + 2*abs(x2)) - sqrt(abs(x1) - 2*abs(x2));
E_m       = sqrt_term / 2;

% 步骤4：计算相对场
denominator = E_m + E_m_bar * exp(1j * phi_diff);
E_mr = E_m / denominator;

end
