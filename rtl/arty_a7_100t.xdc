## Clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name sys_clk_pin -period 10.000 -waveform {0.000 5.000} [get_ports clk]

## Reset button
set_property -dict { PACKAGE_PIN C2 IOSTANDARD LVCMOS33 } [get_ports rst_btn]

## LEDs
set_property -dict { PACKAGE_PIN H5  IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5  IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

## Configuration voltage
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
