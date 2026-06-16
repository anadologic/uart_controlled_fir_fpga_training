# Lab 0 — Diagnosis Baseline

**Goal:** establish the timing *problem* and learn to read the reports that
diagnose it. You change nothing here — you measure.

## What this design is

A fully parallel 8-tap FIR ([rtl/fir_parallel.vhd](rtl/fir_parallel.vhd))
computing all taps in one cycle as a **linear adder chain**:

```
prod[0] = sample*coeff[0]
prod[1] = tap[0]*coeff[1]
...
acc = prod[0] + prod[1] + prod[2] + ... + prod[7]   <- 7 adders IN SERIES
result_r <= acc                                      <- one register at the end
```

Between the input registers and `result_r` sits: **8 multipliers + a 7-deep
adder chain**, all combinational. The clock ([xdc/timing.xdc](xdc/timing.xdc)) is
set to **3.6 ns (≈278 MHz)** — far faster than that cloud can run — so it fails.

## Run it

```
vivado -mode batch -source timing_closure\lab0_baseline\vivado\run_lab.tcl
```

## Read the reports — in this order

### 1. `reports/timing_summary.rpt` — the headline
Look at the **Design Timing Summary** table:

| Field | Meaning | What "bad" looks like |
|-------|---------|-----------------------|
| **WNS** | Worst Negative Slack (setup) | **Negative** → too slow, setup violation |
| **TNS** | Total Negative Slack | how *many* paths fail and by how much |
| **WHS** | Worst Hold Slack | negative → hold violation (too *fast*) |
| **THS** | Total Hold Slack | sum of hold failures |

> **Setup vs hold — the first fork in diagnosis.**
> - **Setup (WNS<0):** signal arrives *too late*. Caused by long logic/routing.
>   Fixed by RTL (shorten the path) or a slower clock. **This is our failure.**
> - **Hold (WHS<0):** signal arrives *too early*. Almost always a routing/clock-
>   skew issue the tool fixes automatically; you rarely fix it in RTL.

### 2. `reports/timing_worst_paths.rpt` — the *why*
Find the worst path and read its delay breakdown. Two numbers matter most:

- **Logic Levels** — how many LUT/CARRY/DSP stages are chained. A 7-deep adder
  chain shows up as many logic levels. **High logic levels = the problem this
  module's RTL labs attack.**
- **Logic vs Net delay split** — is the path slow because of *cells* (logic
  depth) or *wires* (routing/fanout)? This decides which technique applies:
  - cells dominate → restructure/pipeline (Labs 1–3)
  - nets dominate → fanout/placement (Lab 4)

### 3. `reports/utilization.rpt` — the cost baseline
Note the **DSP**, **LUT**, **FF**, and **CARRY** counts. Every later lab trades
some area for speed; this is the "before" you compare against.

## What you should conclude

- The failure is **setup** (WNS < 0).
- The cause is **logic depth** (a long combinational multiply-add chain), visible
  as high **logic levels** in the worst-path report.
- Therefore the right first fixes are **structural** (Lab 1: adder tree) and
  **pipelining** (Lab 2) — not seeds, not fanout tricks.

This is the whole point of Lab 0: **let the report tell you which technique to
reach for**, instead of guessing.

## Reference numbers (Vivado 2023.2, 3.6 ns target)

| Metric | Measured | Yours |
|--------|----------|-------|
| WNS (ns) | **−12.117** ❌ | ____ |
| Logic levels (worst path) | 24 (CARRY4=19, DSP=2, LUT2=3) | ____ |
| DSP / LUT / FF | 2 / 109 / 195 | ____ |

The worst path is the FIR compute path
(`delay_line_reg → result_r_reg`) — the chain genuinely dominates here. Carry
these into [lab5_wrapup](../lab5_wrapup/) for the final comparison.
