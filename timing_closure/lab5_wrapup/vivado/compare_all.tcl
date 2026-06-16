################################################################################
## compare_all.tcl  (LAB 5 - comparison harness)
## Runs the FIR variant from labs 0-3 (each with the shared 4 ns XDC) through the
## SAME default flow, and tabulates WNS / logic-levels / LUT / FF / DSP so the
## whole closure story fits on one screen.
##
## Lab 4 is a tool-flow lab (same RTL as Lab 2), so it is not re-run here - its
## numbers come from its own scripts. This harness is about the RTL progression.
##
##   vivado -mode batch -source timing_closure\lab5_wrapup\vivado\compare_all.tcl
################################################################################

set wrap_dir [file dirname [file dirname [file normalize [info script]]]]
set tc_dir   [file dirname $wrap_dir]              ;# timing_closure/
set part_name "xc7a100tcsg324-1"
set report_dir "$wrap_dir/reports"
file mkdir $report_dir

## lab folder -> friendly label
set labs {
  lab0_baseline   "L0 chain"
  lab1_adder_tree "L1 tree"
  lab2_pipeline   "L2 pipe"
  lab3_dsp_mac    "L3 dsp"
}

set rows {}

foreach {folder label} $labs {
    close_design -quiet
    set lab_path "$tc_dir/$folder"
    read_vhdl [glob $lab_path/rtl/*.vhd]
    read_xdc  [glob $lab_path/xdc/*.xdc]

    synth_design -top fir_top -part $part_name
    opt_design
    place_design
    route_design

    set path [get_timing_paths -delay_type max -max_paths 1]
    set wns  [get_property SLACK       $path]
    set lvl  [get_property LOGIC_LEVELS $path]
    set lut  [llength [get_cells -hier -filter {REF_NAME =~ LUT*}]]
    set ff   [llength [get_cells -hier -filter {REF_NAME =~ FD*}]]
    set dsp  [llength [get_cells -hier -filter {REF_NAME =~ DSP48*}]]

    lappend rows [format "  %-9s  WNS=%7s  levels=%3s  LUT=%5s  FF=%5s  DSP=%3s" \
                         $label $wns $lvl $lut $ff $dsp]
}

set out "$report_dir/comparison.txt"
set fh [open $out w]
set header "============================================================
Timing closure progression (same 4 ns target, same default flow)
============================================================"
puts $header
puts $fh $header
foreach r $rows { puts $r; puts $fh $r }
set footer "------------------------------------------------------------
Trend to expect: WNS rises (less negative -> positive) as logic
levels fall; FF rises with pipelining; DSP appears in L3 while LUT
drops. Each step trades a different resource for speed.
============================================================"
puts $footer
puts $fh $footer
close $fh
puts "Wrote $out"
