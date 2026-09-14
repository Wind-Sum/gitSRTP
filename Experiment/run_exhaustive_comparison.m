function results=run_exhaustive_comparison(varargin)
%RUN_EXHAUSTIVE_COMPARISON 运行469种复响应方法乘11种定位组合的完整比较。

parser=inputParser;
parser.addParameter('FrequencyCount',21,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
parser.addParameter('UseParallel',true,@(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
parser.addParameter('ParallelWorkers',4,@(x)isnumeric(x)&&isscalar(x)&&x>=1);
parser.addParameter('SaveFigure',true,@(x)islogical(x)||(isnumeric(x)&&isscalar(x)));
parser.parse(varargin{:}); options=parser.Results;

root=fileparts(mfilename('fullpath'));
responseRoot=fullfile(root,'FourBranchRev'); localizationRoot=fullfile(root,'Localization');
addpath(responseRoot,localizationRoot);
pathCleanup=onCleanup(@()rmpath(responseRoot,localizationRoot));

run_exhaustive_response_methods('FrequencyCount',options.FrequencyCount);
results=run_exhaustive_localization('UseParallel',logical(options.UseParallel), ...
    'ParallelWorkers',options.ParallelWorkers,'SaveFigure',logical(options.SaveFigure));
fprintf('完整穷举闭环结束：%d种复响应方法，%d条定位链。\n', ...
    height(results.methodTable),height(results.localizations));
clear pathCleanup;
end
