# Lab 2 — Pipelining the Tree

**Technique:** RTL pipelining. **Fixes:** logic depth (per stage).
**Change vs Lab 1:** insert a register between every tree level.

## The idea

Lab 1 cut the *tree* to 3 logic levels, but all 3 levels (plus the multiply)
still sat between two registers — one long combinational cloud. Lab 2 slices
that cloud with registers so each stage holds only **one operation**:

```
stage 1   stage 2     stage 3     stage 4
[mult] FF [add lvl0] FF [add lvl1] FF [add lvl2] FF -> result
```

Now the worst register-to-register path is a **single multiply** or a **single
add** — tiny. Fmax rises sharply; WNS should finally go positive (or close).

## The trade-off (the core lesson)

Pipelining buys Fmax with two currencies:

- **Latency** — the result now appears **4 cycles** after the sample, not 1.
  We track this with a `valid_pipe` shift register so `result_valid_o` lines up
  with the correct `result_data_o`. *Throughput is unchanged* — still one result
  per cycle — only latency grew.
- **Area** — every pipeline register is flip-flops. Check `utilization.rpt`:
  **FF count rises** vs Lab 1.

> Pipelining does **not** change *what* is computed, only *when*. For streaming
> DSP (like an FIR) latency is usually cheap and Fmax is precious, so this is
> almost always the right trade.

## Why this sets up Lab 4

The stages here are **hand-placed** at tidy RTL boundaries — but they are not
necessarily *delay-balanced*. The multiply stage is heavier than an add stage,
so stage 1 may still be the critical path while stages 2–4 have slack to spare.

That imbalance is exactly what **retiming / register balancing** (Lab 4) fixes:
the tool slides these registers to equalize the stages — *without you editing
RTL*. Lab 2 provides the registers; Lab 4 lets the tool optimize their position.

## Run

```
vivado -mode batch -source timing_closure\lab2_pipeline\vivado\run_lab.tcl
```

## Compare

| Metric | Lab 1 (tree) | Lab 2 (pipelined) | Measured |
|--------|--------------|-------------------|----------|
| WNS | −4.395 ns | **+0.144 ns** ✅ | crosses zero |
| Logic levels (worst path) | 10 | **0** | one register hop |
| DSP | 2 | 7 | products → DSP |
| LUT / FF | 122 / 195 | 80 / 223 | FF up (pipeline regs) |
| Latency | 1 cycle | 4 cycles | the cost |

> **Observed surprise:** FF rose only 195 → 223, less than a naive count of the
> pipeline registers would suggest, and LUT actually *dropped* (122 → 80). The
> tool absorbed the products into DSP output registers (DSP 2 → 7) instead of
> fabric flip-flops — so part of the "pipelining cost" landed as DSP registers,
> not slice FFs. A good reminder that the tool maps your RTL to whatever resource
> fits best.

## Reference numbers (Vivado 2023.2, 3.6 ns target)

| Metric | Measured | Yours |
|--------|----------|-------|
| WNS (ns) | **+0.144** ✅ | ____ |
| Logic levels | 0 | ____ |
| DSP / LUT / FF | 7 / 80 / 223 | ____ |
| Latency (cycles) | 4 | 4 |
