@echo off
:: ============================================================================
:: run_sim_xsim.bat
:: Standalone xsim batch simulation (no Vivado project): compile with xvhdl,
:: elaborate with xelab, run with xsim.
::
:: Usage:
::   vivado\run_sim_xsim.bat                    (runs tb_top_synth_demo)
::   vivado\run_sim_xsim.bat tb_fir_filter      (runs the FIR unit testbench)
:: ============================================================================
setlocal

set VIVADO_BIN=C:\Xilinx\Vivado\2023.2\bin

set TB=%1
if "%TB%"=="" set TB=tb_top_synth_demo

set SCRIPT_DIR=%~dp0
set REPO=%SCRIPT_DIR%..
set WORK=%SCRIPT_DIR%xsim_run

if not exist "%WORK%" mkdir "%WORK%"
pushd "%WORK%"

echo === Compiling VHDL sources (xvhdl) ===
call "%VIVADO_BIN%\xvhdl.bat" ^
  "%REPO%\rtl\synth_demo_pkg.vhd" ^
  "%REPO%\rtl\reset_sync.vhd" ^
  "%REPO%\rtl\uart_rx.vhd" ^
  "%REPO%\rtl\uart_tx.vhd" ^
  "%REPO%\rtl\command_parser.vhd" ^
  "%REPO%\rtl\register_bank.vhd" ^
  "%REPO%\rtl\sample_generator.vhd" ^
  "%REPO%\rtl\fir_filter.vhd" ^
  "%REPO%\rtl\sample_ram.vhd" ^
  "%REPO%\rtl\packet_formatter.vhd" ^
  "%REPO%\rtl\top_synth_demo.vhd" ^
  "%REPO%\tb\tb_fir_filter.vhd" ^
  "%REPO%\tb\tb_top_synth_demo.vhd"
if errorlevel 1 goto :fail

echo === Elaborating %TB% (xelab) ===
call "%VIVADO_BIN%\xelab.bat" work.%TB% -s %TB%_sim
if errorlevel 1 goto :fail

echo === Running simulation (xsim) ===
call "%VIVADO_BIN%\xsim.bat" %TB%_sim -R
if errorlevel 1 goto :fail

popd
echo === Simulation of %TB% finished. Check the log above for TEST PASSED. ===
exit /b 0

:fail
popd
echo === Simulation FAILED ===
exit /b 1
