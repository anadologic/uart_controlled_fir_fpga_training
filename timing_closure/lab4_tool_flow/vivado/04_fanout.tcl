################################################################################
## 04_fanout.tcl  (LAB 4)
## FANOUT CONTROL / REGISTER DUPLICATION - the manual levers.
##
## A high-fanout driver (one FF feeding many loads) has a long, hard-to-place
## net. Duplicating the driver lets each copy sit near its own cluster of loads.
##
## Two levers shown:
##   (a) global  : synth_design -fanout_limit N
##   (b) targeted: set the MAX_FANOUT property on a chosen net (RTL attribute is
##                 the usual route; here we show the XDC/Tcl equivalent)
##
##   vivado -mode batch -source timing_closure\lab4_tool_flow\vivado\04_fanout.tcl
##
## NOTE: this 8-tap FIR is small, so fanout may not be the limiter. The lesson is
## the MECHANISM and WHEN to reach for it (net-delay-dominated paths), not a big
## number here. Read the worst path's net-vs-logic split first - if logic
## dominates, fanout tricks will NOT help and you should pipeline instead.
################################################################################

set lab_dir    [file dirname [file dirname [file normalize [info script]]]]
set report_dir "$lab_dir/reports"
set part_name  "xc7a100tcsg324-1"
file mkdir $report_dir

read_vhdl [glob $lab_dir/rtl/*.vhd]
read_xdc  [glob $lab_dir/xdc/*.xdc]

## (a) Global fanout limit: replicate any driver exceeding this load count.
synth_design -top fir_top -part $part_name -fanout_limit 50

## (b) Targeted example (commented - enable if a specific high-fanout net shows
##     up in your reports). Forces duplication so no copy drives > 16 loads:
# set_property MAX_FANOUT 16 [get_nets -hier *valid_pipe*]

opt_design
place_design

## phys_opt also does placement-aware replication for fanout:
phys_opt_design -directive AggressiveFanoutOpt

route_design

report_timing_summary -file "$report_dir/04_fanout_timing.rpt"

## Show the highest-fanout nets so students can SEE what would be a candidate.
report_high_fanout_nets -max_nets 20 -file "$report_dir/04_high_fanout_nets.rpt"

set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "LAB4 / 04_fanout             WNS = $wns ns"
puts "See 04_high_fanout_nets.rpt for the duplication candidates."
