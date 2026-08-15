## Arty A7-100T board constraints for fpga_top_arty_a7_uart

## 100 MHz system clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name sys_clk_pin -period 10.000 -waveform {0.000 5.000} [get_ports clk]

## The MMCM automatically derives the 25 MHz core clock from sys_clk_pin.
## Do not redefine the propagated clock at the downstream BUFG output.

## Reset button (active-low on board)
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports rst_btn]
set_false_path -from [get_ports rst_btn]

## User LEDs
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_false_path -to [get_ports {led[*]}]

## USB-UART
set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33 } [get_ports uart_txd_in]
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports uart_rxd_out]
## UART is asynchronous to the FPGA clock. The receiver uses a two-register
## synchronizer, and the transmitter is sampled by the remote UART baud clock.
set_false_path -from [get_ports uart_txd_in]
set_false_path -to [get_ports uart_rxd_out]

## Configuration voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
