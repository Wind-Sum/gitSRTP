% RUN_PIPELINE 生成算例、调用 FEKO 批量求解并完成 MATLAB 后处理。
% 使用前只需在 config.bat 中设置 FEKO_RUNNER。

code_dir = fileparts(mfilename('fullpath'));
addpath(code_dir);

gen_multi_pre();

code_dir = fileparts(mfilename('fullpath'));
runner = fullfile(code_dir, 'run_all.bat');
command = sprintf('cmd /c ""%s""', runner);
[status, command_output] = system(command, '-echo');
if status ~= 0
    error('FEKO 批量仿真失败（退出码 %d）。\n%s', status, command_output);
end

run(fullfile(code_dir, 'batch_process.m'));

fprintf('\n完整 FEKO + MATLAB 流程已完成。结果位于：%s\n', ...
    fullfile(code_dir, 'Output'));
