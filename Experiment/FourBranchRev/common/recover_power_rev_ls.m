function [hNormalized,valid,diagnostics] = recover_power_rev_ls( ...
        powerData,phaseRad,minBackgroundMagnitude,evaluationPower,evaluationPhaseRad)
%RECOVER_POWER_REV_LS 仅从任意三个以上相移功率拟合 H/(B+H)。
%
% P(theta)=D+2*Re(C*exp(j*theta)), C=conj(B)H。

if nargin<3, minBackgroundMagnitude=1e-12; end
phaseRad=phaseRad(:);
if size(powerData,3)~=numel(phaseRad) || numel(phaseRad)<3
    error('PowerREV:PhaseCountMismatch','功率状态数必须与至少三个相位一一对应。');
end
if ~isreal(powerData) || any(powerData(:)<0 | ~isfinite(powerData(:)))
    error('PowerREV:InvalidPower','功率必须为有限非负实数。');
end
design=[ones(numel(phaseRad),1),2*cos(phaseRad),-2*sin(phaseRad)];
y=reshape(permute(powerData,[3,1,2]),numel(phaseRad),[]);
parameter=design\y;
shape=size(powerData,[1,2]);
powerDc=reshape(parameter(1,:),shape);
firstHarmonic=reshape(parameter(2,:)+1j*parameter(3,:),shape);
discriminant=powerDc.^2-4*abs(firstHarmonic).^2;
tolerance=1e-10*max(powerDc.^2,realmin);
discriminantValid=discriminant>=-tolerance;
root=sqrt(max(discriminant,0));
elementMagnitude=sqrt(max((powerDc-root)/2,0));
backgroundMagnitude=sqrt(max((powerDc+root)/2,0));
relativeElement=elementMagnitude.*exp(1j*angle(firstHarmonic));
relativeTotal=backgroundMagnitude+relativeElement;
rootSeparation=abs(backgroundMagnitude-elementMagnitude)./... 
    max(backgroundMagnitude+elementMagnitude,realmin);
valid=discriminantValid & backgroundMagnitude>minBackgroundMagnitude & ...
    abs(relativeTotal)>minBackgroundMagnitude & rootSeparation>=0.01;
hNormalized=relativeElement./relativeTotal;
hNormalized(~valid)=complex(NaN,NaN);

fit=design*parameter;
diagnostics.trainNmseDb=nmse_db(y,fit);
diagnostics.powerDc=powerDc;
diagnostics.firstHarmonic=firstHarmonic;
diagnostics.rootSeparation=rootSeparation;
diagnostics.validFraction=mean(valid,'all');
if nargin>=4 && ~isempty(evaluationPower)
    evaluationPhaseRad=evaluationPhaseRad(:);
    evalDesign=[ones(numel(evaluationPhaseRad),1), ...
        2*cos(evaluationPhaseRad),-2*sin(evaluationPhaseRad)];
    evalY=reshape(permute(evaluationPower,[3,1,2]),numel(evaluationPhaseRad),[]);
    diagnostics.evaluationNmseDb=nmse_db(evalY,evalDesign*parameter);
else
    diagnostics.evaluationNmseDb=NaN;
end
end

function value=nmse_db(observed,predicted)
value=10*log10(sum((observed-predicted).^2,'all')/max(sum(observed.^2,'all'),realmin));
end
