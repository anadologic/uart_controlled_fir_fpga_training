################################################################################
## run_lab.tcl  (LAB 1 - adder tree)
## Identical flow to Lab 0; only the RTL (tree vs chain) differs. Run and compare
## the worst-path LOGIC LEVELS and WNS against Lab 0.
##
##   vivado -mode batch -source timing_closure\lab1_adder_tree\vivado\run_lab.tcl
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

set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "============================================================"
puts "LAB 1 adder tree  WNS = $wns ns"
puts "Compare logic levels in timing_worst_paths.rpt against Lab 0."
puts "============================================================"

write_checkpoint -force "$report_dir/routed.dcp"
