function plot_exhaustive_comparison(file,results)
%PLOT_EXHAUSTIVE_COMPARISON 绘制Branch4子集穷举的总体分布。

m=results.methodSummary; g=results.groupSummary;
b4=m(strcmp(m.Branch,'Branch4')&m.Recoverable,:);
fig=figure('Visible','off','Color','white','Position',[100,100,1400,850]);
set(fig,'DefaultAxesFontName','Microsoft YaHei','DefaultTextFontName','Microsoft YaHei');
layout=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax=nexttile(layout); grid(ax,'on'); hold(ax,'on');
boxchart(ax,b4.StateCount,b4.Branch1Coherence);
xlabel(ax,'每阵位相移观测数');ylabel(ax,'与B1的复相干系数');
title(ax,'复响应一致性分布');xticks(ax,3:9);

ax=nexttile(layout); grid(ax,'on'); hold(ax,'on');
valid=b4.FourStationValidCount==1;
scatter(ax,b4.Branch1Coherence(valid),b4.FourStationErrorM(valid),18, ...
    b4.StateCount(valid),'filled');
c=colorbar(ax);c.Label.String='每阵位相移观测数';
xlabel(ax,'与B1的复相干系数');ylabel(ax,'四阵位定位误差（米）');
title(ax,'复响应一致性与定位误差');

ax=nexttile(layout); grid(ax,'on'); hold(ax,'on');
plot(ax,g.StateCount(4:end),g.MedianTwoStationErrorM(4:end),'o-','LineWidth',1.3,'DisplayName','两阵位');
plot(ax,g.StateCount(4:end),g.MedianThreeStationErrorM(4:end),'o-','LineWidth',1.3,'DisplayName','三阵位');
plot(ax,g.StateCount(4:end),g.MedianFourStationErrorM(4:end),'o-','LineWidth',1.3,'DisplayName','四阵位');
xlabel(ax,'每阵位相移观测数');ylabel(ax,'定位误差中位数（米）');
title(ax,'不同相移观测数的定位误差');legend(ax,'Location','best');xticks(ax,3:9);

ax=nexttile(layout); grid(ax,'on'); hold(ax,'on');
bar(ax,g.StateCount(4:end),[g.RecoverableMethodCount(4:end), ...
    g.MethodCount(4:end)-g.RecoverableMethodCount(4:end)],'stacked');
xlabel(ax,'每阵位相移观测数');ylabel(ax,'方法数');
title(ax,'可恢复与秩不足的相移子集');legend(ax,{'可恢复','秩不足'},'Location','best');
xticks(ax,3:9);

title(layout,sprintf('%d种复响应方法、每种11个Bartlett定位组合',height(m)));
exportgraphics(fig,file,'Resolution',180);close(fig);
end
