################################################################################
## run_simulation.tcl
## Project-mode batch simulation: create the project, add the testbenches,
## and run the behavioral simulation with xsim.
##
## Run (from any directory):
##   C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source vivado\run_simulation.tcl
##
## To simulate the unit-level FIR testbench instead, change the sim top below
## to tb_fir_filter, or use vivado\run_sim_xsim.bat for the standalone flow.
################################################################################

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]

source "$script_dir/create_project.tcl"

add_files -fileset sim_1 [glob $repo_dir/tb/*.vhd]

set_property top tb_top_synth_demo [get_filesets sim_1]
update_compile_order -fileset sim_1

## Run until the testbench stops itself (gated clock + watchdog)
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]

launch_simulation

puts "INFO: Behavioral simulation finished. Check the log above for TEST PASSED."
