################################################################################
## create_project.tcl
## Create the Vivado project (project mode) for the synthesis training demo.
##
## Run (from any directory):
##   C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source vivado\create_project.tcl
## Or open the GUI afterwards:
##   C:\Xilinx\Vivado\2023.2\bin\vivado.bat vivado\vivado_project\vivado_synth_training.xpr
################################################################################

# Resolve paths relative to this script so the CWD does not matter.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]

set proj_name "vivado_synth_training"
set proj_dir  "$script_dir/vivado_project"
set part_name "xc7a100tcsg324-1"  ;# Nexys A7-100T

create_project $proj_name $proj_dir -part $part_name -force

set_property target_language VHDL [current_project]

add_files [glob $repo_dir/rtl/*.vhd]
add_files -fileset constrs_1 $repo_dir/constraints/top_synth_demo.xdc

set_property top top_synth_demo [current_fileset]

update_compile_order -fileset sources_1

puts "INFO: Project created at $proj_dir/$proj_name.xpr"
