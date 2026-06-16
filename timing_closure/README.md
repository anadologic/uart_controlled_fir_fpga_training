# Timing Closure Training Module

A hands-on, FIR-applied walkthrough of timing-closure techniques on the
**Nexys A7-100T (`xc7a100tcsg324-1`)**, built around a deliberately *stressed*
parallel FIR filter.

## Why a new FIR?

The project's main `fir_filter.vhd` is a **sequential** MAC: one tap per clock
cycle, one multiply + one add. At 100 MHz that closes timing with huge slack —
there is nothing to *fix*, so it cannot teach timing closure.

These labs use a **parallel / unrolled FIR**: every tap is computed in the same
cycle as one big combinational `multiply -> add -> add -> ...` cloud, and the
clock is pushed well past what that cloud can sustain. That produces real,
reproducible **negative slack (WNS < 0)** — the precondition for learning how to
recover it.

Each lab keeps the *same function* (an 8-tap, 16-bit FIR with the same
triangular coefficients as the main project) and changes only **one thing**, so
you can attribute every nanosecond of slack improvement to a single technique.

## The closure loop these labs teach

```
   diagnose (read reports)  ->  identify failure type  ->  apply ONE fix  ->  re-run  ->  compare
        ^                                                                                    |
        +------------------------------------------------------------------------------------+
```

The single most important lesson: **diagnose first**. Each technique fixes one
*kind* of failure (logic depth, net delay/fanout, boundary loss, or just-
borderline). Applying the wrong technique to the wrong failure wastes effort.

## Labs

| Lab | Technique | Domain | Fixes |
|-----|-----------|--------|-------|
| [lab0_baseline](lab0_baseline/)   | Diagnosis baseline (chain) | Reports | — (establishes the problem) |
| [lab1_adder_tree](lab1_adder_tree/) | Adder chain -> balanced tree | RTL | logic depth |
| [lab2_pipeline](lab2_pipeline/)   | Pipeline registers | RTL | logic depth (per-stage) |
| [lab3_dsp_mac](lab3_dsp_mac/)     | DSP48 internal pipeline regs | RTL | logic depth + routing |
| [lab4_tool_flow](lab4_tool_flow/) | Retiming, phys_opt, fanout, flatten, seeds | Tool flow | the last picoseconds |
| [lab5_wrapup](lab5_wrapup/)       | Comparison + methodology | Diagnosis | — (synthesizes the lesson) |

## Measured reference results

Validated on **Vivado 2023.2**, part `xc7a100tcsg324-1` (-1 speed grade), shared
target **3.600 ns (≈278 MHz)**. The chain and tree fail; pipelining is the step
that closes timing.

| Lab | Technique | WNS (ns) | Status | Logic levels | DSP | LUT | FF |
|-----|-----------|---------:|:------:|-------------:|----:|----:|----:|
| 0 | parallel, adder chain | **−12.117** | ❌ FAIL | 24 | 2 | 109 | 195 |
| 1 | adder tree | **−4.395** | ❌ FAIL | 10 | 2 | 122 | 195 |
| 2 | pipelined tree | **+0.144** | ✅ PASS | 0 | 7 | 80 | 223 |
| 3 | DSP48 pipelined MAC | **+0.089** | ✅ PASS | 0 | 7 | 1 | 266 |

The 3.600 ns target was chosen empirically: L0/L1 fail while L2/L3 pass, making
"pipelining is what closes timing" the visible lesson. L2 and L3 sit within
~0.14 ns of each other and cross zero together — at 8 taps, **DSP mapping (L3)
buys area (LUT 80→1) and robustness, not raw Fmax**. WNS magnitudes will vary
slightly with Vivado version and placement seed; track the *trend*, not the digit.

## Folder layout (every lab)

```
labN_name/
  README.md            <- the teaching content for this lab
  rtl/                 <- the FIR variant + a thin synthesizable wrapper
  xdc/                 <- clock + I/O timing constraints (the stress lives here)
  vivado/              <- batch Tcl: run synth+impl, write reports
```

## How to run a lab

From the repo root, in a Vivado-enabled shell (adjust the path to your install):

```
C:\Xilinx\Vivado\2023.2\bin\vivado.bat -mode batch -source timing_closure\lab0_baseline\vivado\run_lab.tcl
```

Each `run_lab.tcl` writes its reports into `labN_name/reports/`. The key file is
`timing_summary.rpt` — look at **WNS** (Worst Negative Slack) at the top.

> The exact WNS numbers depend on your Vivado version, so the labs teach you to
> read the *trend* (each technique improves WNS) and the *report*, not to match a
> golden number.

## The wrapper pattern

Every lab wraps the FIR in `fir_top`, which **registers all I/O** (samples in,
result out) into flip-flops. This pushes the I/O paths into IOB registers and
makes the *only* timing-relevant logic the FIR's internal compute path — so the
critical path you analyze is the real lesson, not an I/O artifact.
