################################################################################
## project_mode.tcl
## Project-mode Tcl example driven by command-line arguments.
##
## Arguments (passed by Vivado after -tclargs):
##   <action>       create | synth | impl
##   <project_dir>  directory where the project lives (created if needed)
##
## Actions:
##   create  create the project in <project_dir>
##   synth   open the project and run synthesis (synth_1)
##   impl    open the project and run implementation + bitstream (impl_1)
##
## Run via the wrapper:
##   vivado\project_mode.cmd create C:\work\fir_proj
##   vivado\project_mode.cmd synth  C:\work\fir_proj
##   vivado\project_mode.cmd impl   C:\work\fir_proj
##
## Or call Vivado directly:
##   vivado.bat -mode batch -source vivado\project_mode.tcl -tclargs create C:\work\fir_proj
################################################################################

if {$argc != 2} {
    puts "ERROR: expected 2 arguments: <action: create|synth|impl> <project_dir>"
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

    impl {
        ########################################################################
        ## Open the existing project and run implementation + bitstream.
        ## launch_runs impl_1 -to_step write_bitstream runs the whole chain
        ## (opt -> place -> route -> bitstream) and, if synth_1 is out of date,
        ## launches it first automatically.
        ########################################################################
        set xpr_file "$proj_dir/$proj_name.xpr"
        if {![file exists $xpr_file]} {
            puts "ERROR: project not found: $xpr_file (run the create step first)"
            exit 1
        }

        open_project $xpr_file

        reset_run impl_1

        launch_runs impl_1 -to_step write_bitstream -jobs 4
        wait_on_run impl_1

        if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
            error "ERROR: Implementation run impl_1 failed."
        }

        open_run impl_1

        set report_dir "$proj_dir/reports"
        file mkdir $report_dir

        report_utilization    -file "$report_dir/utilization_impl.rpt"
        report_timing_summary -file "$report_dir/timing_summary_impl.rpt"
        report_drc            -file "$report_dir/drc_impl.rpt"

        # Bitstream produced by the run; report where it landed.
        set bit_file [glob -nocomplain "$proj_dir/$proj_name.runs/impl_1/*.bit"]
        if {[llength $bit_file] > 0} {
            puts "INFO: Bitstream written to [lindex $bit_file 0]"
        } else {
            puts "WARNING: implementation finished but no .bit file was found."
        }

        puts "INFO: Implementation complete. Reports written to $report_dir"
    }

    default {
        puts "ERROR: unknown action '$action' (expected create, synth, or impl)"
        exit 1
    }
}
