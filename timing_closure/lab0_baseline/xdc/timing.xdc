################################################################################
## timing.xdc  (LAB 0 - baseline)
## Board : Nexys A7-100T (xc7a100tcsg324-1, speed grade -1)
##
## THE STRESS LIVES HERE.
##
## We constrain the clock to ~278 MHz (3.600 ns). The board oscillator is only
## 100 MHz, so this is NOT physically runnable on hardware - it is a deliberate
## over-constraint to force the tool to report negative slack on a path that
## would otherwise pass with ease. Timing closure is about the REPORT, and the
## report is driven by the constraint, not by the oscillator.
##
## All labs in this module share this 3.6 ns target so WNS is comparable across
## labs. It was chosen empirically so the chain (L0) and tree (L1) FAIL while the
## pipelined designs (L2, L3) PASS - making "pipelining is what closes timing"
## the visible lesson. Each lab changes the RTL or tool flow, never this number.
################################################################################

create_clock -name sys_clk -period 3.600 -waveform {0 1.800} [get_ports clk]

## Isolate the FIR: these labs teach INTERNAL register-to-register timing, so we
## explicitly remove the I/O paths from analysis. Without this, once the FIR path
## is optimized the next-worst path becomes an OBUF/IBUF I/O path governed by the
## (artificial) fast clock - which no RTL technique can fix - and it would MASK
## the real FIR improvement in the WNS headline. False-pathing the ports keeps
## WNS reporting the thing the lab is actually about.
set_false_path -from [get_ports {sample_valid_i sample_data_i[*]}]
set_false_path -from [get_ports rst]
set_false_path -to   [get_ports {result_valid_o result_data_o[*]}]
