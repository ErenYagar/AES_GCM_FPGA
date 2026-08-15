set root_dir "C:/project/FPGA2"
set package_dir "$root_dir/artifacts/\u5de5\u7a0b\u5831\u544a(engineering_reports)/\u51cd\u7d50UART(frozen_uart)"
set checkpoint "$package_dir/\u6aa2\u67e5\u9ede(checkpoint)/fpga_top_arty_a7_uart_routed.dcp"

open_checkpoint $checkpoint
set worst_setup_path [get_timing_paths -delay_type max -max_paths 1]
set path_cells [get_cells -quiet -of_objects $worst_setup_path]
set path_nets [get_nets -quiet -of_objects $worst_setup_path]
highlight_objects -color red $path_cells
highlight_objects -color yellow $path_nets
select_objects $path_cells
select_objects -add $path_nets
show_objects -name "Worst Setup Path Objects (Post-Route)" [concat $path_cells $path_nets]
puts "ROUTING_GUI_READY"
