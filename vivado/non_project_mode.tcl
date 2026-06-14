################################################################################
## non_project_mode.tcl
## Non-project (in-memory) synthesis flow, driven by a command-line argument.
##
## Everything lives in one Vivado process in memory: no .xpr, no synth_1 run.
## Nothing is written to disk except the reports/checkpoint we explicitly ask
## for, all of which land in <output_dir>.
##
## Arguments (passed by Vivado after -tclargs):
##   <output_dir>  directory for reports and the checkpoint (created if needed)
##
## Run via the wrapper:
##   vivado\non_project_mode.cmd C:\work\fir_nonproj_out
##
## Or call Vivado directly:
##   vivado.bat -mode batch -source vivado\non_project_mode.tcl -tclargs C:\work\out
################################################################################

if {$argc != 1} {
    puts "ERROR: expected 1 argument: <output_dir>"
    exit 1
}

set output_dir [file normalize [lindex $argv 0]]
set part_name  "xc7a100tcsg324-1"  ;# Nexys A7-100T

# Resolve RTL/constraint paths relative to this script so the CWD does not matter.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]

# Non-project mode does not manage state for us: we create the output dir
# ourselves, because nothing is written unless we write it.
file mkdir $output_dir

# Read sources straight into memory (no project, no fileset runs).
read_vhdl [glob $repo_dir/rtl/*.vhd]
read_xdc "$repo_dir/constraints/top_synth_demo.xdc"

# Run synthesis as a single in-memory command (not launch_runs).
synth_design -top top_synth_demo -part $part_name

# We own every output: nothing exists on disk unless we explicitly write it.
report_utilization    -file "$output_dir/utilization_synth_non_project.rpt"
report_timing_summary -file "$output_dir/timing_summary_synth_non_project.rpt"
report_clock_networks -file "$output_dir/clock_networks_synth_non_project.rpt"
report_methodology    -file "$output_dir/methodology_synth_non_project.rpt"
report_drc            -file "$output_dir/drc_synth_non_project.rpt"

write_checkpoint -force "$output_dir/post_synth_non_project.dcp"
write_verilog    -force "$output_dir/post_synth_netlist.v"

puts "INFO: Synthesis stage complete."

################################################################################
## Implementation: each step is an explicit in-memory command (no impl_1 run).
## opt_design -> place_design -> phys_opt_design -> route_design
################################################################################
opt_design
place_design
phys_opt_design
route_design

# Post-route sign-off reports: now timing/utilization are real (placed+routed),
# not the estimates we saw after synthesis.
report_utilization    -file "$output_dir/utilization_impl_non_project.rpt"
report_timing_summary -file "$output_dir/timing_summary_impl_non_project.rpt"
report_drc            -file "$output_dir/drc_impl_non_project.rpt"

write_checkpoint -force "$output_dir/post_route_non_project.dcp"

################################################################################
## Bitstream: the file we actually download to the FPGA.
################################################################################
write_bitstream -force "$output_dir/top_synth_demo.bit"

puts "INFO: Non-project implementation complete. Bitstream: $output_dir/top_synth_demo.bit"
puts "INFO: All outputs written to $output_dir"
