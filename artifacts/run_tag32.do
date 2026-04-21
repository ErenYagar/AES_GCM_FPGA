quit -sim
if {[file exists work]} { vdel -lib work -all }
vlib work
vlog -sv -work work C:/project/FPGA/rtl/aes_core/addr.v C:/project/FPGA/rtl/aes_core/AES_e.v C:/project/FPGA/rtl/aes_core/KeyGeneration.v C:/project/FPGA/rtl/aes_core/m_col.v C:/project/FPGA/rtl/aes_core/sbox.v C:/project/FPGA/rtl/aes_core/s_box.v C:/project/FPGA/rtl/aes_core/s_row.v C:/project/FPGA/rtl/ctr/aes_ctr_wrapper.v C:/project/FPGA/rtl/AAD_CT_IN.v C:/project/FPGA/rtl/GHASH.v C:/project/FPGA/rtl/IV_IN.v C:/project/FPGA/rtl/top.v C:/project/FPGA/tb/tb_onecase_tag32_fail.sv
vsim -c work.tb_onecase_tag32_fail -do "run -all; quit -f"
