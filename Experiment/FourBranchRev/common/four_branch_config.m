function cfg = four_branch_config
%FOUR_BRANCH_CONFIG 四分支恢复与定位共用的冻结实验元数据。

cfg.locationNames = {'Location1','Location2','Location3','Location4'};
cfg.branchNames = {'Branch1','Branch2','Branch3','Branch4'};
cfg.branchLabels = {'ComplexDFT','OnOff','Hadamard','PowerREV'};
cfg.canonicalFields = {'HRevComplex','HDirect','HElement','HRevPower'};
cfg.arrayCentersM = [132,-11,169; 242,-11,169; 0,0,169; -121,0,169]/100;
cfg.trueSourceM = [0,309,150]/100;
cfg.spacingM = 0.035;
port = (1:32).';
column = floor((port-1)/8)+1;
row = mod(port-1,8)+1;
cfg.localElementPositionsM = [(row-4.5)*cfg.spacingM, zeros(32,1), ...
    (2.5-column)*cfg.spacingM];
cfg.stateAdditionOrderDeg = [0,90,180,270,45,135,225,315,360];
cfg.frequencyRangeHz = [4.5e9,5.5e9];
cfg.metricFrequencyCount = 51;
end
