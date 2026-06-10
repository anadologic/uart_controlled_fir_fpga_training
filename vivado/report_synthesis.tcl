################################################################################
## report_synthesis.tcl
## Re-generate post-synthesis reports from a previously written checkpoint
## without re-running synthesis.
##
## Run (from any directory):
##   C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source vivado\report_synthesis.tcl
################################################################################

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]
set report_dir "$repo_dir/reports"

set dcp_file "$report_dir/post_synth.dcp"
if {![file exists $dcp_file]} {
    set dcp_file "$report_dir/post_synth_non_project.dcp"
}
if {![file exists $dcp_file]} {
    error "ERROR: No post-synthesis checkpoint found in $report_dir. Run run_synthesis.tcl or non_project_synth.tcl first."
}

puts "INFO: Opening checkpoint $dcp_file"
open_checkpoint $dcp_file

report_utilization    -file "$report_dir/utilization_synth.rpt"
report_timing_summary -file "$report_dir/timing_summary_synth.rpt"
report_clock_networks -file "$report_dir/clock_networks_synth.rpt"
report_methodology    -file "$report_dir/methodology_synth.rpt"
report_drc            -file "$report_dir/drc_synth.rpt"

puts "INFO: Reports regenerated in $report_dir"
