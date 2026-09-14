function branch=compute_branch4(measurements,schedule)
%COMPUTE_BRANCH4 严格仅由 |ZRev|^2 恢复 H/(B+H) 的验证分支。

branch.name='Branch4'; branch.label='PowerREV';
branch.locationNames={measurements.location};
branch.frequencyHz=measurements(1).frequencyHz;
branch.H=cell(4,1); branch.valid=cell(4,1); branch.sweep=cell(4,numel(schedule));
canonicalSlot=find([schedule.stateCount]==8 & [schedule.uniquePhaseCount]==8,1);
if isempty(canonicalSlot)
    error('PowerREV:MissingCanonicalState','缺少8个唯一相位的Branch4功率REV基准。');
end
for locationIndex=1:4
    r=measurements(locationIndex).rev;
    powerData=abs(r.ZRev).^2; % 此行之后不再访问 ZRev 的复数相位。
    measuredPhase=r.config.rev.phaseDeg(:).';
    minBackground=r.config.rev.minBackgroundMagnitude;
    for slot=1:numel(schedule)
        selected=schedule(slot).indices;
        heldOut=setdiff(1:numel(measuredPhase),selected,'stable');
        [h,valid,diagnostics]=recover_power_rev_ls(powerData(:,:,selected), ...
            deg2rad(measuredPhase(selected)),minBackground, ...
            powerData(:,:,heldOut),deg2rad(measuredPhase(heldOut)));
        if schedule(slot).stateCount==8
            stateRole='CanonicalEightUniquePhases';
        elseif schedule(slot).stateCount==9
            stateRole='EightUniquePhasesPlusClosureRepeat';
        else
            stateRole='IncrementalPhaseSubset';
        end
        item=struct('stateCount',schedule(slot).stateCount,'phaseDeg',measuredPhase(selected), ...
            'uniquePhaseCount',schedule(slot).uniquePhaseCount,'H',h,'valid',valid, ...
            'estimator','PowerREV','stateRole',stateRole,'diagnostics',diagnostics);
        branch.sweep{locationIndex,slot}=item;
    end
    canonical=branch.sweep{locationIndex,canonicalSlot};
    branch.H{locationIndex}=canonical.H;
    branch.valid{locationIndex}=canonical.valid;
end
branch.canonicalStateCount=8;
branch.canonicalUniquePhaseCount=8;
branch.canonicalEstimator='PowerREV';
end
