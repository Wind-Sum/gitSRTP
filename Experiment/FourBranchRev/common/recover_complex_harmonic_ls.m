function [h,b,diagnostics] = recover_complex_harmonic_ls( ...
        z,phaseRad,evaluationZ,evaluationPhaseRad)
%RECOVER_COMPLEX_HARMONIC_LS 复谐波最小二乘拟合 Z(theta)=B+H*exp(j*theta)。

phaseRad=phaseRad(:);
if size(z,3)~=numel(phaseRad)
    error('ComplexHarmonicLS:PhaseCountMismatch','复数状态数与相位数不一致。');
end
design=[ones(numel(phaseRad),1),exp(1j*phaseRad)];
y=reshape(permute(z,[3,1,2]),numel(phaseRad),[]);
coefficient=design\y;
shape=size(z,[1,2]);
b=reshape(coefficient(1,:),shape);
h=reshape(coefficient(2,:),shape);
fit=design*coefficient;
diagnostics.trainNmseDb=nmse_db(y,fit);

if nargin>=3 && ~isempty(evaluationZ)
    evaluationPhaseRad=evaluationPhaseRad(:);
    evalDesign=[ones(numel(evaluationPhaseRad),1),exp(1j*evaluationPhaseRad)];
    evalY=reshape(permute(evaluationZ,[3,1,2]),numel(evaluationPhaseRad),[]);
    diagnostics.evaluationNmseDb=nmse_db(evalY,evalDesign*coefficient);
else
    diagnostics.evaluationNmseDb=NaN;
end
end

function value=nmse_db(observed,predicted)
value=10*log10(sum(abs(observed-predicted).^2,'all')/max(sum(abs(observed).^2,'all'),realmin));
end
