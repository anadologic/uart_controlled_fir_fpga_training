# Lab 3 — DSP48 Pipelined MAC Mapping

**Technique:** map arithmetic to hard blocks with their internal pipeline regs.
**Fixes:** the multiply stage (the heaviest stage left after Lab 2) + routing.
**Change vs Lab 2:** multiplies run inside DSP48E1 slices using the DSP's own
A and M registers.

## The idea

After Lab 2, the worst stage is almost always the **multiply** — multipliers are
big and, in fabric (LUTs), slow. The Artix-7 has hundreds of **DSP48E1** hard
blocks built for exactly this. Each DSP48 has dedicated datapath registers:

```
   A reg --\
            >-- M reg (multiply) -- P reg (add/accumulate)
   B reg --/
```

If you write the multiply with registers in the right places, synthesis packs
them into the DSP's **A** and **M** registers. The multiply then happens in hard
silicon, fully registered, with **no fabric routing** between the multiplier and
its register — the fastest a multiply can be on this device.

This lab adds the `a_r` (A register) and `m_r` (M register) stages and tags
`m_r` with:

```vhdl
attribute USE_DSP : string;
attribute USE_DSP of m_r : signal is "yes";
```

## Why the registers matter (not just USE_DSP)

`USE_DSP = "yes"` asks for a DSP slice, but a DSP slice with its internal
registers *bypassed* is barely faster than fabric. The speed comes from
**inferring the A and M registers** — that is what the explicit `a_r` then `m_r`
pipeline does. The lesson: *hard blocks are only fast when you feed their
internal pipeline registers.* Mapping without pipelining wastes the DSP.

## Cost

- **Latency** rises to **5 cycles** (one extra for the A register).
- **LUT/FF usage drops** — the multiply moves out of fabric into DSPs. Check
  `utilization.rpt`: DSP count up, LUT count down vs Lab 2.

## Run

```
vivado -mode batch -source timing_closure\lab3_dsp_mac\vivado\run_lab.tcl
```

The script also writes `dsp_cells.rpt` and prints the DSP48 count — **confirm
the multipliers really mapped to DSPs** (should be 8, one per tap).

## Compare

| Metric | Lab 2 (fabric mult) | Lab 3 (DSP mult) | Measured |
|--------|---------------------|------------------|----------|
| WNS | +0.144 ns | **+0.089 ns** ✅ | ~same (within noise) |
| DSP48 slices | 7 | 7 | see note below |
| LUT | 80 | **1** | multiply left fabric |
| FF | 223 | 266 | +1 pipeline stage |
| Latency | 4 | 5 | the cost |

> **What actually happened at 8 taps (read this — it corrects a common
> expectation):** DSP mapping did **not** improve WNS (+0.144 → +0.089 ns, a
> change well within placement noise). After Lab 2's pipelining the multiply was
> *no longer the bottleneck*, so moving it into a DSP couldn't speed up the
> already-fast path. What DSP mapping bought instead is **area and robustness**:
> LUT collapsed from 80 to **1** — the entire multiply-add left the fabric and
> lives in hard silicon. The critical path is now a control/routing path, not a
> multiplier.
>
> **DSP count is 7, not 8:** Vivado fused one tap's multiply with an adjacent add
> using a DSP's internal post-adder, so it needed one fewer slice than the naive
> one-per-tap estimate. Functionally identical, just more efficient.
>
> The lesson: **DSP mapping pays off most when the multiply *is* your critical
> path** (e.g. a wider/faster filter, or before pipelining). Here it pays off as
> area — still a real and common reason to do it.

## Reference numbers (Vivado 2023.2, 3.6 ns target)

| Metric | Measured | Yours |
|--------|----------|-------|
| WNS (ns) | **+0.089** ✅ | ____ |
| DSP48 used | 7 | ____ |
| LUT / FF | 1 / 266 | ____ |
| Latency | 5 | 5 |
