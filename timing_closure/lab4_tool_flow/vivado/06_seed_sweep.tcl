################################################################################
## 06_seed_sweep.tcl  (LAB 4)
## COST TABLES / SEEDS / STRATEGIES - the LAST-PICOSECOND tool.
##
## Place-and-route is a heuristic: a different starting point gives a different
## legal result with different slack. For a design that is ALMOST closing, a
## better seed can push WNS over zero. For a design that is deeply negative, no
## seed will save it - you must fix the RTL.
##
## This script synthesizes ONCE, then places with several placer cost tables
## (different seeds) and reports WNS for each. Pick the best.
##
##   vivado -mode batch -source timing_closure\lab4_tool_flow\vivado\06_seed_sweep.tcl
################################################################################

set lab_dir    [file dirname [file dirname [file normalize [info script]]]]
set report_dir "$lab_dir/reports"
set part_name  "xc7a100tcsg324-1"
file mkdir $report_dir

read_vhdl [glob $lab_dir/rtl/*.vhd]
read_xdc  [glob $lab_dir/xdc/*.xdc]

synth_design -top fir_top -part $part_name
opt_design

## Save the post-opt state so every seed starts from the same netlist.
write_checkpoint -force "$report_dir/_postopt.dcp"

## NOTE on cost tables: older Vivado exposed `place_design -cost_table <1-100>`.
## In 2023.2 that flag is gone; the supported way to get different placement
## "seeds" in the non-project flow is to sweep placer DIRECTIVES (each is a
## different heuristic configuration / starting point). We sweep a set of
## timing-oriented directives and keep the best.
set results {}
foreach dir {Default Explore ExtraTimingOpt ExtraPostPlacementOpt ExtraNetDelay_high} {
    open_checkpoint "$report_dir/_postopt.dcp"
    place_design -directive $dir
    phys_opt_design -directive AggressiveExplore
    route_design
    set wns [get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]
    lappend results [format "  place -directive %-22s  WNS=%6s ns" $dir $wns]
    close_design
}

puts "============================================================"
puts "LAB4 / 06_seed_sweep  (same netlist, different placer directives):"
foreach line $results { puts $line }
puts ""
puts "LESSON: the spread between seeds is the 'luck' in P&R. Seeds buy"
puts "the LAST picoseconds only. A design that closes on just ONE lucky"
puts "seed is FRAGILE - a tiny RTL edit reshuffles placement and it fails"
puts "again. Use seeds last; use RTL (Labs 1-3) for everything above that."
puts "============================================================"

## ---------------------------------------------------------------------------
## PROJECT-FLOW EQUIVALENT (for reference; the project flow runs these in
## parallel as separate implementation runs, each a different strategy/seed):
##
##   create_run impl_perf -flow {Vivado Implementation 2023}
##   set_property strategy Performance_Explore        [get_runs impl_perf]
##   set_property strategy Performance_ExtraTimingOpt  [get_runs impl_perf2]
##   set_property strategy Performance_NetDelay_high   [get_runs impl_perf3]
##   launch_runs impl_perf impl_perf2 impl_perf3 -jobs 3
## ---------------------------------------------------------------------------
