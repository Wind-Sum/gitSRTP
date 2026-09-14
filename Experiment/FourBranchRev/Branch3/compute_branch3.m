function branch=compute_branch3(measurements)
%COMPUTE_BRANCH3 从实测码字响应重新 Hadamard 解码。

branch.name='Branch3'; branch.label='Hadamard';
branch.locationNames={measurements.location};
branch.frequencyHz=measurements(1).frequencyHz;
branch.H=cell(4,1); branch.valid=cell(4,1); branch.decodeRelativeError=zeros(4,1);
for locationIndex=1:4
    r=measurements(locationIndex).hadamard;
    h=(r.codebook'*r.YPattern)/size(r.codebook,1);
    branch.H{locationIndex}=h;
    branch.valid{locationIndex}=isfinite(h);
    branch.decodeRelativeError(locationIndex)=norm(h(:)-r.HElement(:))/max(norm(r.HElement(:)),realmin);
end
end
