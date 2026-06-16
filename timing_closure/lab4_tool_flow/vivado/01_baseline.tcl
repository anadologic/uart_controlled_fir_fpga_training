################################################################################
## 01_baseline.tcl  (LAB 4)
## Default tool settings, no extra optimization. This is the reference the other
## scripts in this lab improve on - WITHOUT touching the RTL.
##
##   vivado -mode batch -source timing_closure\lab4_tool_flow\vivado\01_baseline.tcl
################################################################################

set lab_dir    [file dirname [file dirname [file normalize [info script]]]]
set report_dir "$lab_dir/reports"
set part_name  "xc7a100tcsg324-1"
file mkdir $report_dir

read_vhdl [glob $lab_dir/rtl/*.vhd]
read_xdc  [glob $lab_dir/xdc/*.xdc]

synth_design -top fir_top -part $part_name
opt_design
place_design
route_design

report_timing_summary -file "$report_dir/01_baseline_timing.rpt"
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "LAB4 / 01_baseline           WNS = $wns ns"
