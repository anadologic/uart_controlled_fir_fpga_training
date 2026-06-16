################################################################################
## 02_retiming.tcl  (LAB 4)
## RETIMING / REGISTER BALANCING - let the tool MOVE the pipeline registers
## across logic to equalize stage delays. Same RTL as 01_baseline.
##
## Two knobs are shown:
##   (a) synth_design -retiming   : retiming during synthesis
##   (b) phys_opt_design -retime  : physically-aware retiming after placement
##
##   vivado -mode batch -source timing_closure\lab4_tool_flow\vivado\02_retiming.tcl
################################################################################

set lab_dir    [file dirname [file dirname [file normalize [info script]]]]
set report_dir "$lab_dir/reports"
set part_name  "xc7a100tcsg324-1"
file mkdir $report_dir

read_vhdl [glob $lab_dir/rtl/*.vhd]
read_xdc  [glob $lab_dir/xdc/*.xdc]

## (a) retiming at synthesis: tool slides the hand-placed pipeline registers to
##     balance the multiply stage against the lighter add stages.
synth_design -top fir_top -part $part_name -retiming

opt_design
place_design

## (b) physically-aware retiming: now that placement is known, rebalance again
##     using REAL routing delays. Often the bigger win of the two.
phys_opt_design -retime

route_design

report_timing_summary -file "$report_dir/02_retiming_timing.rpt"
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "LAB4 / 02_retiming           WNS = $wns ns   (compare vs 01_baseline)"

## NOTE: retiming only MOVES existing registers - it cannot add latency. It pays
## off here because Lab 2's pipeline has spare registers in the light add stages
## that can absorb work from the heavy multiply stage. On an UNpipelined design
## (Lab 0/1) -retiming would do almost nothing - there are no registers to move.
