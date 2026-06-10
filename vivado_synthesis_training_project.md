# Vivado Synthesis Training Demo Project

## Purpose

Create a moderate-complexity VHDL project that can be used in an FPGA training session to demonstrate the Vivado synthesis flow in both:

1. Vivado GUI mode
2. Vivado batch / Tcl mode

The next training topic after this project will be timing analysis, so the project must also include a clean starting point for timing constraints and post-synthesis timing reports.

---

## Project Goal

Build a small but realistic FPGA design that is simple enough to explain in class, but complex enough to show meaningful Vivado synthesis behavior.

The project should demonstrate:

- RTL elaboration
- Synthesis flow
- Hierarchical RTL structure
- FSM inference
- RAM inference
- ROM inference
- DSP inference
- Shift-register / SRL inference
- CDC/reset synchronizer attributes
- Debug signal preservation
- Post-synthesis utilization reports
- Post-synthesis timing summary
- Vivado GUI project flow
- Vivado batch/Tcl project flow
- Preparation for timing analysis

---

## Recommended Demo Design

## UART-Controlled FIR Processing Demo

The FPGA receives UART commands from a PC, controls a small signal-processing datapath, stores filtered samples in RAM, and sends status or sample data back through UART.

### High-Level Architecture

```text
PC UART
   |
   v
UART RX
   |
   v
Command Parser FSM
   |
   +--------------------+
   |                    |
   v                    v
Register Bank       Sample Generator
                         |
                         v
                    FIR Filter
                         |
                         v
                    Sample RAM / FIFO
                         |
                         v
                    UART TX Formatter
   |
   v
PC UART
```

---

## Why This Design Is Suitable for Synthesis Training

This design naturally exercises multiple FPGA resource types and synthesis features.

| Design Block | Synthesis Topic Demonstrated |
|---|---|
| UART RX/TX | FSMs, counters, shift registers |
| Command parser | FSM encoding, state-machine extraction |
| Register bank | Flip-flops, reset strategy, control registers |
| Sample generator | Counters, adders, arithmetic logic |
| FIR filter | DSP inference, pipelining, arithmetic mapping |
| Coefficient ROM | ROM inference |
| Sample RAM/FIFO | BRAM or distributed RAM inference |
| Reset synchronizer | `ASYNC_REG` attribute |
| Debug signals | `MARK_DEBUG`, `KEEP` attributes |
| Hierarchical modules | `KEEP_HIERARCHY` attribute |
| Delay line | `SHREG_EXTRACT`, SRL inference |
| Output registers | `IOB` attribute |

---

## Repository Structure

Codex should create the following structure:

```text
vivado_synth_training/
|
├── README.md
├── workflow.md
|
├── rtl/
|   ├── synth_demo_pkg.vhd
|   ├── top_synth_demo.vhd
|   ├── reset_sync.vhd
|   ├── uart_rx.vhd
|   ├── uart_tx.vhd
|   ├── command_parser.vhd
|   ├── register_bank.vhd
|   ├── sample_generator.vhd
|   ├── fir_filter.vhd
|   ├── sample_ram.vhd
|   └── packet_formatter.vhd
|
├── constraints/
|   └── top_synth_demo.xdc
|
├── scripts/
|   ├── create_project.tcl
|   ├── run_synthesis.tcl
|   ├── non_project_synth.tcl
|   └── report_synthesis.tcl
|
└── reports/
    └── .gitkeep
```

---

## RTL Coding Requirements

Use VHDL for all RTL files.

Recommended VHDL style:

- Use `ieee.std_logic_1164.all`
- Use `ieee.numeric_std.all`
- Avoid non-standard arithmetic packages
- Use synchronous processes for registers
- Use clear reset handling
- Use generics for clock frequency and UART baud rate
- Keep module interfaces simple and training-friendly
- Make the design synthesizable in Vivado without vendor primitive instantiation where possible
- Prefer inference for RAM, ROM, DSP, and SRL examples

---

## Top-Level Entity

Create a top-level VHDL entity named:

```vhdl
top_synth_demo
```

Recommended ports:

```vhdl
entity top_synth_demo is
  generic (
    G_CLK_FREQ_HZ : positive := 100_000_000;
    G_UART_BAUD   : positive := 115_200;
    G_SAMPLE_W    : positive := 16;
    G_COEFF_W     : positive := 16;
    G_NUM_TAPS    : positive := 8;
    G_RAM_DEPTH   : positive := 1024
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    uart_rx_i : in  std_logic;
    uart_tx_o : out std_logic;

    led_o     : out std_logic_vector(3 downto 0)
  );
end entity;
```

---

## Package File

Create `rtl/synth_demo_pkg.vhd`.

It should include:

- Common constants
- Common types
- Command opcodes
- FIR coefficient type
- Sample type
- UART byte subtype

Example content:

```vhdl
package synth_demo_pkg is

  subtype byte_t is std_logic_vector(7 downto 0);

  constant C_CMD_START      : byte_t := x"53"; -- ASCII 'S'
  constant C_CMD_STOP       : byte_t := x"58"; -- ASCII 'X'
  constant C_CMD_READ_STAT  : byte_t := x"52"; -- ASCII 'R'
  constant C_CMD_CLEAR      : byte_t := x"43"; -- ASCII 'C'

  type parser_state_t is (
    ST_IDLE,
    ST_DECODE,
    ST_EXECUTE,
    ST_REPLY
  );

end package;
```

---

## Required Modules

## 1. `reset_sync.vhd`

Purpose:

- Synchronize external active-low reset into the system clock domain
- Demonstrate `ASYNC_REG`

Requirements:

- Input: `clk`, `rst_n`
- Output: synchronized active-high reset `rst`
- Use a 2- or 3-stage synchronizer
- Apply `ASYNC_REG` attribute to synchronizer flip-flops

Example attribute style:

```vhdl
attribute ASYNC_REG : string;
attribute ASYNC_REG of rst_sync_ff : signal is "TRUE";
```

---

## 2. `uart_rx.vhd`

Purpose:

- Receive UART bytes from PC
- Demonstrate counters, FSM, and shift registers

Requirements:

- Generic clock frequency and baud rate
- Standard 8-N-1 UART format
- Output one-cycle `rx_valid_o` when a byte is received
- Output received byte as `rx_data_o`
- Implement internal state machine

Recommended states:

```text
IDLE
START
DATA
STOP
VALID
```

---

## 3. `uart_tx.vhd`

Purpose:

- Transmit UART bytes to PC
- Demonstrate FSM, counters, and shift registers

Requirements:

- Generic clock frequency and baud rate
- Standard 8-N-1 UART format
- Input ready/valid style interface
- Output `tx_busy_o`

Recommended interface:

```vhdl
tx_valid_i : in  std_logic;
tx_data_i  : in  std_logic_vector(7 downto 0);
tx_ready_o : out std_logic;
tx_o       : out std_logic;
```

---

## 4. `command_parser.vhd`

Purpose:

- Decode UART command bytes
- Demonstrate FSM inference and optional FSM attributes

Requirements:

- Consume bytes from `uart_rx`
- Generate control strobes:
  - `start_o`
  - `stop_o`
  - `clear_o`
  - `read_status_o`
- Produce simple response byte for `uart_tx`
- Expose parser state for debug

Recommended attribute demonstration:

```vhdl
attribute FSM_ENCODING : string;
attribute FSM_ENCODING of parser_state : signal is "auto";
```

Optional debug attribute:

```vhdl
attribute MARK_DEBUG : string;
attribute MARK_DEBUG of parser_state_dbg : signal is "TRUE";
```

---

## 5. `register_bank.vhd`

Purpose:

- Store control and status registers
- Demonstrate flip-flop inference and simple control logic

Requirements:

Registers:

| Register | Description |
|---|---|
| Control register | Enable processing, clear counters |
| Status register | Busy, sample count, error flags |
| Threshold register | Optional comparison threshold |
| Debug register | Optional internal debug value |

---

## 6. `sample_generator.vhd`

Purpose:

- Generate input samples for FIR filter
- Avoid needing external ADC input
- Demonstrate counters and arithmetic

Requirements:

- Generate a simple ramp, triangle, or pseudo-random sequence
- Produce ready/valid sample interface
- Width controlled by generic `G_SAMPLE_W`

Recommended output:

```vhdl
sample_valid_o : out std_logic;
sample_data_o  : out signed(G_SAMPLE_W-1 downto 0);
```

---

## 7. `fir_filter.vhd`

Purpose:

- Implement a small FIR filter
- Demonstrate DSP inference, coefficient ROM, pipelining, and shift registers

Requirements:

- Generic sample width, coefficient width, and number of taps
- Default number of taps: 8
- Use signed arithmetic
- Include a coefficient ROM
- Include a sample delay line
- Use multiply-accumulate logic
- Register the output

Attributes to demonstrate:

### `USE_DSP`

Apply to multiplication or MAC-related signals where appropriate:

```vhdl
attribute USE_DSP : string;
attribute USE_DSP of mac_result : signal is "yes";
```

### `ROM_STYLE`

Apply to coefficient ROM:

```vhdl
attribute ROM_STYLE : string;
attribute ROM_STYLE of coeff_rom : signal is "distributed";
```

### `SHREG_EXTRACT`

Apply to delay line if coded as a shift register:

```vhdl
attribute SHREG_EXTRACT : string;
attribute SHREG_EXTRACT of delay_line : signal is "yes";
```

---

## 8. `sample_ram.vhd`

Purpose:

- Store filtered samples
- Demonstrate RAM inference

Requirements:

- Single-clock RAM
- Write filtered samples into memory
- Read back for packet formatter or status response
- RAM depth controlled by generic

Attribute to demonstrate:

```vhdl
attribute RAM_STYLE : string;
attribute RAM_STYLE of sample_mem : signal is "block";
```

Expected Vivado result:

- For sufficiently large depth, Vivado should infer block RAM
- For smaller depth or different attribute values, Vivado may infer LUTRAM

---

## 9. `packet_formatter.vhd`

Purpose:

- Format status/sample data for UART transmission
- Demonstrate FSM and multiplexing logic

Requirements:

- Accept status or sample values
- Produce bytes for `uart_tx`
- Use ready/valid interface
- Send simple ASCII response bytes

Example responses:

```text
A = acknowledge
B = busy
D = done
E = error
```

---

## Synthesis Attributes to Demonstrate

The project should include examples of the following attributes.

| Attribute | Recommended Location | Purpose |
|---|---|---|
| `ASYNC_REG` | `reset_sync.vhd` | Mark reset/CDC synchronizer registers |
| `MARK_DEBUG` | `command_parser.vhd`, top-level signals | Preserve and expose debug signals |
| `KEEP` | Internal debug/status nets | Prevent optimization of selected nets |
| `DONT_TOUCH` | Optional instance-level demo | Strongly prevent optimization of a selected block |
| `RAM_STYLE` | `sample_ram.vhd` | Guide RAM inference |
| `ROM_STYLE` | `fir_filter.vhd` | Guide coefficient ROM inference |
| `USE_DSP` | `fir_filter.vhd` | Guide DSP inference for arithmetic |
| `SHREG_EXTRACT` | `fir_filter.vhd` | Guide SRL inference for delay line |
| `KEEP_HIERARCHY` | selected entity or instance | Preserve hierarchy for teaching/demo |
| `IOB` | top-level output register | Pack output register into I/O block |

---

## XDC Constraint File

Create `constraints/top_synth_demo.xdc`.

The XDC should contain generic placeholder pin constraints that the trainer can later modify for the target board.

Minimum required timing constraint:

```tcl
create_clock -period 10.000 -name sys_clk [get_ports clk]
```

This defines a 100 MHz clock.

Add placeholder I/O constraints:

```tcl
# TODO: Replace PACKAGE_PIN values according to the selected board.

set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_i]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_o]
set_property IOSTANDARD LVCMOS33 [get_ports {led_o[*]}]

# Example placeholders only:
# set_property PACKAGE_PIN W5 [get_ports clk]
# set_property PACKAGE_PIN U18 [get_ports rst_n]
# set_property PACKAGE_PIN A9 [get_ports uart_rx_i]
# set_property PACKAGE_PIN D10 [get_ports uart_tx_o]
```

Optional XDC attributes/properties to demonstrate:

```tcl
# Mark a debug net from XDC instead of RTL.
# set_property MARK_DEBUG true [get_nets -hier *parser_state_dbg*]

# Preserve a selected net.
# set_property KEEP true [get_nets -hier *debug*]

# Do not optimize a selected cell.
# set_property DONT_TOUCH true [get_cells -hier *u_fir_filter*]

# Example IOB packing on output registers, if register names are stable.
# set_property IOB TRUE [get_cells -hier *uart_tx_o_reg*]
```

---

## Vivado GUI Training Procedure

Document the following steps in `README.md` or `workflow.md`.

### Step 1: Create Project

In Vivado:

```text
File → Project → New
```

Select:

```text
RTL Project
Target language: VHDL
Simulator language: Mixed or VHDL
```

Choose the target FPGA part or board.

Example part for Nexys A7-100T:

```text
xc7a100tcsg324-1
```

---

### Step 2: Add RTL Sources

```text
Add Sources → Add or Create Design Sources
```

Add all files from:

```text
rtl/
```

Set the top module/entity:

```text
top_synth_demo
```

---

### Step 3: Add Constraints

```text
Add Sources → Add or Create Constraints
```

Add:

```text
constraints/top_synth_demo.xdc
```

Explain that the most important first timing constraint is:

```tcl
create_clock -period 10.000 -name sys_clk [get_ports clk]
```

---

### Step 4: Run RTL Elaboration

In Vivado GUI:

```text
Flow Navigator → RTL Analysis → Open Elaborated Design
```

Show the audience:

- RTL hierarchy
- Schematic view
- Ports
- Signals
- FSM structure
- Inferred high-level structure before synthesis

Explain:

```text
Elaboration checks whether Vivado understands the RTL structure.
It does not yet map the design to FPGA primitives.
```

---

### Step 5: Run Synthesis

In Vivado GUI:

```text
Flow Navigator → Synthesis → Run Synthesis
```

After synthesis completes:

```text
Open Synthesized Design
```

Show the audience:

- Synthesized hierarchy
- Schematic
- Device utilization
- Inferred RAMs
- Inferred DSPs
- FSM extraction
- Clock report
- Timing summary
- Synthesis warnings and critical warnings

---

## Reports to Generate After Synthesis

Generate these reports after synthesis:

```text
Report Utilization
Report Timing Summary
Report Clock Networks
Report Methodology
Report DRC
```

Expected output files:

```text
reports/utilization_synth.rpt
reports/timing_summary_synth.rpt
reports/clock_networks_synth.rpt
reports/methodology_synth.rpt
reports/drc_synth.rpt
reports/post_synth.dcp
```

---

## Batch Mode: Project Flow Tcl

Create `scripts/create_project.tcl`.

```tcl
set proj_name "vivado_synth_training"
set proj_dir "./vivado_project"
set part_name "xc7a100tcsg324-1"

create_project $proj_name $proj_dir -part $part_name -force

set_property target_language VHDL [current_project]

add_files [glob ./rtl/*.vhd]
add_files -fileset constrs_1 ./constraints/top_synth_demo.xdc

set_property top top_synth_demo [current_fileset]

update_compile_order -fileset sources_1
```

Create `scripts/run_synthesis.tcl`.

```tcl
source ./scripts/create_project.tcl

file mkdir ./reports

launch_runs synth_1 -jobs 4
wait_on_run synth_1

open_run synth_1

report_utilization      -file ./reports/utilization_synth.rpt
report_timing_summary   -file ./reports/timing_summary_synth.rpt
report_clock_networks   -file ./reports/clock_networks_synth.rpt
report_methodology      -file ./reports/methodology_synth.rpt
report_drc              -file ./reports/drc_synth.rpt

write_checkpoint -force ./reports/post_synth.dcp
```

Run from terminal:

```bash
vivado -mode batch -source ./scripts/run_synthesis.tcl
```

---

## Batch Mode: Non-Project Tcl Flow

Create `scripts/non_project_synth.tcl`.

```tcl
set part_name "xc7a100tcsg324-1"

file mkdir ./reports

read_vhdl [glob ./rtl/*.vhd]
read_xdc ./constraints/top_synth_demo.xdc

synth_design -top top_synth_demo -part $part_name

report_utilization      -file ./reports/utilization_synth_non_project.rpt
report_timing_summary   -file ./reports/timing_summary_synth_non_project.rpt
report_clock_networks   -file ./reports/clock_networks_synth_non_project.rpt
report_methodology      -file ./reports/methodology_synth_non_project.rpt
report_drc              -file ./reports/drc_synth_non_project.rpt

write_checkpoint -force ./reports/post_synth_non_project.dcp
write_verilog    -force ./reports/post_synth_netlist.v
```

Run from terminal:

```bash
vivado -mode batch -source ./scripts/non_project_synth.tcl
```

---

## Training Explanation: Project Flow vs Non-Project Flow

| Flow | Best For | Training Message |
|---|---|---|
| GUI project flow | Beginners and interactive demos | Easy to visualize the flow and reports |
| Project Tcl flow | Reproducible GUI-compatible projects | Same project can be recreated automatically |
| Non-project Tcl flow | CI/CD and automation | Fast, script-only, no persistent Vivado project required |

---

## What to Explain During the Training

### Before Synthesis

Explain:

```text
RTL describes hardware behavior and structure.
Vivado has not yet mapped the design to LUTs, flip-flops, BRAMs, DSPs, or device primitives.
```

### During Synthesis

Vivado performs:

- RTL parsing
- Elaboration
- Hierarchy handling
- Resource inference
- FSM extraction
- RAM/ROM inference
- DSP inference
- Shift-register/SRL inference
- Logic optimization
- Technology mapping
- Synthesized netlist generation

### After Synthesis

Vivado produces:

- FPGA primitive-level synthesized netlist
- Resource utilization report
- Estimated timing report
- Inferred resource information
- Warnings and critical warnings
- Post-synthesis design checkpoint

---

## Suggested Training Sequence

Use this order during the lesson:

1. Introduce the demo project architecture
2. Explain why the project has UART, FSM, RAM, ROM, DSP, and SRL examples
3. Show the RTL file structure
4. Show the top-level entity
5. Show important VHDL attributes
6. Show the XDC constraint file
7. Open Vivado GUI
8. Create project
9. Add RTL and XDC files
10. Run RTL elaboration
11. Explain the elaborated design
12. Run synthesis
13. Open synthesized design
14. Review utilization report
15. Review synthesis messages
16. Review inferred RAM/DSP/FSM information
17. Review timing summary briefly
18. Repeat the same synthesis flow using Tcl batch mode
19. Compare GUI mode, project Tcl mode, and non-project Tcl mode
20. Transition to timing analysis

---

## Transition to Timing Analysis

End the synthesis session with this message:

```text
Synthesis gives us a mapped netlist and estimated timing.
However, real timing closure starts when constraints are correctly defined
and after implementation places and routes the design.
```

The next topic should cover:

- Timing constraints
- Clock definition
- Input delays
- Output delays
- Generated clocks
- Clock groups
- False paths
- Multicycle paths
- Setup analysis
- Hold analysis
- Clock-domain crossings
- Post-synthesis timing
- Post-implementation timing
- Timing closure methodology

---

## Acceptance Criteria for Codex

The generated repository should satisfy these conditions:

1. All VHDL files compile in Vivado.
2. `top_synth_demo` is the top-level entity.
3. The design uses only synthesizable VHDL.
4. The project contains meaningful hierarchy.
5. The design includes at least one FSM.
6. The design includes inferred RAM.
7. The design includes inferred ROM.
8. The design includes arithmetic suitable for DSP inference.
9. The design includes a shift-register/delay-line example.
10. The design includes at least five synthesis attributes from this list:
    - `ASYNC_REG`
    - `MARK_DEBUG`
    - `KEEP`
    - `RAM_STYLE`
    - `ROM_STYLE`
    - `USE_DSP`
    - `SHREG_EXTRACT`
    - `KEEP_HIERARCHY`
    - `IOB`
11. The project includes a valid XDC file with a 100 MHz clock constraint.
12. The project includes Tcl scripts for project-mode synthesis.
13. The project includes Tcl scripts for non-project-mode synthesis.
14. The scripts generate utilization and timing reports.
15. The README explains both GUI and batch synthesis procedures.
16. The design is suitable for follow-up timing analysis training.

---

## Suggested Codex Prompt

Use the following prompt with Codex in VS Code:

```text
Create the VHDL Vivado synthesis training project described in this markdown file.

Implement the full repository structure, all RTL modules, the XDC file, Tcl scripts, and README/workflow documentation.

The project must compile in Vivado with top entity top_synth_demo.
Use synthesizable VHDL with ieee.std_logic_1164 and ieee.numeric_std.
Avoid vendor primitive instantiation unless absolutely necessary.
Use inference-based examples for RAM, ROM, DSP arithmetic, and shift registers.
Include Vivado synthesis attributes in the RTL as described.

After creating the files, check for VHDL syntax consistency, compile-order issues, missing packages, inconsistent generics, and invalid port connections.
```

---

## Notes for Trainer

The exact FPGA board does not matter for synthesis training as long as the target part is selected and the clock constraint is valid.

For a physical board demo, update the XDC pin assignments according to the selected board.

For timing analysis training, keep the design clock at 100 MHz first. After the initial timing discussion, increase the clock frequency to create timing pressure and show how timing violations appear in Vivado reports.
