"C:\Xilinx\Vivado\2021.1\bin\xvlog.bat" --sv -L unisims_ver ^
  C:/project/FPGA/rtl/IV_IN.v ^
  C:/project/FPGA/rtl/AAD_CT_IN.v ^
  C:/project/FPGA/rtl/GHASH.v ^
  C:/project/FPGA/rtl/ctr/aes_ctr_wrapper.v ^
  C:/project/FPGA/rtl/aes_core/sbox.v ^
  C:/project/FPGA/rtl/aes_core/s_box.v ^
  C:/project/FPGA/rtl/aes_core/s_row.v ^
  C:/project/FPGA/rtl/aes_core/m_col.v ^
  C:/project/FPGA/rtl/aes_core/KeyGeneration.v ^
  C:/project/FPGA/rtl/aes_core/addr.v ^
  C:/project/FPGA/rtl/aes_core/AES_e.v ^
  C:/project/FPGA/rtl/top.v ^
  C:/project/FPGA/rtl/uart_tx.v ^
  C:/project/FPGA/rtl/uart_rx.v ^
  C:/project/FPGA/rtl/fpga_top_arty_a7_uart.v ^
  C:/project/FPGA/tb/tb_fpga_top_arty_a7_uart.sv
"C:\Xilinx\Vivado\2021.1\bin\xelab.bat" -L unisims_ver tb_fpga_top_arty_a7_uart -s tb_fpga_top_arty_a7_uart_snapshot
"C:\Xilinx\Vivado\2021.1\bin\xsim.bat" tb_fpga_top_arty_a7_uart_snapshot -runall
