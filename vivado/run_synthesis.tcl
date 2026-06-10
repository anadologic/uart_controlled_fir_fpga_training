################################################################################
## run_synthesis.tcl
## Project-mode batch synthesis: create the project, run synth_1, and
## generate post-synthesis reports.
##
## Run (from any directory):
##   C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source vivado\run_synthesis.tcl
################################################################################

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set report_dir "$repo_dir/reports"

source "$script_dir/create_project.tcl"

file mkdir $report_dir

launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "ERROR: Synthesis run synth_1 failed."
}

open_run synth_1

report_utilization    -file "$report_dir/utilization_synth.rpt"
report_timing_summary -file "$report_dir/timing_summary_synth.rpt"
report_clock_networks -file "$report_dir/clock_networks_synth.rpt"
report_methodology    -file "$report_dir/methodology_synth.rpt"
report_drc            -file "$report_dir/drc_synth.rpt"

write_checkpoint -force "$report_dir/post_synth.dcp"

puts "INFO: Synthesis complete. Reports written to $report_dir"
