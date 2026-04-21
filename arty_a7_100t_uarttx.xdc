## Arty A7-100T board constraints for fpga_top_arty_a7_uarttx

## 100 MHz system clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name sys_clk_pin -period 10.000 -waveform {0.000 5.000} [get_ports clk]

## 25 MHz internal core clock from fabric divide-by-4 and BUFG
create_clock -name core_clk -period 40.000 [get_pins u_core_clk_buf/O]

## Reset button
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports rst_btn]

## User LEDs
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## USB-UART interface: FPGA TX -> USB-UART RX
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports uart_rxd_out]

## Configuration voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
