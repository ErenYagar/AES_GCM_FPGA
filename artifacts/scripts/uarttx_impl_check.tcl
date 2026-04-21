read_verilog {C:/project/FPGA/rtl/top.v}
read_verilog {C:/project/FPGA/rtl/IV_IN.v}
read_verilog {C:/project/FPGA/rtl/AAD_CT_IN.v}
read_verilog {C:/project/FPGA/rtl/GHASH.v}
read_verilog {C:/project/FPGA/rtl/ctr/aes_ctr_wrapper.v}
read_verilog {C:/project/FPGA/rtl/aes_core/AES_e.v}
read_verilog {C:/project/FPGA/rtl/aes_core/KeyGeneration.v}
read_verilog {C:/project/FPGA/rtl/aes_core/addr.v}
read_verilog {C:/project/FPGA/rtl/aes_core/m_col.v}
read_verilog {C:/project/FPGA/rtl/aes_core/s_box.v}
read_verilog {C:/project/FPGA/rtl/aes_core/s_row.v}
read_verilog {C:/project/FPGA/rtl/aes_core/sbox.v}
read_verilog {C:/project/FPGA/rtl/uart_tx.v}
read_verilog {C:/project/FPGA/rtl/fpga_top_arty_a7_uarttx.v}
read_xdc {C:/project/FPGA/arty_a7_100t_uarttx.xdc}
synth_design -top fpga_top_arty_a7_uarttx -part xc7a100tcsg324-1
opt_design
place_design
route_design
report_timing_summary -file {C:/project/FPGA/uarttx_impl_timing.rpt}
report_drc -file {C:/project/FPGA/uarttx_impl_drc.rpt}
report_utilization -file {C:/project/FPGA/uarttx_impl_utilization.rpt}
exit
