@echo off
rem ============================================================================
rem project_mode.cmd
rem Project-mode Tcl caller for the synthesis training demo.
rem
rem Usage:
rem   project_mode.cmd create <project_dir>   - create the Vivado project there
rem   project_mode.cmd synth  <project_dir>   - synthesize the project there
rem
rem Example:
rem   vivado\project_mode.cmd create C:\work\fir_proj
rem   vivado\project_mode.cmd synth  C:\work\fir_proj
rem
rem Set VIVADO_BAT to override the default Vivado install location.
rem ============================================================================
setlocal

set "ACTION=%~1"
set "PROJ_DIR=%~2"

set "VALID="
if /I "%ACTION%"=="create" set "VALID=1"
if /I "%ACTION%"=="synth"  set "VALID=1"

if not defined VALID (
    echo Usage: project_mode.cmd create ^<project_dir^>
    echo        project_mode.cmd synth  ^<project_dir^>
    exit /b 1
)
if "%PROJ_DIR%"=="" (
    echo Usage: project_mode.cmd create ^<project_dir^>
    echo        project_mode.cmd synth  ^<project_dir^>
    exit /b 1
)

if not defined VIVADO_BAT set "VIVADO_BAT=C:\Xilinx\Vivado\2023.2\bin\vivado.bat"
if not exist "%VIVADO_BAT%" (
    echo ERROR: vivado.bat not found at "%VIVADO_BAT%".
    echo        Set the VIVADO_BAT environment variable to your install path.
    exit /b 1
)

rem %~dp0 is the directory of this .cmd file (ends with a backslash).
set "SCRIPT_DIR=%~dp0"

call "%VIVADO_BAT%" -mode batch -nolog -nojournal ^
    -source "%SCRIPT_DIR%project_mode.tcl" ^
    -tclargs %ACTION% "%PROJ_DIR%"

exit /b %ERRORLEVEL%
