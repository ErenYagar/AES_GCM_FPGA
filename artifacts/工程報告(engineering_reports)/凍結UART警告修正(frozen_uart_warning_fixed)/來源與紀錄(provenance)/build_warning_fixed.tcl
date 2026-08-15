set root_dir "C:/project/FPGA2"
set package_dir "$root_dir/artifacts/\u5de5\u7a0b\u5831\u544a(engineering_reports)/\u51cd\u7d50UART\u8b66\u544a\u4fee\u6b63(frozen_uart_warning_fixed)"
set report_dir "$package_dir/\u5831\u544a(reports)"
set checkpoint_dir "$package_dir/\u6aa2\u67e5\u9ede(checkpoint)"
set provenance_dir "$package_dir/\u4f86\u6e90\u8207\u7d00\u9304(provenance)"

foreach dir [list $package_dir $report_dir $checkpoint_dir $provenance_dir] {
    file mkdir $dir
}

set part_name "xc7a100tcsg324-1"
set top_name "fpga_top_arty_a7_uart"
set_param general.maxThreads 2

set rtl_files [list \
    "$root_dir/rtl/aes_core/addr.v" \
    "$root_dir/rtl/aes_core/AES_e.v" \
    "$root_dir/rtl/aes_core/KeyGeneration.v" \
    "$root_dir/rtl/aes_core/m_col.v" \
    "$root_dir/rtl/aes_core/sbox.v" \
    "$root_dir/rtl/aes_core/s_box.v" \
    "$root_dir/rtl/aes_core/s_row.v" \
    "$root_dir/rtl/ctr/aes_ctr_wrapper.v" \
    "$root_dir/rtl/AAD_CT_IN.v" \
    "$root_dir/rtl/GHASH.v" \
    "$root_dir/rtl/IV_IN.v" \
    "$root_dir/rtl/top.v" \
    "$root_dir/rtl/uart_rx.v" \
    "$root_dir/rtl/uart_tx.v" \
    "$root_dir/rtl/fpga_top_arty_a7_uart.v" \
]
set xdc_file "$root_dir/arty_a7_100t_uart.xdc"

create_project -in_memory -part $part_name
read_verilog $rtl_files
read_xdc $xdc_file
synth_design -top $top_name -part $part_name
opt_design
place_design
phys_opt_design
route_design

report_timing_summary -max_paths 10 -file "$report_dir/timing_summary.rpt"
report_timing -delay_type max -max_paths 10 -path_type full -file "$report_dir/critical_paths_setup_top10.rpt"
report_timing -delay_type min -max_paths 10 -path_type full -file "$report_dir/critical_paths_hold_top10.rpt"
report_utilization -file "$report_dir/utilization.rpt"
report_route_status -file "$report_dir/route_status.rpt"
report_drc -file "$report_dir/drc.rpt"
report_methodology -file "$report_dir/methodology.rpt"
report_clock_interaction -file "$report_dir/clock_interaction.rpt"
report_cdc -details -show_waiver -file "$report_dir/cdc.rpt"
check_timing -verbose -file "$report_dir/check_timing.rpt"
report_clocks -file "$report_dir/clocks.rpt"
report_power -advisory -file "$report_dir/power.rpt"

write_checkpoint -force "$checkpoint_dir/fpga_top_arty_a7_uart_warning_fixed_routed.dcp"

set setup_path [get_timing_paths -delay_type max -max_paths 1]
set hold_path [get_timing_paths -delay_type min -max_paths 1]
set result_fp [open "$provenance_dir/build_result.txt" w]
puts $result_fp "vivado_version=[version -short]"
puts $result_fp "design=[current_design]"
puts $result_fp "part=[get_property PART [current_design]]"
puts $result_fp "setup_wns_ns=[get_property SLACK $setup_path]"
puts $result_fp "hold_whs_ns=[get_property SLACK $hold_path]"
puts $result_fp "drc_violation_count=[llength [get_drc_violations]]"
puts $result_fp "routing_error_count=[llength [get_nets -quiet -hierarchical -filter {ROUTE_STATUS == UNROUTED}]]"
foreach clock [get_clocks] {
    puts $result_fp "clock=[get_property NAME $clock],period_ns=[get_property PERIOD $clock]"
}
close $result_fp

puts "WARNING_FIXED_BUILD_COMPLETE"
puts "WARNING_FIXED_PACKAGE=$package_dir"
exit
