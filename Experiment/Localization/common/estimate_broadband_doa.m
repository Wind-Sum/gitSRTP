function doa = estimate_broadband_doa(h, validMask, frequencyHz, ...
        frequencyIndices, elementPositions, cfg, algorithm)
%ESTIMATE_BROADBAND_DOA 宽带 Bartlett 或单快拍 MUSIC 方向余弦搜索。
% 每个频点各有一个复响应向量；MUSIC 使用该向量的秩一投影噪声子空间。

if nargin < 7, algorithm = 'Bartlett'; end
algorithm = validatestring(algorithm, {'Bartlett','Music'});

[uxGrid, uzGrid] = meshgrid(-1:cfg.CoarseDirectionStep:1, ...
    -1:cfg.CoarseDirectionStep:1);
inside = uxGrid.^2 + uzGrid.^2 <= 1;
coarseU = [uxGrid(inside), sqrt(max(0, 1 - uxGrid(inside).^2 - ...
    uzGrid(inside).^2)), uzGrid(inside)];
[coarseScores, ~, ~] = score_directions(coarseU, h, ...
    validMask, frequencyHz, frequencyIndices, elementPositions, cfg, algorithm);
[bestCoarse, bestIndex] = max(coarseScores);
peak = coarseU(bestIndex, :);

span = 2.5 * cfg.CoarseDirectionStep;
ux = max(-1, peak(1)-span):cfg.FineDirectionStep:min(1, peak(1)+span);
uz = max(-1, peak(3)-span):cfg.FineDirectionStep:min(1, peak(3)+span);
[uxFine, uzFine] = meshgrid(ux, uz);
insideFine = uxFine.^2 + uzFine.^2 <= 1;
fineU = [uxFine(insideFine), sqrt(max(0, 1 - uxFine(insideFine).^2 - ...
    uzFine(insideFine).^2)), uzFine(insideFine)];
[fineScores, usedCount, validFraction] = score_directions(fineU, h, ...
    validMask, frequencyHz, frequencyIndices, elementPositions, cfg, algorithm);
[bestScore, bestIndex] = max(fineScores);
bestU = fineU(bestIndex, :);

angularDistance = acosd(max(-1, min(1, fineU * bestU.')));
outsideMainPeak = angularDistance > max(1, 2 * asind(cfg.FineDirectionStep));
if any(outsideMainPeak)
    secondScore = max(fineScores(outsideMainPeak));
else
    secondScore = NaN;
end

doa.direction = bestU;
doa.azimuthDeg = atan2d(bestU(2), bestU(1));
doa.elevationDeg = asind(bestU(3));
doa.peakScore = bestScore;
doa.coarsePeakScore = bestCoarse;
doa.peakToSecondRatio = bestScore / max(secondScore, realmin);
doa.usedFrequencyCount = usedCount;
doa.meanValidElementFraction = validFraction;
doa.algorithm = algorithm;
end

function [scores, usedFrequencyCount, meanValidFraction] = score_directions( ...
        directions, h, validMask, frequencyHz, frequencyIndices, ...
        elementPositions, cfg, algorithm)
c = 299792458;
scores = zeros(size(directions, 1), 1);
usedFrequencyCount = 0;
validFractions = [];
for frequencyIndex = frequencyIndices(:).'
    valid = validMask(:, frequencyIndex) & isfinite(h(:, frequencyIndex));
    if nnz(valid) < cfg.MinValidElements, continue; end
    x = h(valid, frequencyIndex);
    magnitude = abs(x);
    if cfg.AmplitudeExponent == 0
        x = exp(1j * angle(x));
    elseif cfg.AmplitudeExponent ~= 1
        scale = median(magnitude(magnitude > 0));
        if isempty(scale) || ~isfinite(scale), continue; end
        x = (magnitude / scale).^cfg.AmplitudeExponent .* exp(1j * angle(x));
    end
    waveNumber = 2 * pi * frequencyHz(frequencyIndex) / c;
    steering = exp(1j * waveNumber * ...
        (elementPositions(valid, :) * directions.'));
    normalizedPower = (abs(x' * steering).^2).' / ...
        max(nnz(valid) * sum(abs(x).^2), realmin);
    if strcmp(algorithm, 'Music')
        % R=x*x^H 的噪声投影为 I-x*x^H/(x^H*x)。
        % P_MUSIC=1/(a^H*P_noise*a)=1/[N*(1-normalizedPower)]。
        % 这是单次复响应的形式化 MUSIC，不能据此声称多快拍性能。
        scores = scores + 1 ./ max(nnz(valid) * ...
            (1 - min(normalizedPower, 1)), 1e-8);
    else
        scores = scores + normalizedPower;
    end
    usedFrequencyCount = usedFrequencyCount + 1;
    validFractions(end+1) = nnz(valid) / size(h, 1); %#ok<AGROW>
end
if usedFrequencyCount == 0
    error('FourBranch:NoValidFrequency', ...
        '没有频点具备至少 %d 个有效阵元。', cfg.MinValidElements);
end
scores = scores / usedFrequencyCount;
meanValidFraction = mean(validFractions);
end
