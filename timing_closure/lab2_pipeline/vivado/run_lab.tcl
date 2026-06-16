################################################################################
## run_lab.tcl  (LAB 2 - pipelined adder tree)
##   vivado -mode batch -source timing_closure\lab2_pipeline\vivado\run_lab.tcl
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
puts "LAB 2 pipeline  WNS = $wns ns   (expect a big jump vs Lab 1)"
puts "Latency is now 4 cycles - note the FF count rose in utilization.rpt."
puts "============================================================"

write_checkpoint -force "$report_dir/routed.dcp"
