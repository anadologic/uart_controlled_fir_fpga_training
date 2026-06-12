@echo off
rem ============================================================================
rem non_project_mode.cmd
rem Non-project (in-memory) synthesis caller for the synthesis training demo.
rem
rem Unlike the project-mode flow, there is no create/synth split: a single
rem invocation reads the sources, synthesizes in memory, and writes the
rem reports/checkpoint into <output_dir>. No .xpr or synth_1 run is created.
rem
rem Usage:
rem   non_project_mode.cmd <output_dir>   - synthesize and write outputs there
rem
rem Example:
rem   vivado\non_project_mode.cmd C:\work\fir_nonproj_out
rem
rem Set VIVADO_BAT to override the default Vivado install location.
rem ============================================================================
setlocal

set "OUTPUT_DIR=%~1"

if "%OUTPUT_DIR%"=="" (
    echo Usage: non_project_mode.cmd ^<output_dir^>
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
    -source "%SCRIPT_DIR%non_project_mode.tcl" ^
    -tclargs "%OUTPUT_DIR%"

exit /b %ERRORLEVEL%
