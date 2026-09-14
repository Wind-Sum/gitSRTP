function branch=compute_branch2(measurements)
%COMPUTE_BRANCH2 On/Off 逐阵元直接复响应参考分支。

branch.name='Branch2'; branch.label='OnOff';
branch.locationNames={measurements.location};
branch.frequencyHz=measurements(1).frequencyHz;
branch.H=cell(4,1); branch.valid=cell(4,1);
for locationIndex=1:4
    branch.H{locationIndex}=measurements(locationIndex).onoff.HDirect;
    branch.valid{locationIndex}=isfinite(branch.H{locationIndex});
end
end
