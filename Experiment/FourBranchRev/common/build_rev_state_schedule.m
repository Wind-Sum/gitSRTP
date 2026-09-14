function schedule = build_rev_state_schedule(measuredPhaseDeg,additionOrderDeg)
%BUILD_REV_STATE_SCHEDULE 构造 3--9 状态的嵌套相移集合。

measuredPhaseDeg = measuredPhaseDeg(:).';
indices = zeros(size(additionOrderDeg));
for k=1:numel(additionOrderDeg)
    [errorDeg,index] = min(abs(measuredPhaseDeg-additionOrderDeg(k)));
    if errorDeg>1e-6
        error('FourBranchRev:MissingPhase','实测状态中缺少 %.1f°。',additionOrderDeg(k));
    end
    indices(k)=index;
end
if numel(unique(indices))~=numel(indices)
    error('FourBranchRev:DuplicateScheduleIndex','相移递增顺序映射到重复实测列。');
end
schedule = repmat(struct(),7,1);
for stateCount=3:9
    slot=stateCount-2;
    schedule(slot).stateCount=stateCount;
    schedule(slot).indices=indices(1:stateCount);
    schedule(slot).phaseDeg=measuredPhaseDeg(schedule(slot).indices);
    schedule(slot).phaseRad=deg2rad(schedule(slot).phaseDeg);
    schedule(slot).uniquePhaseCount=numel(unique(mod(schedule(slot).phaseDeg,360)));
    schedule(slot).label=strjoin(compose('%g',schedule(slot).phaseDeg),'/');
end
end
