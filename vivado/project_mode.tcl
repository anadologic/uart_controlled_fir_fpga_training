################################################################################
## project_mode.tcl
## Project-mode Tcl example driven by command-line arguments.
##
## Arguments (passed by Vivado after -tclargs):
##   <action>       create | synth
##   <project_dir>  directory where the project lives (created if needed)
##
## Run via the wrapper:
##   vivado\project_mode.cmd create C:\work\fir_proj
##   vivado\project_mode.cmd synth  C:\work\fir_proj
##
## Or call Vivado directly:
##   vivado.bat -mode batch -source vivado\project_mode.tcl -tclargs create C:\work\fir_proj
################################################################################

if {$argc != 2} {
    puts "ERROR: expected 2 arguments: <action: create|synth> <project_dir>"
    exit 1
}

set action    [string tolower [lindex $argv 0]]
set proj_dir  [file normalize [lindex $argv 1]]
set proj_name "vivado_synth_training"
set part_name "xc7a100tcsg324-1"  ;# Nexys A7-100T

# Resolve RTL/constraint paths relative to this script so the CWD does not matter.
set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]

switch -- $action {

    create {
        ########################################################################
        ## Create the project in the requested directory
        ########################################################################
        create_project $proj_name $proj_dir -part $part_name -force

        set_property target_language VHDL [current_project]

        add_files [glob $repo_dir/rtl/*.vhd]
        add_files -fileset constrs_1 $repo_dir/constraints/top_synth_demo.xdc

        set_property top top_synth_demo [current_fileset]

        update_compile_order -fileset sources_1

        puts "INFO: Project created at $proj_dir/$proj_name.xpr"
    }

    synth {
        ########################################################################
        ## Open the existing project and run synthesis (runs infrastructure)
        ########################################################################
        set xpr_file "$proj_dir/$proj_name.xpr"
        if {![file exists $xpr_file]} {
            puts "ERROR: project not found: $xpr_file (run the create step first)"
            exit 1
        }

        open_project $xpr_file

        # Re-run from scratch even if synth_1 already completed once.
        reset_run synth_1

        launch_runs synth_1 -jobs 4
        wait_on_run synth_1

        if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
            error "ERROR: Synthesis run synth_1 failed."
        }

        open_run synth_1

        set report_dir "$proj_dir/reports"
        file mkdir $report_dir

        report_utilization    -file "$report_dir/utilization_synth.rpt"
        report_timing_summary -file "$report_dir/timing_summary_synth.rpt"

        puts "INFO: Synthesis complete. Reports written to $report_dir"
    }

    default {
        puts "ERROR: unknown action '$action' (expected create or synth)"
        exit 1
    }
}
