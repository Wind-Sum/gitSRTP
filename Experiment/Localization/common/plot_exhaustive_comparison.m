function plot_exhaustive_comparison(file,results)
%PLOT_EXHAUSTIVE_COMPARISON 绘制Branch4子集穷举的总体分布。

m=results.methodSummary; g=results.groupSummary;
b4=m(strcmp(m.Branch,'Branch4')&m.Recoverable,:);
fig=figure('Visible','off','Color','white','Position',[100,100,1400,850]);
layout=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax=nexttile(layout); grid(ax,'on'); hold(ax,'on');
boxchart(ax,b4.StateCount,b4.Branch1Coherence);
xlabel(ax,'Selected observation count');ylabel(ax,'Coherence with Branch1');
title(ax,'Response agreement distribution');xticks(ax,3:9);

ax=nexttile(layout); grid(ax,'on'); hold(ax,'on');
valid=b4.FourStationValidCount==1;
scatter(ax,b4.Branch1Coherence(valid),b4.FourStationErrorM(valid),18, ...
    b4.StateCount(valid),'filled');
colorbar(ax);xlabel(ax,'Coherence with Branch1');ylabel(ax,'Four-station error (m)');
title(ax,'Response agreement versus localization');

ax=nexttile(layout); grid(ax,'on'); hold(ax,'on');
plot(ax,g.StateCount(4:end),g.MedianTwoStationErrorM(4:end),'o-','LineWidth',1.3,'DisplayName','2 stations');
plot(ax,g.StateCount(4:end),g.MedianThreeStationErrorM(4:end),'o-','LineWidth',1.3,'DisplayName','3 stations');
plot(ax,g.StateCount(4:end),g.MedianFourStationErrorM(4:end),'o-','LineWidth',1.3,'DisplayName','4 stations');
xlabel(ax,'Selected observation count');ylabel(ax,'Median localization error (m)');
title(ax,'Localization error by state count');legend(ax,'Location','best');xticks(ax,3:9);

ax=nexttile(layout); grid(ax,'on'); hold(ax,'on');
bar(ax,g.StateCount(4:end),[g.RecoverableMethodCount(4:end), ...
    g.MethodCount(4:end)-g.RecoverableMethodCount(4:end)],'stacked');
xlabel(ax,'Selected observation count');ylabel(ax,'Method count');
title(ax,'Recoverable and rank-deficient subsets');legend(ax,{'Recoverable','Rank deficient'},'Location','best');
xticks(ax,3:9);

title(layout,sprintf('%d response methods x 11 localization combinations',height(m)));
exportgraphics(fig,file,'Resolution',180);close(fig);
end
