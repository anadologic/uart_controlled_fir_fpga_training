################################################################################
## top_synth_demo.xdc
## Board  : Digilent Nexys A7-100T (xc7a100tcsg324-1)
## Top    : top_synth_demo
##
## Port mapping:
##   clk        -> 100 MHz on-board oscillator
##   rst_n      -> CPU_RESETN push button (active low)
##   uart_rx_i  -> USB-RS232 bridge, FTDI TXD (PC -> FPGA)
##   uart_tx_o  -> USB-RS232 bridge, FTDI RXD (FPGA -> PC)
##   led_o[3:0] -> LED[3:0]
################################################################################

## Clock signal (100 MHz)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }]; #IO_L12P_T1_MRCC_35 Sch=clk100mhz
create_clock -add -name sys_clk -period 10.000 -waveform {0 5} [get_ports { clk }]

## Reset button (CPU_RESETN, active low)
set_property -dict { PACKAGE_PIN C12   IOSTANDARD LVCMOS33 } [get_ports { rst_n }]; #IO_L3P_T0_DQS_AD1P_15 Sch=cpu_resetn

## USB-RS232 interface
set_property -dict { PACKAGE_PIN C4    IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; #IO_L7P_T1_AD6P_35 Sch=uart_txd_in
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports { uart_tx_o }]; #IO_L11N_T1_SRCC_35 Sch=uart_rxd_out

## LEDs
set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { led_o[0] }]; #IO_L18P_T2_A24_15 Sch=led[0]
set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { led_o[1] }]; #IO_L24P_T3_RS1_15 Sch=led[1]
set_property -dict { PACKAGE_PIN J13   IOSTANDARD LVCMOS33 } [get_ports { led_o[2] }]; #IO_L17N_T2_A25_15 Sch=led[2]
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { led_o[3] }]; #IO_L8P_T1_D11_14 Sch=led[3]

################################################################################
## Timing exceptions
################################################################################

## rst_n is asynchronous and synchronized inside reset_sync (ASYNC_REG chain).
set_false_path -from [get_ports rst_n]

## uart_rx_i is asynchronous and double-registered inside uart_rx.
set_false_path -from [get_ports uart_rx_i]

## Slow outputs with no external timing requirement.
set_false_path -to [get_ports uart_tx_o]
set_false_path -to [get_ports {led_o[*]}]

################################################################################
## Configuration
################################################################################

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

################################################################################
## Optional attribute demos (XDC instead of RTL) - keep commented for training
################################################################################

## Mark a debug net from XDC instead of RTL.
# set_property MARK_DEBUG true [get_nets -hier *parser_state_dbg*]

## Preserve a selected net.
# set_property KEEP true [get_nets -hier *dbg_reg*]

## Do not optimize a selected cell.
# set_property DONT_TOUCH true [get_cells -hier *u_fir_filter*]

## Example IOB packing on output registers, if register names are stable.
# set_property IOB TRUE [get_cells -hier *led_reg_reg*]
