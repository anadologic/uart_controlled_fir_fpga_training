# Lab 5 — Wrap-up: The Closure Methodology

**Goal:** see the whole progression in one table, and internalize the *loop* that
produced it.

## Run the comparison harness

```
vivado -mode batch -source timing_closure\lab5_wrapup\vivado\compare_all.tcl
```

It runs the Lab 0–3 FIR variants through the same default flow at the same
3.6 ns target and writes `reports/comparison.txt`. Reference run on Vivado
2023.2 (`xc7a100tcsg324-1`):

```
  L0 chain   WNS= -12.117  levels= 24  LUT= 109  FF= 195  DSP= 2
  L1 tree    WNS=  -4.395  levels= 10  LUT= 122  FF= 195  DSP= 2
  L2 pipe    WNS=  +0.144  levels=  0  LUT=  80  FF= 223  DSP= 7
  L3 dsp     WNS=  +0.089  levels=  0  LUT=   1  FF= 266  DSP= 7
```

## The trend to read

| Step | What changed | WNS | Logic levels | What it cost |
|------|--------------|-----|--------------|--------------|
| L0 → L1 | chain → tree | −12.1 → −4.4 | 24 → 10 | ~nothing (same area) |
| L1 → L2 | + pipeline | −4.4 → **+0.14** ✅ | 10 → 0 | latency (1→4), FF + DSP |
| L2 → L3 | + DSP regs | +0.14 → +0.09 (flat) | 0 → 0 | latency (4→5); **LUT 80→1** |
| (L4) | tool flow | last ps | — | none (settings only) |

> **The measured surprise — keep it in the lesson:** pipelining (L1→L2) is the
> step that crosses zero. DSP mapping (L2→L3) did **not** speed things up here
> (WNS flat within noise) because the multiply was no longer critical after
> pipelining — instead it emptied the fabric (LUT 80→1). DSP mapping is an
> *area/robustness* win at this size, a *speed* win only when the multiply is the
> critical path. The honest table beats a tidy "everything improves WNS" story.

Every step trades a *different* resource for speed: structure (free), latency,
flip-flops, DSP slices, or just compute effort. **There is no single "make it
faster" button — closure is a sequence of targeted trades.**

## The methodology loop (the real deliverable)

```
   1. DIAGNOSE   read report_timing_summary -> setup or hold? WNS how bad?
        |        read worst path -> logic levels? net vs logic delay?
        v
   2. CLASSIFY   logic depth?  -> restructure / pipeline / DSP   (Labs 1-3)
        |        net / fanout? -> duplication / phys_opt          (Lab 4)
        |        boundary?     -> flatten                          (Lab 4)
        |        just borderline? -> seeds / strategies            (Lab 4)
        v
   3. APPLY ONE  change a single thing so you can attribute the result
        |
        v
   4. RE-RUN     measure WNS again
        |
        v
   5. COMPARE -> improved? keep it. not? revert, re-diagnose.  (loop to 1)
```

## The five things to remember

1. **Diagnose before you fix.** The report tells you which technique applies;
   guessing wastes iterations.
2. **Setup vs hold are different problems.** Setup = too slow (RTL/clock). Hold =
   too fast (tool fixes it). This module is all setup.
3. **Structure beats brute force.** A tree vs a chain is free timing. Reach for
   restructuring and pipelining before tool knobs.
4. **The tool amplifies, it doesn't create.** Retiming needs registers; fanout
   fixes need a net problem; seeds need a near-closing design.
5. **Change one thing at a time.** Otherwise you can't tell what helped — and
   timing closure is an attribution problem as much as an optimization one.

## Where to go next (extensions for trainees)

- Bump `G_NUM_TAPS` to 16/32 and watch the chain-vs-tree gap widen.
- Tighten the clock further (3 ns) and find which lab finally fails again.
- Add a `set_multicycle_path` on a deliberately slow path and see the report
  change — the constraint-side technique this module intentionally left out.
- Port the winning structure (L3) back into the project's real `fir_filter`.
