function [pos_est, err] = aoa_localize(az1, el1, p1, az2, el2, p2, true_pos)
% AOA 双站交叉定位：两阵列方向射线最小二乘求交点
%
% 原理：
%   阵列1 方向单位向量 u1，过点 p1 的射线：p1 + t * u1
%   阵列2 方向单位向量 u2，过点 p2 的射线：p2 + s * u2
%   最小二乘解 t,s 满足：[u1, -u2] * [t;s] = p2 - p1
%   估计位置取两条射线上最近点的中点。
%
% 输入：
%   az1, el1 : 阵列1 估计的方位角 / 俯仰角 (°)
%   p1       : 阵列1 几何中心 [x; y; z]
%   az2, el2 : 阵列2 估计的方位角 / 俯仰角 (°)
%   p2       : 阵列2 几何中心 [x; y; z]
%   true_pos : 真实信源位置 [x; y; z]（可选，若提供则计算误差）
%
% 输出：
%   pos_est : 估计位置 [x; y; z]
%   err     : 定位误差 (m)，若未提供 true_pos 则为 NaN

% 方向单位向量
u1 = [cosd(el1)*cosd(az1); cosd(el1)*sind(az1); sind(el1)];
u2 = [cosd(el2)*cosd(az2); cosd(el2)*sind(az2); sind(el2)];

% 检测极端病态几何：两射线几乎共线 → 定位无意义
cos_angle = abs(dot(u1, u2));
if cos_angle > 0.9995
    pos_est = [NaN; NaN; NaN];
    err     = Inf;
    return;
end

% 使用 pinv 稳定求解（替代 warning off + \ 的 hack）
x_sol = pinv([u1, -u2]) * (p2 - p1);

% 估计位置：两条射线上最近点的中点
pos_est = ( (p1 + x_sol(1)*u1) + (p2 + x_sol(2)*u2) ) / 2;

% 误差计算
if nargin >= 7 && ~isempty(true_pos)
    err = norm(true_pos(:) - pos_est(:));
else
    err = NaN;
end
end
