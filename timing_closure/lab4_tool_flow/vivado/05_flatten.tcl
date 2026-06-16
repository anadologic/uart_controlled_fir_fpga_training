################################################################################
## 05_flatten.tcl  (LAB 4)
## FLATTEN vs PRESERVE HIERARCHY - cross-boundary optimization.
##
## The FIR is instantiated inside fir_top. By default synthesis flattens during
## optimization and rebuilds the hierarchy for reports ("rebuilt"). This script
## synthesizes the SAME RTL three ways and reports WNS + LUT for each, so you can
## see what boundaries cost.
##
##   none    : preserve every boundary (most readable, least optimization)
##   rebuilt : flatten to optimize, then restore names (the default)
##   full    : flatten everything, no rebuild (max optimization, flat reports)
##
##   vivado -mode batch -source timing_closure\lab4_tool_flow\vivado\05_flatten.tcl
################################################################################

set lab_dir    [file dirname [file dirname [file normalize [info script]]]]
set report_dir "$lab_dir/reports"
set part_name  "xc7a100tcsg324-1"
file mkdir $report_dir

set summary {}

foreach mode {none rebuilt full} {
    ## fresh in-memory design each time
    close_design -quiet
    read_vhdl [glob $lab_dir/rtl/*.vhd]
    read_xdc  [glob $lab_dir/xdc/*.xdc]

    synth_design -top fir_top -part $part_name -flatten_hierarchy $mode
    opt_design
    place_design
    route_design

    set wns  [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
    set luts [llength [get_cells -hier -filter {REF_NAME =~ LUT*}]]
    lappend summary [format "  flatten=%-8s  WNS=%6s ns   LUTs=%s" $mode $wns $luts]

    report_timing_summary -file "$report_dir/05_flatten_${mode}_timing.rpt"
}

puts "============================================================"
puts "LAB4 / 05_flatten  (same RTL, three hierarchy modes):"
foreach line $summary { puts $line }
puts "More flattening -> more cross-boundary optimization, but flatter"
puts "(harder to debug) reports. 'rebuilt' is the usual sweet spot."
puts "============================================================"
