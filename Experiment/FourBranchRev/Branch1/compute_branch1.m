function branch=compute_branch1(measurements,schedule)
%COMPUTE_BRANCH1 复数 S21 的 DFT 参考分支及状态递增试验。

branch.name='Branch1'; branch.label='ComplexDFT';
branch.locationNames={measurements.location};
branch.frequencyHz=measurements(1).frequencyHz;
branch.H=cell(4,1); branch.background=cell(4,1);
branch.valid=cell(4,1); branch.sweep=cell(4,numel(schedule));
canonicalSlot=find([schedule.stateCount]==8 & [schedule.uniquePhaseCount]==8,1);
if isempty(canonicalSlot)
    error('ComplexDFT:MissingCanonicalState','缺少8个唯一相位的Branch1 DFT基准。');
end
for locationIndex=1:4
    z=measurements(locationIndex).rev.ZRev;
    measuredPhase=measurements(locationIndex).rev.config.rev.phaseDeg(:).';
    for slot=1:numel(schedule)
        selected=schedule(slot).indices;
        heldOut=setdiff(1:numel(measuredPhase),selected,'stable');
        if schedule(slot).stateCount==8 && schedule(slot).uniquePhaseCount==8
            estimator='ComplexDFT'; stateRole='CanonicalEightUniquePhases';
            [h,b,diagnostics]=recover_complex_dft(z(:,:,selected), ...
                deg2rad(measuredPhase(selected)),z(:,:,heldOut),deg2rad(measuredPhase(heldOut)));
        else
            estimator='ComplexHarmonicLS';
            if schedule(slot).stateCount==9
                stateRole='EightUniquePhasesPlusClosureRepeat';
            else
                stateRole='IncrementalPhaseSubset';
            end
            [h,b,diagnostics]=recover_complex_harmonic_ls(z(:,:,selected), ...
                deg2rad(measuredPhase(selected)),z(:,:,heldOut),deg2rad(measuredPhase(heldOut)));
        end
        item=struct('stateCount',schedule(slot).stateCount,'phaseDeg',measuredPhase(selected), ...
            'uniquePhaseCount',schedule(slot).uniquePhaseCount,'H',h,'background',b, ...
            'valid',isfinite(h),'estimator',estimator,'stateRole',stateRole, ...
            'diagnostics',diagnostics);
        branch.sweep{locationIndex,slot}=item;
    end
    canonical=branch.sweep{locationIndex,canonicalSlot};
    branch.H{locationIndex}=canonical.H;
    branch.background{locationIndex}=canonical.background;
    branch.valid{locationIndex}=canonical.valid;
end
branch.canonicalStateCount=8;
branch.canonicalUniquePhaseCount=8;
branch.canonicalEstimator='ComplexDFT';
end
