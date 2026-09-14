function plot_response_progression(file,bundle)
%PLOT_RESPONSE_PROGRESSION 展示功率 REV 随相移状态增加的响应质量。

fig=figure('Visible','off','Color','white','Position',[100,100,1350,780]);
layout=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
s=bundle.sweepMetrics; colors=lines(4);
quantities={'ValidFraction','VsBranch1Coherence','VsBranch1PhaseRmseDeg','HeldOutFitNmseDb'};
ylabels={'Valid fraction','Coherence with Branch1','Aligned phase RMSE (deg)','Held-out power-fit NMSE (dB)'};
titles={'Power REV validity','Power REV complex agreement','Power REV phase agreement','Power-model predictive fit'};
for panel=1:4
    ax=nexttile(layout);hold(ax,'on');grid(ax,'on');
    for locationIndex=1:4
        mask=strcmp(s.Branch,'Branch4')&strcmp(s.Location,bundle.config.locationNames{locationIndex});
        plot(ax,s.StateCount(mask),s.(quantities{panel})(mask),'o-', ...
            'Color',colors(locationIndex,:),'LineWidth',1.3, ...
            'DisplayName',bundle.config.locationNames{locationIndex});
    end
    xlabel(ax,'Measured phase-state count');ylabel(ax,ylabels{panel});
    title(ax,titles{panel});xticks(ax,3:9);
    if panel==1,legend(ax,'Location','best');end
end
title(layout,'Branch4 response quality versus REV phase-state count');
exportgraphics(fig,file,'Resolution',180);close(fig);
end
