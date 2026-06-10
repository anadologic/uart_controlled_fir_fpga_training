# Vivado Synthesis Training — UART-Controlled FIR Filter

A moderate-complexity VHDL design for teaching the **Vivado synthesis flow** in both
**GUI mode** and **batch/Tcl mode**, with a clean starting point for the follow-up
**timing analysis** session.

- **Board** : Digilent Nexys A7-100T (`xc7a100tcsg324-1`)
- **Tool**  : Vivado 2023.2
- **Top**   : `top_synth_demo`
- **Clock** : 100 MHz (`create_clock -period 10.000`)
- **UART**  : 115200 baud, 8-N-1, via on-board USB-RS232 bridge

---

## 1. What the design does

The FPGA receives single-byte ASCII commands over UART, runs an internal
signal-processing datapath, stores filtered samples in RAM, and answers over UART.

```text
PC (terminal, 115200 8-N-1)
   |
   v
UART RX ──> Command Parser FSM ──> Register Bank
                                       |  enable / clear / threshold
                                       v
                  Sample Generator (triangle wave)
                                       |
                                       v
                  FIR Filter (8 taps, sequential MAC, 1x DSP)
                                       |
                                       v
                  Sample RAM (1024 x 32, BRAM)
                                       |
                                       v
                  Packet Formatter ──> UART TX ──> PC
```

### Command protocol

| Byte | Command      | Action                                   | Reply                                  |
|------|--------------|------------------------------------------|----------------------------------------|
| `S`  | Start        | Enable sample generation + filtering     | `A`                                    |
| `X`  | Stop         | Disable processing                       | `A`                                    |
| `C`  | Clear        | Reset RAM write pointer / sample counter | `A`                                    |
| `R`  | Read status  | Return status and last filtered sample   | `A` + `[status][sample 4B MSB..LSB][D]` |
| any other | —       | Unknown command                          | `E`                                    |

Status byte: `bit7 = busy`, `bit6 = RAM full (error)`, `bits 5..0 = sample count`.

### LEDs

| LED | Meaning                              |
|-----|--------------------------------------|
| 0   | Processing enabled                   |
| 1   | Sample RAM full                      |
| 2   | Last filtered sample above threshold |
| 3   | Heartbeat blink (~0.7 s)             |

---

## 2. Repository structure

```text
.
├── README.md
├── vivado_synthesis_training_project.md   <- original project specification
├── rtl/                                   <- all VHDL sources
│   ├── synth_demo_pkg.vhd                 <- types, opcodes, clog2()
│   ├── top_synth_demo.vhd                 <- top level
│   ├── reset_sync.vhd
│   ├── uart_rx.vhd
│   ├── uart_tx.vhd
│   ├── command_parser.vhd
│   ├── register_bank.vhd
│   ├── sample_generator.vhd
│   ├── fir_filter.vhd
│   ├── sample_ram.vhd
│   └── packet_formatter.vhd
├── constraints/
│   └── top_synth_demo.xdc                 <- Nexys A7 pins + 100 MHz clock
├── vivado/
│   ├── create_project.tcl                 <- project creation (project mode)
│   ├── run_synthesis.tcl                  <- project-mode batch synthesis
│   ├── non_project_synth.tcl              <- non-project batch synthesis
│   └── report_synthesis.tcl               <- regenerate reports from a checkpoint
└── reports/                               <- generated, not in git
```

---

## 3. Why each block exists (slide: design-to-topic map)

Every module is there to make Vivado demonstrate a specific synthesis feature:

| Block              | Synthesis topic it demonstrates                        |
|--------------------|--------------------------------------------------------|
| `uart_rx` / `uart_tx` | FSM inference, counters, shift registers            |
| `command_parser`   | FSM extraction + encoding choice (`FSM_ENCODING`)      |
| `register_bank`    | Flip-flop inference, reset strategy, `KEEP`            |
| `sample_generator` | Counters, signed arithmetic                            |
| `fir_filter`       | DSP inference (`USE_DSP`), ROM inference (`ROM_STYLE`), SRL inference (`SHREG_EXTRACT`) |
| `sample_ram`       | Block RAM inference (`RAM_STYLE`)                      |
| `reset_sync`       | CDC-safe reset, `ASYNC_REG`                            |
| `top_synth_demo`   | Hierarchy, `KEEP_HIERARCHY`, `MARK_DEBUG`, `IOB`       |

### Synthesis attributes used in the RTL

| Attribute        | File                 | Applied to              | Purpose                                  |
|------------------|----------------------|-------------------------|------------------------------------------|
| `ASYNC_REG`      | `reset_sync.vhd`     | `rst_sync_ff`           | Mark synchronizer chain (also in `uart_rx` on `rx_meta`/`rx_sync`) |
| `FSM_ENCODING`   | `command_parser.vhd` | `parser_state`          | Let Vivado pick/report the state encoding |
| `MARK_DEBUG`     | `command_parser.vhd`, `top_synth_demo.vhd` | `parser_state_dbg` | Preserve net for ILA probing |
| `KEEP`           | `register_bank.vhd`  | `dbg_reg`               | Prevent optimization of a dead-end net    |
| `ROM_STYLE`      | `fir_filter.vhd`     | `coeff_rom`             | Force distributed (LUT) ROM               |
| `SHREG_EXTRACT`  | `fir_filter.vhd`     | `delay_line`            | Allow SRL extraction of the delay line    |
| `USE_DSP`        | `fir_filter.vhd`     | `mac_result`            | Map the MAC to a DSP48 slice              |
| `RAM_STYLE`      | `sample_ram.vhd`     | `sample_mem`            | Force block RAM (try `"distributed"` live!) |
| `KEEP_HIERARCHY` | `top_synth_demo.vhd` | `u_fir_filter` instance | Keep the FIR as its own level in the netlist |
| `IOB`            | `top_synth_demo.vhd` | `led_reg`               | Pack output registers into I/O blocks     |

The XDC also contains **commented** examples of setting `MARK_DEBUG`, `KEEP`,
`DONT_TOUCH`, and `IOB` from constraints instead of RTL.

---

## 4. GUI flow (live demo script)

### Step 1 — Create the project

`File → Project → New`
- RTL Project, do **not** specify sources yet (or add them in the wizard)
- Target language: **VHDL**
- Part: **xc7a100tcsg324-1** (or pick the Nexys A7-100T board)

### Step 2 — Add sources

`Add Sources → Add or Create Design Sources` → add all of `rtl/*.vhd`
- Top entity: `top_synth_demo` (Vivado should detect it automatically)
- Show the **compile order** Vivado derives (package first)

### Step 3 — Add constraints

`Add Sources → Add or Create Constraints` → add `constraints/top_synth_demo.xdc`

Key message: *the single most important constraint is the clock definition* —

```tcl
create_clock -add -name sys_clk -period 10.000 -waveform {0 5} [get_ports { clk }]
```

### Step 4 — RTL elaboration

`Flow Navigator → RTL Analysis → Open Elaborated Design`

Show: RTL hierarchy, schematic, ports, the FSMs as generic blocks.

Key message: *elaboration checks that Vivado understands the RTL structure —
nothing is mapped to FPGA primitives yet.*

### Step 5 — Run synthesis

`Flow Navigator → Synthesis → Run Synthesis` → then **Open Synthesized Design**

Walk through, in this order:
1. **Messages tab** — FSM encoding infos, ROM/RAM/DSP/SRL mapping tables
2. **Schematic** — find the `DSP48E1`, `RAMB36E1`, `SRL16E` primitives
3. **Report Utilization**
4. **Report Timing Summary** (estimated, pre-route)
5. The preserved `u_fir_filter` hierarchy (effect of `KEEP_HIERARCHY`)

---

## 5. Batch flows

Run from the repository root (any directory works — scripts resolve their own paths):

```bat
:: Project mode: creates vivado/vivado_project/, runs synth_1, writes reports/
C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source vivado\run_synthesis.tcl

:: Non-project mode: in-memory, no project on disk, writes reports/
C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source vivado\non_project_synth.tcl

:: Regenerate reports from an existing checkpoint
C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source vivado\report_synthesis.tcl
```

Generated reports (in `reports/`): utilization, timing summary, clock networks,
methodology, DRC, post-synthesis checkpoint (`.dcp`), and (non-project flow only)
a Verilog netlist.

### Slide: the three flows compared

| Flow                 | Best for                      | Training message                              |
|----------------------|-------------------------------|-----------------------------------------------|
| GUI project flow     | Beginners, interactive demos  | Easy to visualize flow and reports            |
| Project Tcl flow     | Reproducible projects         | Same project recreated automatically, GUI-compatible |
| Non-project Tcl flow | CI/CD, automation             | Fast, script-only, nothing persists on disk   |

---

## 6. Expected synthesis results (verified, Vivado 2023.2)

Use these numbers on your slides — they come from an actual run of
`non_project_synth.tcl` on this repository:

**Messages to point at during the demo:**

- 4 FSMs inferred: `uart_rx` (sequential), `uart_tx` (sequential),
  `command_parser` (**one-hot**), `fir_filter` (one-hot)
- ROM mapping: `fir_filter/coeff_rom` → distributed LUT ROM
- Block RAM: `sample_ram/sample_mem` → **1 RAMB36** tile
- SRL: FIR delay line → **16× SRL16E**
- DSP: MAC → **1× DSP48E1**

**Utilization (of xc7a100t):**

| Resource        | Used | Available | %    |
|-----------------|------|-----------|------|
| Slice LUTs      | 280  | 63,400    | 0.44 |
| Slice Registers | 326  | 126,800   | 0.26 |
| Block RAM Tiles | 1    | 135       | 0.74 |
| DSPs            | 1    | 240       | 0.42 |

**Timing (estimated, post-synthesis):** WNS **+1.57 ns** at 100 MHz — design meets
timing comfortably.

---

## 7. Live experiments to run in class

Small RTL/XDC edits with visible synthesis consequences:

1. **`RAM_STYLE` `"block"` → `"distributed"`** (`sample_ram.vhd`):
   BRAM disappears, LUT count jumps → discuss BRAM vs LUTRAM trade-off.
2. **`USE_DSP` `"yes"` → `"no"`** (`fir_filter.vhd`):
   DSP48E1 disappears, fabric multiplier appears → utilization + timing impact.
3. **`SHREG_EXTRACT` `"yes"` → `"no"`** (`fir_filter.vhd`):
   SRL16Es become individual flip-flops.
4. **Delete `create_clock` from the XDC**: timing summary becomes meaningless
   ("no clocks") → motivates the timing-constraints session.
5. **Shrink the clock period** (e.g. `-period 2.0`): create timing pressure and
   show how violations appear in the report — the bridge to the next training.

---

## 8. Talking points per phase

**Before synthesis** — RTL describes behavior and structure; nothing is mapped to
LUTs, FFs, BRAMs, or DSPs yet.

**During synthesis** — Vivado performs: RTL parsing → elaboration → hierarchy
handling → resource inference (FSM/RAM/ROM/DSP/SRL) → logic optimization →
technology mapping → netlist generation.

**After synthesis** — you get: a primitive-level netlist, utilization report,
*estimated* timing report, inference messages, warnings, and a design checkpoint.

**Closing message (transition to timing analysis):**

> Synthesis gives us a mapped netlist and estimated timing.
> Real timing closure starts when constraints are correctly defined and after
> implementation places and routes the design.

Next session covers: clock definitions, input/output delays, generated clocks,
clock groups, false paths, multicycle paths, setup/hold analysis, CDC, and
timing closure methodology. The `set_false_path` exceptions already present in
`top_synth_demo.xdc` (async reset, UART pins) are a ready-made discussion starter.

---

## 9. Trying it on hardware (optional)

1. Run synthesis + implementation + bitstream in the GUI project.
2. Connect the Nexys A7 USB port; it enumerates as a COM port.
3. Open a terminal at **115200 8-N-1** and type `S`, `R`, `X`, `C`.
4. Watch LED0 (enabled), LED1 (RAM full after ~1024 samples), LED3 (heartbeat).
