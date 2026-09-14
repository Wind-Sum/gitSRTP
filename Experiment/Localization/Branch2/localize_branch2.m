function results=localize_branch2(varargin)
%LOCALIZE_BRANCH2 仅运行 Branch2 的 2/3/4 站定位。
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
cleanup=onCleanup(@()rmpath(root));
results=run_localization_analysis('Branches',2,'WriteRootOutput',false,varargin{:});
clear cleanup;
end
