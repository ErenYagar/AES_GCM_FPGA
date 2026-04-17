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
read_xdc {C:/project/top_ghash/top_ghash.srcs/constrs_1/new/clk.xdc}
synth_design -top top -part xc7k70tfbv676-1
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -max_paths 10 -file C:/project/FPGA/impl12_timing_summary.rpt
report_drc -file C:/project/FPGA/impl12_drc.rpt
report_utilization -file C:/project/FPGA/impl12_utilization.rpt
exit
