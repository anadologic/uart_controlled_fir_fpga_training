# Lab 1 — Adder Chain → Balanced Adder Tree

**Technique:** RTL restructuring. **Fixes:** logic depth.
**Change vs Lab 0:** the summation shape only — chain becomes a tree.

## The idea

Lab 0 summed 8 products as a **linear chain** — each adder waits for the one
before it, so 8 taps = **7 adders in series** = 7 logic levels of addition:

```
(((((((p0+p1)+p2)+p3)+p4)+p5)+p6)+p7)
```

Lab 1 sums them as a **balanced binary tree** — independent adders run in
parallel, so depth is `ceil(log2(8)) = 3` levels:

```
level 0:   p0+p1    p2+p3    p4+p5    p6+p7      (4 adders, parallel)
level 1:    \__+__/           \__+__/            (2 adders, parallel)
level 2:        \________+________/              (1 adder)
```

**Same products, same total number of adders (7), same area** — only the
*dependency structure* changed. The critical path drops from 7 add-delays to 3.

## Why this matters conceptually

Logic-level count, not gate count, sets the combinational path length. Two
circuits with identical area can have wildly different Fmax purely from how the
operations are *chained*. Restructuring a chain into a tree is the cheapest
timing win available — it costs (almost) nothing.

> **Note:** synthesis *can* sometimes re-balance an addition itself, but you
> should never rely on it — associativity reordering of signed arithmetic is not
> always applied, and writing the tree explicitly guarantees the structure.

## Run

```
vivado -mode batch -source timing_closure\lab1_adder_tree\vivado\run_lab.tcl
```

## Compare against Lab 0

Open both `timing_worst_paths.rpt` files side by side:

| Metric | Lab 0 (chain) | Lab 1 (tree) | Measured |
|--------|---------------|--------------|----------|
| Logic levels (worst path) | 24 | **10** | tree much lower |
| WNS | −12.117 ns | **−4.395 ns** | improved ~7.7 ns |
| LUT / DSP / FF | 109 / 2 / 195 | 122 / 2 / 195 | ~same area |

Lab 1 still **fails timing** (WNS = −4.395 ns at 3.6 ns) — the multiplier delay
plus 3 adder levels is still far too much for a 3.6 ns clock. That is
intentional: Lab 1 shows restructuring *helps* (logic levels 24→10, path delay
roughly halved) but is *not sufficient* alone. Pipelining (Lab 2) is the lever
that finally crosses zero.

## Reference numbers (Vivado 2023.2, 3.6 ns target)

| Metric | Measured | Yours |
|--------|----------|-------|
| WNS (ns) | **−4.395** ❌ | ____ |
| Logic levels | 10 (CARRY4=8, LUT2=2) | ____ |
| DSP / LUT / FF | 2 / 122 / 195 | ____ |
