read_verilog {C:/project/FPGA/rtl/IV_IN.v}
read_verilog {C:/project/FPGA/rtl/AAD_CT_IN.v}
read_verilog {C:/project/FPGA/rtl/GHASH.v}
read_verilog {C:/project/FPGA/rtl/ctr/aes_ctr_wrapper.v}
read_verilog {C:/project/FPGA/rtl/aes_core/sbox.v}
read_verilog {C:/project/FPGA/rtl/aes_core/s_box.v}
read_verilog {C:/project/FPGA/rtl/aes_core/s_row.v}
read_verilog {C:/project/FPGA/rtl/aes_core/m_col.v}
read_verilog {C:/project/FPGA/rtl/aes_core/KeyGeneration.v}
read_verilog {C:/project/FPGA/rtl/aes_core/addr.v}
read_verilog {C:/project/FPGA/rtl/aes_core/AES_e.v}
read_verilog {C:/project/FPGA/rtl/top.v}
synth_design -top top -part xc7a200tffg1156-3
report_utilization -file C:/project/FPGA/synth_util_tmp.rpt
exit
