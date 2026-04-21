set root "C:/project/FPGA"
set part "xc7a100tcsg324-1"
set top "fpga_top_arty_a7_uart"
set out_bit "$root/artifacts/fpga_top_arty_a7_uart_fixed.bit"
set out_timing "$root/artifacts/fpga_top_arty_a7_uart_fixed_timing.rpt"
set out_drc "$root/artifacts/fpga_top_arty_a7_uart_fixed_drc.rpt"
set out_util "$root/artifacts/fpga_top_arty_a7_uart_fixed_util.rpt"

read_verilog \
  "$root/rtl/aes_core/addr.v" \
  "$root/rtl/aes_core/AES_e.v" \
  "$root/rtl/aes_core/KeyGeneration.v" \
  "$root/rtl/aes_core/m_col.v" \
  "$root/rtl/aes_core/sbox.v" \
  "$root/rtl/aes_core/s_box.v" \
  "$root/rtl/aes_core/s_row.v" \
  "$root/rtl/ctr/aes_ctr_wrapper.v" \
  "$root/rtl/AAD_CT_IN.v" \
  "$root/rtl/GHASH.v" \
  "$root/rtl/IV_IN.v" \
  "$root/rtl/top.v" \
  "$root/rtl/uart_rx.v" \
  "$root/rtl/uart_tx.v" \
  "$root/rtl/fpga_top_arty_a7_uart.v"

read_xdc "$root/arty_a7_100t_uart.xdc"

synth_design -top $top -part $part
opt_design
place_design
phys_opt_design
route_design

report_timing_summary -file $out_timing
report_drc -file $out_drc
report_utilization -file $out_util

write_bitstream -force $out_bit

open_hw_manager
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices xc7a100t_0] 0]
refresh_hw_device -update_hw_probes false [current_hw_device]
set_property PROGRAM.FILE $out_bit [current_hw_device]
program_hw_devices [current_hw_device]
close_hw_target
disconnect_hw_server
close_hw_manager

exit
