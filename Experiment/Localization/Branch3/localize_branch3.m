function results=localize_branch3(varargin)
%LOCALIZE_BRANCH3 仅运行 Branch3 的 2/3/4 站定位。
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
cleanup=onCleanup(@()rmpath(root));
results=run_localization_analysis('Branches',3,'WriteRootOutput',false,varargin{:});
clear cleanup;
end
