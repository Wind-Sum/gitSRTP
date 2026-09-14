function analysis=run_closed_loop_analysis(varargin)
%RUN_CLOSED_LOOP_ANALYSIS 一次运行四分支复响应与 2/3/4 站定位闭环。

parser=inputParser;
parser.addParameter('MetricFrequencyCount',51,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
parser.addParameter('FrequencyCount',51,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
parser.addParameter('SweepFrequencyCount',21,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
parser.addParameter('AmplitudeExponent',1,@(x)isnumeric(x)&&isscalar(x)&&x>=0&&x<=1);
parser.addParameter('SaveFigures',true,@(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
parser.parse(varargin{:}); options=parser.Results;

root=fileparts(mfilename('fullpath'));
revDir=fullfile(root,'FourBranchRev');
localizationDir=fullfile(root,'Localization');
addpath(revDir,localizationDir);
pathCleanup=onCleanup(@()rmpath(revDir,localizationDir));

fprintf('第一层：恢复四分支复响应并完成响应级交叉验证。\n');
bundle=run_four_branch_rev_analysis('MetricFrequencyCount',options.MetricFrequencyCount);
fprintf('第二层：完成单站 AOA、2/3/4 站组合和 3--9 相移定位。\n');
localization=run_localization_analysis( ...
    'FrequencyCount',options.FrequencyCount, ...
    'SweepFrequencyCount',options.SweepFrequencyCount, ...
    'AmplitudeExponent',options.AmplitudeExponent, ...
    'SaveFigures',logical(options.SaveFigures));

analysis=struct('responses',bundle,'localization',localization,'options',options);
fprintf('闭环分析完成。\n');
clear pathCleanup;
end
