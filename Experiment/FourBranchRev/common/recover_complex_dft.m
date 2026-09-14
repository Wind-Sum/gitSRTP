function [h,b,diagnostics]=recover_complex_dft(z,phaseRad,evaluationZ,evaluationPhaseRad)
%RECOVER_COMPLEX_DFT 由一周均匀唯一相位的复数总 S21 提取直流和一阶 DFT。

phaseRad=phaseRad(:);
if size(z,3)~=numel(phaseRad) || numel(phaseRad)<3
    error('ComplexDFT:PhaseCountMismatch','复数状态必须与至少三个相位一一对应。');
end
wrapped=sort(mod(phaseRad,2*pi));
spacing=diff([wrapped;wrapped(1)+2*pi]);
if max(abs(spacing-2*pi/numel(phaseRad)))>1e-8
    error('ComplexDFT:NonuniformPhases','复数DFT要求唯一相位均匀覆盖一周。');
end

negativeWeights=reshape(exp(-1j*phaseRad),1,1,[]);
positiveWeights=reshape(exp(1j*phaseRad),1,1,[]);
b=mean(z,3);
h=mean(z.*negativeWeights,3);
fit=b+h.*positiveWeights;
diagnostics.trainNmseDb=nmse_db(z,fit);

if nargin>=3 && ~isempty(evaluationZ)
    evaluationPhaseRad=evaluationPhaseRad(:);
    evalWeights=reshape(exp(1j*evaluationPhaseRad),1,1,[]);
    diagnostics.evaluationNmseDb=nmse_db(evaluationZ,b+h.*evalWeights);
else
    diagnostics.evaluationNmseDb=NaN;
end
end

function value=nmse_db(observed,predicted)
value=10*log10(sum(abs(observed-predicted).^2,'all')/ ...
    max(sum(abs(observed).^2,'all'),realmin));
end
