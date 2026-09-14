function results=localize_branch4(varargin)
%LOCALIZE_BRANCH4 仅运行 Branch4 的 2/3/4 站与状态递增定位。
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
cleanup=onCleanup(@()rmpath(root));
results=run_localization_analysis('Branches',4,'WriteRootOutput',false,varargin{:});
clear cleanup;
end
