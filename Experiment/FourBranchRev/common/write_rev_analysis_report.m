function write_rev_analysis_report(file,bundle)
%WRITE_REV_ANALYSIS_REPORT 输出四分支复响应与状态递增报告。

fid=fopen(file,'w','n','UTF-8');
if fid<0,error('FourBranchRev:ReportOpenFailed','无法写入 %s。',file);end
fprintf(fid,'# 四分支复响应恢复与相移级数分析\n\n');
fprintf(fid,'生成时间：%s\n\n',char(datetime('now')));
fprintf(fid,'## 分支定义\n\n');
fprintf(fid,'- Branch1：8个唯一相位复数 S21 的一阶 DFT参考。\n- Branch2：On/Off 逐阵元直接复响应。\n');
fprintf(fid,'- Branch3：Hadamard 正交解码复响应。\n- Branch4：严格仅从 `|ZRev|^2` 恢复 `H/(B+H)`。\n\n');
fprintf(fid,'相移递增顺序为 `0/90/180 -> +270 -> +45/+135/+225/+315 -> +360`。');
fprintf(fid,['Branch1正式结果只用8个唯一相位做DFT；Branch4正式结果只用相同8相位做功率REV。' ...
    '第9次360°与0°同相，仅在状态递增试验中作为重复观测，并用于闭合一致性检查。\n\n']);

fprintf(fid,'## 四分支两两复响应一致性（四站中位数）\n\n');
fprintf(fid,['对每个位置和频点，将两个分支的32阵元复响应记为 `a`、`b`，只使用一个对所有阵元共有的' ...
    '复标量 `q=(a^H b)/(a^H a)` 对齐公共增益与公共相位零点。相干系数越接近1越好；' ...
    '对齐相位RMSE和幅度NRMSE越接近0越好；复数NMSE越负越好。该比较验证阵元间相对幅相结构，' ...
    '不验证不可辨识的绝对公共增益和相位。表内先对频点取中位数，再对四个位置取中位数。\n\n']);
fprintf(fid,'| 分支对 | 相干系数 | 对齐相位 RMSE | 复数 NMSE | 幅度 NRMSE |\n|---|---:|---:|---:|---:|\n');
pairs=nchoosek(1:4,2); t=bundle.pairMetrics;
for k=1:size(pairs,1)
    mask=strcmp(t.BranchA,bundle.config.branchNames{pairs(k,1)})& ...
        strcmp(t.BranchB,bundle.config.branchNames{pairs(k,2)});
    fprintf(fid,'| %s-%s | %.3f | %.2f° | %.2f dB | %.3f |\n', ...
        bundle.config.branchNames{pairs(k,1)},bundle.config.branchNames{pairs(k,2)}, ...
        median(t.MedianCoherence(mask),'omitnan'),median(t.MedianPhaseRmseDeg(mask),'omitnan'), ...
        median(t.MedianComplexNmseDb(mask),'omitnan'),median(t.MedianMagnitudeNrmse(mask),'omitnan'));
end

fprintf(fid,'\n## Branch1/Branch4 相移观测状态递增（四站中位数）\n\n');
fprintf(fid,['Branch1的3--7状态采用复谐波最小二乘，8状态为正式复数DFT基准；' ...
    '9状态表示8个唯一相位加一次360°闭合重复，不是9个唯一相位。\n\n']);
fprintf(fid,'| 方法 | 状态数 | 唯一相位 | 有效率 | 对 Branch1 相干 | 对 Branch1 相位 RMSE | 留出状态拟合 NMSE |\n');
fprintf(fid,'|---|---:|---:|---:|---:|---:|---:|\n');
s=bundle.sweepMetrics;
for branchName={'Branch1','Branch4'}
    for stateCount=3:9
        mask=strcmp(s.Branch,branchName{1})&s.StateCount==stateCount;
        fprintf(fid,'| %s | %d | %d | %.2f%% | %.3f | %.2f° | %.2f dB |\n', ...
            branchName{1},stateCount,round(median(s.UniquePhaseCount(mask))), ...
            100*median(s.ValidFraction(mask),'omitnan'), ...
            median(s.VsBranch1Coherence(mask),'omitnan'), ...
            median(s.VsBranch1PhaseRmseDeg(mask),'omitnan'), ...
            median(s.HeldOutFitNmseDb(mask),'omitnan'));
    end
end
fprintf(fid,'\n详细到每个位置的数据见 `response_pair_metrics.csv` 和 `rev_state_sweep_metrics.csv`。\n');
fclose(fid);
end
