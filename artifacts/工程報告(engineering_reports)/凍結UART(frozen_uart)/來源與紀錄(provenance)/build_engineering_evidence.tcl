set root_dir "C:/project/FPGA2"
set package_dir "$root_dir/artifacts/\u5de5\u7a0b\u5831\u544a(engineering_reports)/\u51cd\u7d50UART(frozen_uart)"
set report_dir "$package_dir/\u5831\u544a(reports)"
set visual_dir "$package_dir/\u5716\u50cf(visuals)"
set checkpoint_dir "$package_dir/\u6aa2\u67e5\u9ede(checkpoint)"
set provenance_dir "$package_dir/\u4f86\u6e90\u8207\u7d00\u9304(provenance)"

set part_name "xc7a100tcsg324-1"
set top_name "fpga_top_arty_a7_uart"

foreach dir [list $package_dir $report_dir $visual_dir $checkpoint_dir $provenance_dir] {
    file mkdir $dir
}

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

proc write_metadata {path phase} {
    global part_name top_name rtl_files xdc_file
    set fp [open $path w]
    puts $fp "phase=$phase"
    puts $fp "vivado_version=[version -short]"
    puts $fp "top=$top_name"
    puts $fp "part=$part_name"
    puts $fp "system_clock_mhz=100"
    puts $fp "core_clock_mhz=25"
    puts $fp "power_method=post-route vectorless estimate; not board measurement"
    puts $fp "source_equivalence=tracked RTL/XDC match commit ef6d1b8f; binary identity is not claimed"
    foreach source $rtl_files {
        puts $fp "rtl=$source"
    }
    puts $fp "xdc=$xdc_file"
    close $fp
}

proc require_objects {objects label} {
    if {[llength $objects] == 0} {
        error "No objects found for $label"
    }
    return $objects
}

write_metadata "$provenance_dir/build_metadata.txt" "pre-build"

# Elaborated RTL views.
create_project -in_memory -part $part_name
read_verilog $rtl_files
read_xdc $xdc_file
synth_design -rtl -name rtl_evidence -top $top_name -part $part_name

set rtl_top_cells [require_objects [get_cells -quiet *] "elaborated top-level cells"]
show_schematic -name "Elaborated RTL Top" $rtl_top_cells
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Elaborated RTL Top" "$visual_dir/elaborated_rtl_top.svg"

set rtl_core_cells [require_objects [get_cells -quiet -hierarchical {u_core u_core/u_iv_in u_core/u_aad_ct_in u_core/u_hcalc u_core/u_data_ctr u_core/u_tag_ctr u_core/u_ghash}] "elaborated AES-GCM core cells"]
show_schematic -name "Elaborated AES-GCM Core" $rtl_core_cells
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Elaborated AES-GCM Core" "$visual_dir/elaborated_aes_gcm_core.svg"

close_design
close_project

# Source-equivalent Frozen UART implementation. This intentionally stops before
# write_bitstream and never opens the hardware manager.
create_project -in_memory -part $part_name
read_verilog $rtl_files
read_xdc $xdc_file
synth_design -top $top_name -part $part_name

set synth_top_cells [require_objects [get_cells -quiet *] "synthesized top-level cells"]
show_schematic -name "Synthesized Top Netlist" $synth_top_cells
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Synthesized Top Netlist" "$visual_dir/synthesized_top_netlist.svg"

set synth_crypto_cells [get_cells -quiet -hierarchical -filter {ORIG_REF_NAME =~ "top" || ORIG_REF_NAME =~ "AES_e" || ORIG_REF_NAME =~ "GHASH" || ORIG_REF_NAME =~ "aes_ctr_wrapper"}]
set synth_crypto_cells [require_objects $synth_crypto_cells "synthesized crypto datapath cells"]
show_schematic -name "Synthesized Crypto Datapath" $synth_crypto_cells
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Synthesized Crypto Datapath" "$visual_dir/synthesized_crypto_datapath.svg"

opt_design
place_design
phys_opt_design
route_design

report_timing_summary -max_paths 10 -file "$report_dir/timing_summary.rpt"
report_timing -delay_type max -max_paths 10 -path_type full -file "$report_dir/critical_paths_setup_top10.rpt"
report_timing -delay_type min -max_paths 10 -path_type full -file "$report_dir/critical_paths_hold_top10.rpt"
report_utilization -file "$report_dir/utilization.rpt"
report_utilization -hierarchical -hierarchical_depth 4 -hierarchical_percentages -file "$report_dir/utilization_hierarchical.rpt"
report_route_status -file "$report_dir/route_status.rpt"
report_drc -file "$report_dir/drc.rpt"
report_methodology -file "$report_dir/methodology.rpt"
report_design_analysis -timing -setup -max_paths 10 -show_all -file "$report_dir/design_analysis_timing_setup.rpt"
report_design_analysis -timing -hold -max_paths 10 -show_all -file "$report_dir/design_analysis_timing_hold.rpt"
report_design_analysis -complexity -hierarchical_depth 4 -file "$report_dir/design_analysis_complexity.rpt"
report_design_analysis -congestion -min_congestion_level 3 -file "$report_dir/design_analysis_congestion.rpt"
report_design_analysis -logic_level_distribution -logic_level_dist_paths 1000 -file "$report_dir/design_analysis_logic_levels.rpt"
report_design_analysis -qor_summary -file "$report_dir/design_analysis_qor_summary.rpt"
report_qor_assessment -max_paths 10 -file "$report_dir/qor_assessment.rpt"
report_clock_interaction -file "$report_dir/clock_interaction.rpt"
report_cdc -details -show_waiver -file "$report_dir/cdc.rpt"
check_timing -verbose -file "$report_dir/check_timing.rpt"
report_clocks -file "$report_dir/clocks.rpt"
report_clock_networks -file "$report_dir/clock_networks.rpt"
report_power -advisory -hier all -hierarchical_depth 4 -file "$report_dir/power.rpt"

set worst_setup_path [require_objects [get_timing_paths -max_paths 1 -setup] "worst setup timing path"]
show_schematic -name "Worst Setup Critical Path" $worst_setup_path
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Worst Setup Critical Path" "$visual_dir/worst_setup_critical_path.svg"

write_checkpoint -force "$checkpoint_dir/fpga_top_arty_a7_uart_routed.dcp"
write_metadata "$provenance_dir/build_metadata.txt" "post-route"

set summary_fp [open "$provenance_dir/build_result.txt" w]
set worst_setup [get_timing_paths -max_paths 1 -setup]
set worst_hold [get_timing_paths -delay_type min -max_paths 1]
puts $summary_fp "design=[current_design]"
puts $summary_fp "part=[get_property PART [current_design]]"
puts $summary_fp "setup_wns_ns=[get_property SLACK $worst_setup]"
puts $summary_fp "hold_whs_ns=[get_property SLACK $worst_hold]"
puts $summary_fp "drc_violation_count=[llength [get_drc_violations]]"
puts $summary_fp "unrouted_net_count=[llength [get_nets -hierarchical -filter {ROUTE_STATUS == UNROUTED}]]"
puts $summary_fp "checkpoint=$checkpoint_dir/fpga_top_arty_a7_uart_routed.dcp"
close $summary_fp

puts "ENGINEERING_EVIDENCE_BUILD_COMPLETE"
puts "ENGINEERING_EVIDENCE_PACKAGE=$package_dir"
exit
