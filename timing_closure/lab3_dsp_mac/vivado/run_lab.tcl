################################################################################
## run_lab.tcl  (LAB 3 - DSP48 pipelined MAC)
##   vivado -mode batch -source timing_closure\lab3_dsp_mac\vivado\run_lab.tcl
################################################################################

set lab_dir    [file dirname [file dirname [file normalize [info script]]]]
set report_dir "$lab_dir/reports"
set part_name  "xc7a100tcsg324-1"

file mkdir $report_dir

read_vhdl [glob $lab_dir/rtl/*.vhd]
read_xdc  [glob $lab_dir/xdc/*.xdc]

synth_design -top fir_top -part $part_name
report_timing_summary -file "$report_dir/timing_summary_postsynth.rpt"

opt_design
place_design
route_design

report_timing_summary -file "$report_dir/timing_summary.rpt"
report_timing -delay_type max -max_paths 10 -nworst 10 -input_pins \
              -file "$report_dir/timing_worst_paths.rpt"
report_utilization -file "$report_dir/utilization.rpt"
report_methodology -file "$report_dir/methodology.rpt"

## DSP-specific: confirm the multipliers actually mapped to DSP48 slices.
report_utilization -cells [get_cells -hier -filter {PRIMITIVE_GROUP == DSP}] \
                   -file "$report_dir/dsp_cells.rpt" -quiet

set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
set dsp [llength [get_cells -hier -filter {REF_NAME =~ DSP48*}]]
puts "============================================================"
puts "LAB 3 DSP MAC  WNS = $wns ns   DSP48 slices used = $dsp"
puts "Check that the critical path no longer runs through a fabric multiplier."
puts "============================================================"

write_checkpoint -force "$report_dir/routed.dcp"
