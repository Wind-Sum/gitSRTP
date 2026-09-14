function plot_localization_progression(file,results)
%PLOT_LOCALIZATION_PROGRESSION 站数递增和相移观测状态递增定位曲线。

fig=figure('Visible','off','Color','white','Position',[100,100,1400,850]);
layout=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
cfg=results.config; t=results.combinations; colors=lines(4);
active=find(cellfun(@(name)any(strcmp(t.Branch,name)),cfg.branchNames));

ax=nexttile(layout); hold(ax,'on'); grid(ax,'on');
for branchIndex=active
    med=zeros(1,3); low=med; high=med;
    for count=2:4
        mask=strcmp(t.Branch,cfg.branchNames{branchIndex})&t.StationCount==count;
        values=t.ErrorM(mask); med(count-1)=median(values); low(count-1)=min(values); high(count-1)=max(values);
    end
    errorbar(ax,2:4,med,med-low,high-med,'o-','Color',colors(branchIndex,:), ...
        'LineWidth',1.4,'DisplayName',cfg.branchNames{branchIndex});
end
xlabel(ax,'Station count'); ylabel(ax,'Localization error (m)');
title(ax,'2/3/4-station progression'); legend(ax,'Location','best'); xticks(ax,2:4);

ax=nexttile(layout); hold(ax,'on'); grid(ax,'on'); s=results.stateSweepCombinations;
if ~isempty(s)
    for branchIndex=intersect(active,[1,4])
        values=nan(1,7);
        for count=3:9
            mask=strcmp(s.Branch,cfg.branchNames{branchIndex})&s.StateCount==count&s.StationCount==4;
            if any(mask),values(count-2)=s.ErrorM(mask);end
        end
        plot(ax,3:9,values,'o-','Color',colors(branchIndex,:),'LineWidth',1.5, ...
            'DisplayName',cfg.branchNames{branchIndex});
    end
end
xlabel(ax,'Measured phase-state count'); ylabel(ax,'Four-station error (m)');
title(ax,'Phase-observation progression');
if ~isempty(s),legend(ax,'Location','best');end
xticks(ax,3:9);

ax=nexttile(layout); hold(ax,'on'); grid(ax,'on');
for branchIndex=active
    mask=strcmp(t.Branch,cfg.branchNames{branchIndex})&t.StationCount==4;
    scatter(ax,t.EstimatedX_M(mask),t.EstimatedY_M(mask),90,colors(branchIndex,:), ...
        'filled','DisplayName',cfg.branchNames{branchIndex});
end
scatter(ax,cfg.trueSourceM(1),cfg.trueSourceM(2),130,'kp','filled','DisplayName','Truth');
xlabel(ax,'x (m)');ylabel(ax,'y (m)');title(ax,'Four-station estimates (xy)');
axis(ax,'equal');legend(ax,'Location','best');

ax=nexttile(layout); hold(ax,'on'); grid(ax,'on'); d=results.doa;
for branchIndex=active
    mask=strcmp(d.Branch,cfg.branchNames{branchIndex});
    plot(ax,1:nnz(mask),d.AngularErrorDeg(mask),'o-','Color',colors(branchIndex,:), ...
        'LineWidth',1.4,'DisplayName',cfg.branchNames{branchIndex});
end
xlabel(ax,'Location index');ylabel(ax,'DOA angular error (deg)');
title(ax,'Per-location DOA error');xticks(ax,1:4);legend(ax,'Location','best');

title(layout,'Measured four-branch AOA localization progression');
exportgraphics(fig,file,'Resolution',180);close(fig);
end
