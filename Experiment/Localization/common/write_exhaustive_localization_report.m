function write_exhaustive_localization_report(file,results)
%WRITE_EXHAUSTIVE_LOCALIZATION_REPORT 输出5159条全流程的总体摘要。

fid=fopen(file,'w','n','UTF-8');
if fid<0,error('ExhaustiveLocalization:ReportOpenFailed','无法写入%s。',file);end
t=results.methodTable; l=results.localizations; g=results.groupSummary; m=results.methodSummary;
fprintf(fid,'# 四分支全方法、全定位组合总体报告\n\n生成时间：%s\n\n',char(datetime('now')));
fprintf(fid,'复响应方法数：%d；每种方法固定运行6个两站、4个三站和1个四站定位，共%d条全流程。\n\n', ...
    height(t),height(l));
fprintf(fid,'其中Branch4方法%d种；功率设计矩阵秩不足的方法%d种，保留在结果中并标记不可恢复。', ...
    nnz(strcmp(t.Branch,'Branch4')),nnz(strcmp(t.Branch,'Branch4')&~t.Recoverable));
fprintf(fid,'频率维统一使用%d个均匀抽取频点。\n\n',numel(results.frequencyHz));
fprintf(fid,'得到数值定位%d条，秩不足连带产生的无效定位%d条；数值定位中有%d条未通过全部射线向前检查。\n\n', ...
    nnz(l.LocalizationValid),nnz(~l.LocalizationValid), ...
    nnz(l.LocalizationValid&~l.AllRaysForward));
fprintf(fid,['“状态数”在下表中特指Location1--4每个阵位各自采用的REV相移观测数，不是参与定位的阵位数。' ...
    '每个相移子集都分别产生4个单站AOA，并固定运行6个两阵位、4个三阵位和1个四阵位定位。' ...
    '四阵位误差统计始终使用Location1--4全部四个阵位。\n\n']);
fprintf(fid,['| 分支 | 每阵位REV相移观测数 | 相移子集数 | 可恢复子集数 | 完成全部11种定位的子集数 | ' ...
    '有效率中位数（跨子集） | 对B1相干中位数（跨子集） | 相位RMSE中位数（跨子集） | ' ...
    '四阵位联合定位误差中位数（跨子集） | 四阵位联合定位误差范围（跨子集） |\n']);
fprintf(fid,'|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for index=1:height(g)
    fprintf(fid,'| %s | %s | %d | %d | %d | %.2f%% | %.3f | %.2f° | %.3f m | %.3f--%.3f m |\n', ...
        g.Branch{index},number_or_dash(g.StateCount(index)),g.MethodCount(index), ...
        g.RecoverableMethodCount(index),g.FullyLocalizedMethodCount(index), ...
        100*g.MedianValidFraction(index),g.MedianBranch1Coherence(index), ...
        g.MedianBranch1PhaseRmseDeg(index),g.MedianFourStationErrorM(index), ...
        g.MinFourStationErrorM(index),g.MaxFourStationErrorM(index));
end

validFour=m(strcmp(m.Branch,'Branch4')&m.FourStationValidCount==1,:);
[~,responseOrder]=sort(validFour.Branch1Coherence,'descend');
fprintf(fid,'\n## Branch4与Branch1复响应最一致的10个观测子集\n\n');
fprintf(fid,'| 方法 | 每阵位REV相移观测数 | 观测编号 | 每阵位使用的相位集合 | 对B1相干 | 相位RMSE | 四阵位联合定位误差 |\n');
fprintf(fid,'|---|---:|---|---|---:|---:|---:|\n');
for rankIndex=1:min(10,numel(responseOrder))
    item=validFour(responseOrder(rankIndex),:);
    source=t(t.MethodIndex==item.MethodIndex,:);
    fprintf(fid,'| %s | %d | %s | %s | %.3f | %.2f° | %.3f m |\n', ...
        item.MethodId{1},item.StateCount,source.ObservationIndices{1},source.PhaseSetDeg{1}, ...
        item.Branch1Coherence,item.Branch1PhaseRmseDeg,item.FourStationErrorM);
end

[~,bestOrder]=sort(validFour.FourStationErrorM,'ascend');
fprintf(fid,'\n## 事后真值误差最小的10个Branch4观测子集\n\n');
fprintf(fid,['下表使用已知真实坐标进行事后排序，只用于暴露误差分布和共同系统偏差，' ...
    '存在选择偏差，不能作为实际未知信源时的相位子集选择规则。\n\n']);
fprintf(fid,'| 方法 | 每阵位REV相移观测数 | 观测编号 | 每阵位使用的相位集合 | 四阵位联合定位误差 | 对B1相干 | 相位RMSE |\n');
fprintf(fid,'|---|---:|---|---|---:|---:|---:|\n');
for rankIndex=1:min(10,numel(bestOrder))
    item=validFour(bestOrder(rankIndex),:);
    source=t(t.MethodIndex==item.MethodIndex,:);
    fprintf(fid,'| %s | %d | %s | %s | %.3f m | %.3f | %.2f° |\n', ...
        item.MethodId{1},item.StateCount,source.ObservationIndices{1},source.PhaseSetDeg{1}, ...
        item.FourStationErrorM,item.Branch1Coherence,item.Branch1PhaseRmseDeg);
end
fprintf(fid,'\n完整结果见 `exhaustive_full_pipeline.csv`，每行就是一条复响应方法×定位组合链路。\n');
fclose(fid);
end

function value=number_or_dash(x)
if isnan(x),value='-';else,value=sprintf('%d',x);end
end
