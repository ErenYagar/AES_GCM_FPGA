read_verilog {C:/project/FPGA/rtl/top.v}
read_verilog {C:/project/FPGA/rtl/IV_IN.v}
read_verilog {C:/project/FPGA/rtl/AAD_CT_IN.v}
read_verilog {C:/project/FPGA/rtl/GHASH.v}
read_verilog {C:/project/FPGA/rtl/fpga_top_arty_a7_selftest.v}
read_verilog {C:/project/FPGA/rtl/ctr/aes_ctr_wrapper.v}
read_verilog {C:/project/FPGA/rtl/aes_core/AES_e.v}
read_verilog {C:/project/FPGA/rtl/aes_core/KeyGeneration.v}
read_verilog {C:/project/FPGA/rtl/aes_core/addr.v}
read_verilog {C:/project/FPGA/rtl/aes_core/m_col.v}
read_verilog {C:/project/FPGA/rtl/aes_core/s_box.v}
read_verilog {C:/project/FPGA/rtl/aes_core/s_row.v}
read_verilog {C:/project/FPGA/rtl/aes_core/sbox.v}
read_xdc {C:/project/FPGA/arty_a7_100t_selftest.xdc}
synth_design -top fpga_top_arty_a7_selftest -part xc7a100tcsg324-1
report_timing_summary -file C:/project/FPGA/selftest_synth_timing.rpt
exit
