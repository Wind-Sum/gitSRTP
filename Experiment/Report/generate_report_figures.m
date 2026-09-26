function generate_report_figures
%GENERATE_REPORT_FIGURES Generate reproducible figures for the measured-data report.
% The script reads only the frozen CSV outputs produced by the standard and
% exhaustive four-branch analysis. It does not modify experimental data.

reportDir = fileparts(mfilename('fullpath'));
experimentDir = fileparts(reportDir);
figureDir = fullfile(reportDir, 'figures');
if ~exist(figureDir, 'dir')
    mkdir(figureDir);
end

set(groot, 'defaultAxesFontName', 'Microsoft YaHei');
set(groot, 'defaultTextFontName', 'Microsoft YaHei');
set(groot, 'defaultAxesFontSize', 10);

localization = readtable(fullfile(experimentDir, 'Localization', 'output', ...
    'localization_2_3_4_stations.csv'), 'TextType', 'string');
doa = readtable(fullfile(experimentDir, 'Localization', 'output', ...
    'doa_results.csv'), 'TextType', 'string');
pairMetrics = readtable(fullfile(experimentDir, 'FourBranchRev', 'output', ...
    'response_pair_metrics.csv'), 'TextType', 'string');
groupSummary = readtable(fullfile(experimentDir, 'Localization', 'output', ...
    'exhaustive_group_summary.csv'), 'TextType', 'string');
algorithmSummary = readtable(fullfile(experimentDir, 'Localization', 'output', ...
    'music_vs_bartlett_group_summary.csv'), 'TextType', 'string');

branches = ["Branch1", "Branch2", "Branch3", "Branch4"];
branchNames = ["B1 复数DFT", "B2 开关法", "B3 哈达玛", "B4 功率REV"];
colors = lines(4);
stationCenters = [1.32 -0.11 1.69; 2.42 -0.11 1.69; ...
    0 0 1.69; -1.21 0 1.69];
truth = [0 3.09 1.50];

%% Figure 1: standard four-branch localization evidence.
fourStation = localization(localization.StationCount == 4, :);
fourStation = reorder_by_branch(fourStation, branches);
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1500 930]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
hold on;
scatter(stationCenters(:,1), stationCenters(:,2), 85, 'k', '^', 'filled', ...
    'DisplayName', '阵列位置');
for idx = 1:4
    text(stationCenters(idx,1) + 0.04, stationCenters(idx,2) - 0.08, ...
        sprintf('L%d', idx), 'FontWeight', 'bold');
end
branch4Doa = doa(doa.Branch == "Branch4", :);
branch4Doa = reorder_by_location(branch4Doa);
for idx = 1:height(branch4Doa)
    rayLength = 3.8;
    rayEnd = stationCenters(idx,:) + rayLength * ...
        [branch4Doa.Ux(idx), branch4Doa.Uy(idx), branch4Doa.Uz(idx)];
    plot([stationCenters(idx,1), rayEnd(1)], ...
        [stationCenters(idx,2), rayEnd(2)], '--', ...
        'Color', [0.55 0.55 0.55], 'LineWidth', 1.1, ...
        'HandleVisibility', 'off');
end
scatter(truth(1), truth(2), 180, 'k', 'p', 'filled', 'DisplayName', '真实位置');
for idx = 1:4
    scatter(fourStation.EstimatedX_M(idx), fourStation.EstimatedY_M(idx), ...
        95, colors(idx,:), 'o', 'filled', 'MarkerEdgeColor', 'k', ...
        'DisplayName', branchNames(idx));
end
xlabel('x 坐标（米）'); ylabel('y 坐标（米）');
title('（a）阵列位置、真值、估计位置与B4测向线');
axis equal; grid on;
xlim([-1.45 2.65]); ylim([-0.30 3.35]);
legend('Location', 'eastoutside');

nexttile;
values = [fourStation.ErrorM, fourStation.RmsRayDistanceM];
bar(values, 'grouped');
set(gca, 'XTick', 1:4, 'XTickLabel', {'B1','B2','B3','B4'});
ylabel('距离（米）');
title('（b）真值误差与射线交汇残差');
legend({'真值误差', '射线均方根残差'}, 'Location', 'northwest');
grid on;
for idx = 1:4
    text(idx - 0.15, fourStation.ErrorM(idx) + 0.025, ...
        sprintf('%.3f', fourStation.ErrorM(idx)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end

nexttile;
coordinates = [truth; [fourStation.EstimatedX_M, ...
    fourStation.EstimatedY_M, fourStation.EstimatedZ_M]];
bar(coordinates, 'grouped');
set(gca, 'XTick', 1:5, 'XTickLabel', {'真值','B1','B2','B3','B4'});
ylabel('坐标（米）');
title('（c）三维坐标对照');
legend({'x', 'y', 'z'}, 'Location', 'northwest');
grid on;

nexttile;
hold on;
locations = 1:4;
for idx = 1:4
    branchDoa = doa(doa.Branch == branches(idx), :);
    branchDoa = reorder_by_location(branchDoa);
    plot(locations, branchDoa.AngularErrorDeg, '-o', ...
        'Color', colors(idx,:), 'LineWidth', 1.8, ...
        'MarkerFaceColor', 'w', 'DisplayName', branchNames(idx));
end
set(gca, 'XTick', locations, 'XTickLabel', {'L1','L2','L3','L4'});
xlabel('阵列位置'); ylabel('DOA角误差（度）');
title('（d）各阵位DOA角误差');
grid on; legend('Location', 'northeast');

sgtitle('四分支Bartlett实测结果（标准51频点）', ...
    'FontWeight', 'bold');
exportgraphics(fig, fullfile(figureDir, 'four_branch_localization.png'), ...
    'Resolution', 240);
close(fig);

%% Figure 2: pairwise response agreement.
coherence = eye(4);
phaseRmse = zeros(4);
for row = 1:height(pairMetrics)
    ia = find(branches == pairMetrics.BranchA(row), 1);
    ib = find(branches == pairMetrics.BranchB(row), 1);
    if isempty(ia) || isempty(ib), continue; end
    pairMask = pairMetrics.BranchA == pairMetrics.BranchA(row) & ...
        pairMetrics.BranchB == pairMetrics.BranchB(row);
    coherence(ia,ib) = median(pairMetrics.MedianCoherence(pairMask), 'omitnan');
    coherence(ib,ia) = coherence(ia,ib);
    phaseRmse(ia,ib) = median(pairMetrics.MedianPhaseRmseDeg(pairMask), 'omitnan');
    phaseRmse(ib,ia) = phaseRmse(ia,ib);
end

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1260 520]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
imagesc(coherence, [0.65 1]); axis image;
colorbar; colormap(gca, parula);
set(gca, 'XTick', 1:4, 'XTickLabel', {'B1','B2','B3','B4'}, ...
    'YTick', 1:4, 'YTickLabel', {'B1','B2','B3','B4'});
title('（a）复相干系数中位数');
write_matrix_values(coherence, '%.3f', 0.82, false);

nexttile;
imagesc(phaseRmse, [0 50]); axis image;
colorbar; colormap(gca, flipud(hot));
set(gca, 'XTick', 1:4, 'XTickLabel', {'B1','B2','B3','B4'}, ...
    'YTick', 1:4, 'YTickLabel', {'B1','B2','B3','B4'});
title('（b）对齐相位均方根误差中位数（度）');
write_matrix_values(phaseRmse, '%.1f', 24, true);

sgtitle('四分支相对复响应两两一致性（四阵位中位数）', ...
    'FontWeight', 'bold');
exportgraphics(fig, fullfile(figureDir, 'response_agreement_matrix.png'), ...
    'Resolution', 240);
close(fig);

%% Figure 3: exhaustive Branch 4 phase-observation summary.
b4 = groupSummary(groupSummary.Branch == "Branch4" & ...
    isfinite(groupSummary.StateCount), :);
b4 = sortrows(b4, 'StateCount');
k = b4.StateCount;

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1400 820]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(k, 100*b4.MedianValidFraction, '-o', 'LineWidth', 2, ...
    'MarkerFaceColor', [0.2 0.55 0.85]);
xlabel('每阵位相移观测数');
ylabel('有效阵元比例中位数（%）'); grid on; xlim([3 9]);
title('（a）功率REV有效率');

nexttile;
plot(k, b4.MedianBranch1Coherence, '-o', 'LineWidth', 2, ...
    'MarkerFaceColor', [0.2 0.55 0.85]);
xlabel('每阵位相移观测数');
ylabel('与B1的复相干系数中位数'); grid on; xlim([3 9]); ylim([0.65 1]);
title('（b）相对复响应一致性');

nexttile;
plot(k, b4.MedianBranch1PhaseRmseDeg, '-o', 'LineWidth', 2, ...
    'MarkerFaceColor', [0.2 0.55 0.85]);
xlabel('每阵位相移观测数');
ylabel('对齐相位均方根误差中位数（度）'); grid on; xlim([3 9]);
title('（c）相对相位误差');

nexttile;
lower = b4.MedianFourStationErrorM - b4.MinFourStationErrorM;
upper = b4.MaxFourStationErrorM - b4.MedianFourStationErrorM;
errorbar(k, b4.MedianFourStationErrorM, lower, upper, '-o', ...
    'LineWidth', 2, 'MarkerFaceColor', [0.2 0.55 0.85], ...
    'CapSize', 8);
xlabel('每阵位相移观测数');
ylabel('四阵位定位误差（米）');
grid on; xlim([3 9]); ylim([0.75 1.28]);
title('（d）可恢复子集的误差中位数与范围');

sgtitle('分支4相移子集响应质量与Bartlett定位（21频点）', ...
    'FontWeight', 'bold');
exportgraphics(fig, fullfile(figureDir, 'phase_observation_summary.png'), ...
    'Resolution', 240);
close(fig);

%% Figure 4: same-response two-algorithm localization comparison.
paired = algorithmSummary(algorithmSummary.Branch == "Branch4" & ...
    algorithmSummary.StationCount == 4 & isfinite(algorithmSummary.StateCount), :);
paired = sortrows(paired, 'StateCount');
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 690]);
hold on;
plot(paired.StateCount, paired.BartlettMedianErrorM, '-o', ...
    'LineWidth', 2.4, 'MarkerSize', 8, 'DisplayName', 'Bartlett常规波束形成');
plot(paired.StateCount, paired.MusicMedianErrorM, '-s', ...
    'LineWidth', 2.4, 'MarkerSize', 8, 'DisplayName', 'MUSIC');
xlabel('每阵位相移观测数');
ylabel('四阵位定位真值误差中位数（米；纵轴局部放大）');
title('相同复响应下两种测向算法的四阵位定位对照');
xticks(3:9); xlim([3 9]); ylim([1.075 1.185]);
grid on; legend('Location', 'southeast');
exportgraphics(fig, fullfile(figureDir, 'dual_algorithm_four_station.png'), ...
    'Resolution', 240);
close(fig);

fprintf('Report figures written to %s\n', figureDir);
end

function tableOut = reorder_by_branch(tableIn, branches)
indices = zeros(numel(branches), 1);
for idx = 1:numel(branches)
    match = find(tableIn.Branch == branches(idx), 1);
    if isempty(match)
        error('Report:MissingBranch', 'Missing %s in standard results.', branches(idx));
    end
    indices(idx) = match;
end
tableOut = tableIn(indices, :);
end

function tableOut = reorder_by_location(tableIn)
locationNumber = nan(height(tableIn), 1);
for idx = 1:height(tableIn)
    token = regexp(tableIn.Location(idx), '\\d+$', 'match', 'once');
    locationNumber(idx) = str2double(token);
end
[~, order] = sort(locationNumber);
tableOut = tableIn(order, :);
end

function write_matrix_values(values, format, threshold, invertContrast)
for row = 1:size(values,1)
    for column = 1:size(values,2)
        if (~invertContrast && values(row,column) > threshold) || ...
                (invertContrast && values(row,column) <= threshold)
            color = 'k';
        else
            color = 'w';
        end
        text(column, row, sprintf(format, values(row,column)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontWeight', 'bold', 'Color', color);
    end
end
end
