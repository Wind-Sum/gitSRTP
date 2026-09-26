@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "CODE_DIR=%~dp0"
set "WORK_DIR=%CODE_DIR%Work"
call "%CODE_DIR%config.bat"

if not defined FEKO_RUNNER (
    echo [ERROR] FEKO_RUNNER is not set. Edit config.bat first.
    exit /b 2
)

if not exist "%FEKO_RUNNER%" (
    echo [ERROR] FEKO launcher not found:
    echo %FEKO_RUNNER%
    echo Edit FEKO_RUNNER in config.bat and try again.
    exit /b 3
)

if not exist "%WORK_DIR%\8x8x2_pos1.pre" (
    echo [ERROR] No generated cases were found in Work.
    echo Run gen_multi_pre.m in MATLAB first.
    exit /b 4
)

pushd "%WORK_DIR%"
echo ===== FEKO batch simulation =====

for /f "delims=" %%F in ('dir /b /a:-d "8x8x2_pos*.pre"') do (
    echo [%%date%% %%time%%] Running %%F
    "%FEKO_RUNNER%" "%%F"
    if errorlevel 1 goto :failed
)

popd
echo ===== All FEKO cases completed =====
exit /b 0

:failed
set "FEKO_STATUS=%ERRORLEVEL%"
echo [ERROR] FEKO failed. Exit code: %FEKO_STATUS%
popd
exit /b %FEKO_STATUS%
