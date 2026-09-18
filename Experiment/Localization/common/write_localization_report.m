function write_localization_report(file,results)
%WRITE_LOCALIZATION_REPORT 汇总两站、三站、四站与状态递增定位。

fid=fopen(file,'w','n','UTF-8');
if fid<0,error('Localization:ReportOpenFailed','无法写入 %s。',file);end
cfg=results.config; t=results.combinations;
fprintf(fid,'# 四分支 AOA 逐级定位报告\n\n生成时间：%s\n\n',char(datetime('now')));
fprintf(fid,['两站时取两条无限直线最近点的中点；三站和四站时求到所有方向直线' ...
    '垂距平方和最小的点，并用 Huber IRLS 降低异常射线影响。每个结果同时检查' ...
    '射线参数是否向前，避免把阵列背后的直线交点当作有效 AOA。\n\n']);
fprintf(fid,['射线RMS是定位点到参与定位的各条AOA方向线之垂距的均方根，只衡量射线之间的内部' ...
    '交汇一致性，不等于相对真值的位置误差；多条射线可能一致地交在错误位置。表中的“中位数”' ...
    '是在同一分支、同一站数的全部组合之间取中位数，四站只有一个组合。\n\n']);
fprintf(fid,'## 2/3/4 站逐级结果汇总\n\n');
fprintf(fid,'| 分支 | 站数 | 组合数 | 误差中位数 | 最小误差 | 最大误差 | 射线 RMS 中位数 |\n');
fprintf(fid,'|---|---:|---:|---:|---:|---:|---:|\n');
for branchIndex=1:4
    for stationCount=2:4
        mask=strcmp(t.Branch,cfg.branchNames{branchIndex})&t.StationCount==stationCount;
        if ~any(mask),continue;end
        fprintf(fid,'| %s | %d | %d | %.3f m | %.3f m | %.3f m | %.3f m |\n', ...
            cfg.branchNames{branchIndex},stationCount,nnz(mask),median(t.ErrorM(mask)), ...
            min(t.ErrorM(mask)),max(t.ErrorM(mask)),median(t.RmsRayDistanceM(mask)));
    end
end
fprintf(fid,'\n## 四站定位\n\n| 分支 | 估计坐标 x/y/z (m) | 误差 | 射线 RMS |\n|---|---:|---:|---:|\n');
for branchIndex=1:4
    mask=strcmp(t.Branch,cfg.branchNames{branchIndex})&t.StationCount==4;
    if ~any(mask),continue;end
    fprintf(fid,'| %s | %.3f / %.3f / %.3f | %.3f m | %.3f m |\n', ...
        cfg.branchNames{branchIndex},t.EstimatedX_M(mask),t.EstimatedY_M(mask), ...
        t.EstimatedZ_M(mask),t.ErrorM(mask),t.RmsRayDistanceM(mask));
end

s=results.stateSweepCombinations;
if ~isempty(s)
    fprintf(fid,'\n## Branch1/Branch4 每阵位相移观测状态数对四阵位联合定位的影响\n\n');
    fprintf(fid,['下表每一行始终使用Location1--4全部四个阵位联合定位。' ...
        '“状态数”是每个阵位各自使用的相移观测数，并非参与定位的阵位数。\n\n']);
    fprintf(fid,'| 分支 | 每阵位相移观测状态数 | 每阵位唯一相位数 | 四阵位联合估计坐标 x/y/z (m) | 真值误差 | 射线 RMS |\n');
    fprintf(fid,'|---|---:|---:|---:|---:|---:|\n');
    for branchName={'Branch1','Branch4'}
        for count=3:9
            mask=strcmp(s.Branch,branchName{1})&s.StateCount==count&s.StationCount==4;
            if ~any(mask),continue;end
            fprintf(fid,'| %s | %d | %d | %.3f / %.3f / %.3f | %.3f m | %.3f m |\n', ...
                branchName{1},count,s.UniquePhaseCount(mask),s.EstimatedX_M(mask), ...
                s.EstimatedY_M(mask),s.EstimatedZ_M(mask),s.ErrorM(mask),s.RmsRayDistanceM(mask));
        end
    end
end
fprintf(fid,['\n完整 44 组标准组合及相移扫描下的全部组合分别位于 ' ...
    '`localization_2_3_4_stations.csv` 与 `rev_state_sweep_localization.csv`。\n']);
fclose(fid);
end
