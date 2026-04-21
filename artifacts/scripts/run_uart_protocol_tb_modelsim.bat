@echo off
setlocal

set MSIM=C:\intelFPGA_lite\17.0\modelsim_ase\win32aloem
set WORKDIR=C:\project\FPGA\msim_uart

if exist "%WORKDIR%" rmdir /s /q "%WORKDIR%"
mkdir "%WORKDIR%"
cd /d "%WORKDIR%"

"%MSIM%\vlib.exe" work || exit /b 1
"%MSIM%\vlog.exe" -sv ^
  ..\tb\bufg_stub.v ^
  ..\rtl\IV_IN.v ^
  ..\rtl\AAD_CT_IN.v ^
  ..\rtl\GHASH.v ^
  ..\rtl\ctr\aes_ctr_wrapper.v ^
  ..\rtl\aes_core\sbox.v ^
  ..\rtl\aes_core\s_box.v ^
  ..\rtl\aes_core\s_row.v ^
  ..\rtl\aes_core\m_col.v ^
  ..\rtl\aes_core\KeyGeneration.v ^
  ..\rtl\aes_core\addr.v ^
  ..\rtl\aes_core\AES_e.v ^
  ..\rtl\top.v ^
  ..\rtl\uart_tx.v ^
  ..\rtl\uart_rx.v ^
  ..\rtl\fpga_top_arty_a7_uart.v ^
  ..\tb\tb_fpga_top_arty_a7_uart.sv || exit /b 1

"%MSIM%\vsim.exe" -c tb_fpga_top_arty_a7_uart -do "run -all; quit -f"
