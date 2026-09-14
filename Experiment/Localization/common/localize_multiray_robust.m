function result = localize_multiray_robust(centers, directions)
%LOCALIZE_MULTIRAY_ROBUST 用 Huber IRLS 求到多条方向射线距离最小的点。

weights = ones(size(centers,1),1);
position = [NaN, NaN, NaN];
for iteration = 1:15
    previous = position;
    [position, conditionNumber] = weighted_line_lsq(centers, directions, weights);
    delta = position - centers;
    ranges = sum(delta .* directions, 2);
    perpendicular = delta - ranges .* directions;
    residual = sqrt(sum(perpendicular.^2, 2));
    scale = 1.4826 * median(abs(residual - median(residual))) + 1e-9;
    cutoff = max(1.5 * scale, 0.01);
    weights = min(1, cutoff ./ max(residual, realmin));
    if all(isfinite(previous)) && norm(position - previous) < 1e-8, break; end
end

result.positionM = position;
result.rangesM = ranges;
result.rayDistancesM = residual;
result.rmsRayDistanceM = sqrt(mean(residual.^2));
result.conditionNumber = conditionNumber;
result.minimumForwardRangeM = min(ranges);
result.allRaysForward = all(ranges >= 0);
result.iterations = iteration;
result.weights = weights;
result.weightSpread = max(weights) / max(min(weights), realmin);
end

function [position, conditionNumber] = weighted_line_lsq(centers, directions, weights)
a = zeros(3); b = zeros(3,1);
for index = 1:size(centers,1)
    u = directions(index, :).';
    projection = eye(3) - u * u.';
    a = a + weights(index) * projection;
    b = b + weights(index) * projection * centers(index, :).';
end
conditionNumber = cond(a);
position = (pinv(a) * b).';
end
