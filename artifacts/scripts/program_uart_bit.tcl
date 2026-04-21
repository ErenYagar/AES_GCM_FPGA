set root "C:/project/FPGA"
set bitfile "$root/artifacts/fpga_top_arty_a7_uart_fixed.bit"

open_hw_manager
connect_hw_server
open_hw_target
current_hw_device [lindex [get_hw_devices xc7a100t_0] 0]
refresh_hw_device -update_hw_probes false [current_hw_device]
set_property PROGRAM.FILE $bitfile [current_hw_device]
program_hw_devices [current_hw_device]
close_hw_target
disconnect_hw_server
close_hw_manager

exit
