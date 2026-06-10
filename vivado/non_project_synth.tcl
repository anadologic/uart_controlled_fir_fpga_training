################################################################################
## non_project_synth.tcl
## Non-project (in-memory) synthesis flow: read sources, synthesize, and
## generate reports without creating a persistent Vivado project.
##
## Run (from any directory):
##   C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source vivado\non_project_synth.tcl
################################################################################

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set report_dir "$repo_dir/reports"

set part_name "xc7a100tcsg324-1"  ;# Nexys A7-100T

file mkdir $report_dir

read_vhdl [glob $repo_dir/rtl/*.vhd]
read_xdc "$repo_dir/constraints/top_synth_demo.xdc"

synth_design -top top_synth_demo -part $part_name

report_utilization    -file "$report_dir/utilization_synth_non_project.rpt"
report_timing_summary -file "$report_dir/timing_summary_synth_non_project.rpt"
report_clock_networks -file "$report_dir/clock_networks_synth_non_project.rpt"
report_methodology    -file "$report_dir/methodology_synth_non_project.rpt"
report_drc            -file "$report_dir/drc_synth_non_project.rpt"

write_checkpoint -force "$report_dir/post_synth_non_project.dcp"
write_verilog    -force "$report_dir/post_synth_netlist.v"

puts "INFO: Non-project synthesis complete. Reports written to $report_dir"
