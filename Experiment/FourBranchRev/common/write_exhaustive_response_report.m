function write_exhaustive_response_report(file,cache)
%WRITE_EXHAUSTIVE_RESPONSE_REPORT 输出全部复响应方法的可读摘要。

fid=fopen(file,'w','n','UTF-8');
if fid<0,error('ExhaustiveREV:ReportOpenFailed','无法写入%s。',file);end
t=cache.methodTable; s=cache.methodSummary;
fprintf(fid,'# 四分支复响应方法穷举报告\n\n生成时间：%s\n\n',char(datetime('now')));
fprintf(fid,'总方法数：%d；Branch1--3各1种，Branch4为9次观测中任选3--9次，共%d种。\n\n', ...
    height(t),nnz(strcmp(t.Branch,'Branch4')));
fprintf(fid,'9次观测中0°与360°名义相位重复，但保留为两个独立实测观测编号。');
fprintf(fid,'功率设计矩阵秩小于3的组合不具备复响应可辨识性，仍保留在总表并标记失败。\n\n');
fprintf(fid,'全部方法统一使用4.5--5.5 GHz内均匀抽取的%d个频点。',numel(cache.frequencyHz));
fprintf(fid,['响应比较在每个位置和频点只用一个对32阵元共有的复标量对齐公共增益与相位零点；' ...
    '相干系数越接近1越好，相位RMSE越接近0°越好。\n\n']);
fprintf(fid,'| 状态数 | 组合数 | 可恢复 | 秩不足 | 有效率中位数 | 对Branch1相干中位数 | 相位RMSE中位数 |\n');
fprintf(fid,'|---:|---:|---:|---:|---:|---:|---:|\n');
for stateCount=3:9
    mask=strcmp(t.Branch,'Branch4')&t.StateCount==stateCount;
    indices=t.MethodIndex(mask);
    fprintf(fid,'| %d | %d | %d | %d | %.2f%% | %.3f | %.2f° |\n',stateCount, ...
        nnz(mask),nnz(t.Recoverable(mask)),nnz(~t.Recoverable(mask)), ...
        100*median(s.MedianValidFraction(indices),'omitnan'), ...
        median(s.Branch1Coherence(indices),'omitnan'), ...
        median(s.Branch1PhaseRmseDeg(indices),'omitnan'));
end
fprintf(fid,['\n观测数增加时，有效率和对Branch1的一致性持续改善；该趋势没有在定位误差中形成同等幅度的收益，' ...
    '定位总体结论应结合`../../Localization/output/EXHAUSTIVE_COMPARISON_REPORT.md`解读。\n']);
fprintf(fid,'\n完整方法定义、逐位置响应比对和逐方法摘要分别见：\n\n');
fprintf(fid,'- `exhaustive_response_methods.csv`\n- `exhaustive_response_agreement.csv`\n');
fprintf(fid,'- `exhaustive_response_summary.csv`\n');
fclose(fid);
end
