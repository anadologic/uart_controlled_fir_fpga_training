# Lab 4 — Tool-Flow Techniques (no RTL changes)

**Technique:** make the *tool* work harder on the *same* source.
**Fixes:** stage imbalance, fanout, lost cross-boundary optimization, and the
last few picoseconds of slack.

This lab reuses **Lab 2's pipeline RTL unchanged** (on purpose — it is hand-
placed and *not* delay-balanced) and shows what synthesis/implementation
settings can recover without you editing a single line of VHDL.

Run each script and compare its WNS against `01_baseline.tcl`.

| Script | Technique | Lever |
|--------|-----------|-------|
| [01_baseline.tcl](vivado/01_baseline.tcl) | default flow (reference) | — |
| [02_retiming.tcl](vivado/02_retiming.tcl) | retiming / register balancing | `synth -retiming`, `phys_opt -retime` |
| [03_phys_opt.tcl](vivado/03_phys_opt.tcl) | physical optimization | `phys_opt_design -directive` |
| [04_fanout.tcl](vivado/04_fanout.tcl) | fanout / register duplication | `-fanout_limit`, `MAX_FANOUT` |
| [05_flatten.tcl](vivado/05_flatten.tcl) | flatten vs preserve hierarchy | `-flatten_hierarchy` |
| [06_seed_sweep.tcl](vivado/06_seed_sweep.tcl) | cost tables / seeds / strategies | `place -directive` (see note) |

---

## 1. Retiming / register balancing — `02_retiming.tcl`

**Retiming** moves registers across combinational logic *without changing the
function or the latency* — only *where* the flip-flops sit. The goal is to
**balance the delay between every pair of registers** so the slowest stage (which
sets Fmax) gets faster.

```
Before:  FF --[ 7ns logic ]-- FF --[ 1ns logic ]-- FF     Fmax limited by 7 ns
After:   FF --[ 4ns logic ]-- FF --[ 4ns logic ]-- FF     Fmax limited by 4 ns
```

**Register balancing** is just retiming applied to a pipeline you already built:
the tool redistributes logic between *your* stage registers so each stage has
roughly equal delay. Lab 2's multiply stage is heavier than its add stages —
retiming slides registers to even them out.

**Key rule:** retiming only *moves* existing registers; it **cannot add latency**.
That is why this lab works on the *pipelined* design — there are spare registers
in the light stages to absorb work. On Lab 0/1 (no pipeline) `-retiming` does
almost nothing. Also: a `KEEP`/`DONT_TOUCH` on a register **disables** retiming
there — a common accidental footgun.

The `phys_opt_design -retime` pass is often the bigger win because it retimes
using *real* post-placement routing delays, not synthesis estimates.

---

## 2. Physical optimization — `03_phys_opt.tcl`

`phys_opt_design` runs *after* placement, when real routing delays are known, and
fixes what placement exposed: replicates high-fanout drivers, nudges critical
cells, rewires, and retimes. Directives escalate effort:
`Default → Explore → AggressiveExplore → AggressiveFanoutOpt`. The script prints
WNS before and after so you see the pass earn its keep.

---

## 3. Fanout / register duplication — `04_fanout.tcl`

**Fanout** = how many loads one driver feeds. High fanout means a long net the
placer cannot keep short, so net delay grows. **Duplicating** the driver lets
each copy sit near its own cluster of loads:

```
   FF --> 64 loads        =>     FF_a --> loads 1-16   (each net short,
   (one long net)                FF_b --> loads 17-32   placed locally)
                                 FF_c --> loads 33-48
                                 FF_d --> loads 49-64
```

- `synth_design -fanout_limit N` — **global** default threshold.
- `MAX_FANOUT` attribute/property — **targeted** at one identified net.

**Caveat that matters:** duplication only helps when **net delay** dominates the
path. If the path is slow because of **logic depth** (cells), duplication does
nothing — pipeline instead. *Always read the net-vs-logic split first.* This 8-
tap FIR is small, so fanout likely is not the limiter here; the script teaches
the mechanism and `report_high_fanout_nets` so you can recognize the real case.

---

## 4. Flatten vs preserve hierarchy — `05_flatten.tcl`

Optimization opportunities often straddle a module boundary (e.g. unused result
bits on the far side of a port). Preserving the boundary hides them; flattening
exposes them.

| Mode | Meaning |
|------|---------|
| `none` | preserve every boundary — readable reports, least optimization |
| `rebuilt` | **default** — flatten to optimize, then restore names for reports |
| `full` | flatten everything, no rebuild — max optimization, flat/ugly reports |

Plus `KEEP_HIERARCHY` to *protect* one module (a hand-tuned tree, a CDC
synchronizer) from being dissolved even under `full`. The script synthesizes all
three modes and prints WNS + LUT for each so you can see boundaries cost timing.
The trade-off: more flattening = better timing/area but worse debuggability.

---

## 5. Cost tables / seeds / strategies — `06_seed_sweep.tcl`

P&R is an NP-hard **heuristic**, not a solver. A different starting point yields a
different legal placement and different slack. The script sweeps several **placer
directives** on the *same* post-opt netlist and reports the WNS spread.

> **Vivado-version note (important):** older Vivado exposed
> `place_design -cost_table <1-100>` as the seed knob. In **2023.2 that flag was
> removed** — `place_design` no longer accepts `-cost_table`. The supported
> equivalent in the non-project flow is to sweep `place_design -directive <name>`
> (each directive is a different heuristic configuration / starting point). In the
> *project* flow you express the same idea as implementation strategies run in
> parallel (see the bottom of the script). The teaching point — "a different seed
> gives different slack" — is unchanged; only the command moved.

**The honest framing — teach this hard:**
- Seeds buy the **last picoseconds**. If WNS is −0.05 ns, a lucky seed may reach
  +0.10 ns and you ship.
- If WNS is −3 ns, **no seed will save you** — fix the RTL (Labs 1–3).
- A design that closes on only *one* lucky seed is **fragile**: a tiny RTL edit
  reshuffles placement and it fails again.

So seed-sweeping is the *last* resort and a *fragility warning*, never a
substitute for architecture.

---

## The Lab 4 takeaway

The tool can rebalance, replicate, flatten, and re-seed — but every one of these
**amplifies** a sound design; none **creates** one. Retiming needs registers to
move; fanout fixes need a net-delay problem; seeds need a design that is already
close. **Diagnose first** (Lab 0), fix the architecture (Labs 1–3), then let the
tool flow close the gap (Lab 4).

## Reference numbers (Vivado 2023.2, 3.6 ns target, RTL = Lab 2 pipeline)

Baseline WNS = **+0.144 ns**. Each lever's measured effect:

| Script | Result (WNS, ns) | Reading |
|--------|------------------|---------|
| 01 baseline | +0.144 | reference |
| 02 retiming | +0.144 (no change) | nothing to rebalance — see below |
| 03 phys_opt | +0.144 (was +0.245 mid-flow) | no net-delay/fanout problem to fix here |
| 04 fanout | +0.144 ("No nets found for high-fanout optimization") | this design has no high-fanout net |
| 05 flatten | none **+0.292** / rebuilt +0.144 / full +0.061 | boundaries *helped* here (see below) |
| 06 seed sweep | Default +0.144 / Explore +0.190 / **ExtraTimingOpt +0.352** / ExtraPostPlacementOpt +0.293 / ExtraNetDelay_high +0.190 | directive choice swings WNS by ~0.2 ns |

### What the measurements actually taught (some defied the textbook)

- **Retiming did nothing (02).** The Lab 2 pipeline is already balanced enough,
  and synthesis had *already* absorbed the products into DSP registers — there
  were no spare fabric registers to slide. Retiming amplifies an *unbalanced*
  pipeline; this one wasn't. A clean demonstration of "the tool can't help if
  there's no imbalance to fix."
- **Fanout found nothing (04).** Vivado reported *"No nets found for high-fanout
  optimization."* An 8-tap FIR simply has no high-fanout net — exactly why the
  doc warned this lever only matters on net-delay-dominated paths. The lesson is
  recognizing *when it does not apply*.
- **Flatten was the surprise (05).** `none` (+0.292) beat `full` (+0.061) here —
  the opposite of the usual "flatten more = faster." With this tiny design,
  preserving boundaries gave the placer cleaner groupings, while aggressive
  flattening spread logic out and *hurt* WNS. LUT count was identical (81) all
  three ways. Great evidence that "more optimization" is not monotonic — measure,
  don't assume.
- **Seed sweep worked as advertised (06).** Same netlist, WNS from +0.144 to
  **+0.352** purely by placer directive — ~0.2 ns of "free" slack from luck. This
  is the real last-picosecond lever. But note: it's only +0.2 ns. If the design
  were −3 ns, none of these directives would rescue it.

**Bottom line for trainees:** on an already-closing, well-pipelined design, the
tool-flow knobs mostly do *nothing* (02, 03, 04) or behave *non-intuitively*
(05) — and the one reliable win (06) is small. That is the honest shape of
tool-flow optimization: it is the finish line, not the race.

---

## Reference numbers — same scripts on the LAB 1 design (the failing one)

The lab ships pointed at the Lab 2 pipeline (which already passes). But the more
revealing experiment is to run the *same* tool-flow scripts on the **Lab 1
combinational adder tree** — a design that *fails* by a wide margin
(WNS = −4.395 ns). This answers "can the tool rescue a design that's deeply
negative?" To reproduce: swap `lab1_adder_tree/rtl/fir_parallel.vhd` into
`lab4_tool_flow/rtl/` and re-run the scripts. (Measured Vivado 2023.2, 3.6 ns.)

| Script | Result (WNS, ns) | Reading |
|--------|------------------|---------|
| 01 baseline | −4.395 | reference (fails) |
| 02 retiming | **−1.273** | **huge +3.1 ns recovery** — see below |
| 03 phys_opt | −4.380 (was −4.523 mid-flow) | negligible |
| 04 fanout | −4.380 | negligible (no high-fanout net) |
| 05 flatten | none −4.395 / rebuilt −4.395 / full **−4.279** | tiny; flatten=full best here |
| 06 seed sweep | Default −4.380 / Explore −4.380 / ExtraTimingOpt −4.692 / ExtraPostPlacementOpt −4.380 / **ExtraNetDelay_high −4.292** | ±0.4 ns jitter, none close to zero |

### The headline: retiming behaves the OPPOSITE of the Lab 2 case

- **Retiming recovered 3.1 ns here (02): −4.395 → −1.273.** On the Lab 1 design
  the whole multiply-add cloud sits between *one* input register stage and the
  *one* output register `result_r` — a massively **unbalanced** single stage.
  `synth -retiming` + `phys_opt -retime` pulled the output register *backward*
  into the combinational cloud, splitting that long path. This is the textbook
  retiming win — and the direct contrast with the Lab 2 run above, where
  retiming did *nothing* because the pipeline was already balanced. Same lever,
  opposite outcome, decided entirely by whether an imbalance exists to fix.
- **But retiming still did not close timing.** −1.273 ns is a big improvement and
  still a **failure**. Retiming can only move the registers that *exist*; with
  just two register stages around the cloud there is a hard limit to how short
  the worst stage can get. To actually close, you must *add* registers in RTL —
  which is precisely Lab 2 (pipelining). Retiming amplifies; it cannot create the
  latency pipelining provides.
- **phys_opt, fanout, flatten, seeds: all negligible (03–06).** None moved WNS
  more than ~0.2 ns, and the seed sweep's *best* directive (−4.292) is still
  nowhere near zero. This is the lesson stated bluntly in §5: **when a design is
  deeply negative, no placement seed or directive will save it.** They polish;
  they do not pipeline.

**The two runs side by side (the real takeaway):**

| Lever | Lab 2 (balanced, passes) | Lab 1 (unbalanced, fails badly) |
|-------|--------------------------|----------------------------------|
| retiming | no effect (nothing to balance) | **+3.1 ns** (big imbalance to fix) |
| seeds/directives | ±0.2 ns (the finish line) | ±0.4 ns jitter (hopeless from −4.4) |

Tool flow's value depends entirely on the *state of the design you feed it*. It
rebalances and polishes — it never substitutes for the architecture (Labs 1–3).
