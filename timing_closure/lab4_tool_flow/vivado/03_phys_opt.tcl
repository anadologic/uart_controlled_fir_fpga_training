################################################################################
## 03_phys_opt.tcl  (LAB 4)
## PHYSICAL OPTIMIZATION - post-placement fixes that use REAL routing delays:
## register replication (for fanout), critical-cell placement, DSP/BRAM register
## optimization, and retiming. Same RTL.
##
##   vivado -mode batch -source timing_closure\lab4_tool_flow\vivado\03_phys_opt.tcl
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

## WNS right after placement, before phys_opt:
set wns_pre [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]

## Aggressive physical optimization. The directive bundles replication, retiming,
## rewiring and critical-path placement tweaks. Try the directive variants:
##   Default | Explore | AggressiveExplore | AggressiveFanoutOpt
phys_opt_design -directive AggressiveExplore

route_design

report_timing_summary -file "$report_dir/03_phys_opt_timing.rpt"
set wns_post [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "LAB4 / 03_phys_opt   WNS before = $wns_pre ns   after = $wns_post ns"

## phys_opt is where high-fanout nets get AUTOMATICALLY replicated based on the
## ACTUAL placement - usually smarter than a hand-written max_fanout guess
## (see 04_fanout.tcl for the manual lever).
