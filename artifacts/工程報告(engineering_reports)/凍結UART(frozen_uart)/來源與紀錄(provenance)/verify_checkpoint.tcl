set root_dir "C:/project/FPGA2"
set package_dir "$root_dir/artifacts/\u5de5\u7a0b\u5831\u544a(engineering_reports)/\u51cd\u7d50UART(frozen_uart)"
set checkpoint "$package_dir/\u6aa2\u67e5\u9ede(checkpoint)/fpga_top_arty_a7_uart_routed.dcp"
set result_file "$package_dir/\u4f86\u6e90\u8207\u7d00\u9304(provenance)/checkpoint_validation.txt"

open_checkpoint $checkpoint
set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
set unrouted_nets [get_nets -quiet -hierarchical -filter {ROUTE_STATUS == UNROUTED}]
report_drc -return_string

set fp [open $result_file w]
puts $fp "checkpoint_open=PASS"
puts $fp "vivado_version=[version -short]"
puts $fp "design=[current_design]"
puts $fp "part=[get_property PART [current_design]]"
puts $fp "setup_wns_ns=[get_property SLACK $setup_path]"
puts $fp "hold_whs_ns=[get_property SLACK $hold_path]"
puts $fp "drc_violation_count=[llength [get_drc_violations]]"
puts $fp "unrouted_net_count=[llength $unrouted_nets]"
foreach clock [get_clocks] {
    puts $fp "clock=[get_property NAME $clock],period_ns=[get_property PERIOD $clock]"
}
close $fp

puts "CHECKPOINT_VALIDATION_COMPLETE"
exit
