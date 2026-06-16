################################################################################
## run_lab.tcl  (LAB 0 - baseline diagnosis)
## Non-project flow: read RTL + XDC, synth, place, route, and write the reports
## you use to DIAGNOSE a timing failure.
##
## Run from the repo root:
##   vivado -mode batch -source timing_closure\lab0_baseline\vivado\run_lab.tcl
################################################################################

set lab_dir    [file dirname [file dirname [file normalize [info script]]]]
set report_dir "$lab_dir/reports"
set part_name  "xc7a100tcsg324-1"

file mkdir $report_dir

## ---- read sources -----------------------------------------------------------
read_vhdl [glob $lab_dir/rtl/*.vhd]
read_xdc  [glob $lab_dir/xdc/*.xdc]

## ---- synthesis --------------------------------------------------------------
synth_design -top fir_top -part $part_name
report_timing_summary -file "$report_dir/timing_summary_postsynth.rpt"

## ---- implementation ---------------------------------------------------------
opt_design
place_design
route_design

## ---- the diagnosis reports --------------------------------------------------
## 1) The headline: WNS / TNS / WHS / THS. Read this FIRST.
report_timing_summary -file "$report_dir/timing_summary.rpt"

## 2) The worst paths, with full delay/logic-level breakdown. This is where you
##    SEE the multiply->add->add->... chain and count the logic levels.
report_timing -delay_type max -max_paths 10 -nworst 10 -input_pins \
              -file "$report_dir/timing_worst_paths.rpt"

## 3) Utilization (LUT / FF / DSP / CARRY) - the area side of the trade-off.
report_utilization -file "$report_dir/utilization.rpt"

## 4) Methodology / DRC - catches missing constraints and bad practice.
report_methodology -file "$report_dir/methodology.rpt"

## ---- a one-line WNS summary to the console ----------------------------------
set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
puts "============================================================"
puts "LAB 0 baseline  WNS = $wns ns   (negative = FAILS timing)"
puts "Reports in: $report_dir"
puts "============================================================"

write_checkpoint -force "$report_dir/routed.dcp"
