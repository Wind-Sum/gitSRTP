function results=localize_branch1(varargin)
%LOCALIZE_BRANCH1 仅运行 Branch1 的 2/3/4 站与状态递增定位。
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
cleanup=onCleanup(@()rmpath(root));
results=run_localization_analysis('Branches',1,'WriteRootOutput',false,varargin{:});
clear cleanup;
end
