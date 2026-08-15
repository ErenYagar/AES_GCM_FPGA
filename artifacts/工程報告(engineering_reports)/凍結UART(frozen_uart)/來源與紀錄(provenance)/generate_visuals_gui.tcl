set root_dir "C:/project/FPGA2"
set package_dir "$root_dir/artifacts/\u5de5\u7a0b\u5831\u544a(engineering_reports)/\u51cd\u7d50UART(frozen_uart)"
set checkpoint "$package_dir/\u6aa2\u67e5\u9ede(checkpoint)/fpga_top_arty_a7_uart_routed.dcp"
set staging_dir "$root_dir/.Xil/frozen_uart_visuals"
file mkdir $staging_dir

set part_name "xc7a100tcsg324-1"
set top_name "fpga_top_arty_a7_uart"
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

proc require_objects {objects label} {
    if {[llength $objects] == 0} {
        error "No objects found for $label"
    }
    return $objects
}

# write_schematic requires the GUI. The staging path is ASCII because Vivado
# 2021.1 can mishandle non-ASCII export filenames on Windows.
create_project -in_memory -part $part_name
read_verilog $rtl_files
synth_design -rtl -name rtl_visuals -top $top_name -part $part_name

set rtl_top_cells [require_objects [get_cells -quiet *] "elaborated top-level cells"]
show_schematic -name "Elaborated RTL Top" $rtl_top_cells
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Elaborated RTL Top" "$staging_dir/elaborated_rtl_top.svg"

set rtl_core_cells [require_objects [get_cells -quiet -hierarchical {u_core u_core/u_iv_in u_core/u_aad_ct_in u_core/u_hcalc u_core/u_data_ctr u_core/u_tag_ctr u_core/u_ghash}] "elaborated AES-GCM core cells"]
show_schematic -name "Elaborated AES-GCM Core" $rtl_core_cells
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Elaborated AES-GCM Core" "$staging_dir/elaborated_aes_gcm_core.svg"

close_design
close_project

create_project -in_memory -part $part_name
read_verilog $rtl_files
synth_design -top $top_name -part $part_name

set synth_top_cells [require_objects [get_cells -quiet *] "synthesized top-level cells"]
show_schematic -name "Synthesized Top Netlist" $synth_top_cells
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Synthesized Top Netlist" "$staging_dir/synthesized_top_netlist.svg"

set synth_crypto_cells [get_cells -quiet -hierarchical -filter {ORIG_REF_NAME =~ "top" || ORIG_REF_NAME =~ "AES_e" || ORIG_REF_NAME =~ "GHASH" || ORIG_REF_NAME =~ "aes_ctr_wrapper"}]
set synth_crypto_cells [require_objects $synth_crypto_cells "synthesized crypto datapath cells"]
show_schematic -name "Synthesized Crypto Datapath" $synth_crypto_cells
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Synthesized Crypto Datapath" "$staging_dir/synthesized_crypto_datapath.svg"

close_design
close_project

open_checkpoint $checkpoint
set worst_setup_path [require_objects [get_timing_paths -delay_type max -max_paths 1] "worst setup timing path"]
show_schematic -name "Worst Setup Critical Path (Post-Route)" $worst_setup_path
write_schematic -force -format svg -orientation landscape -scope all \
    -name "Worst Setup Critical Path (Post-Route)" "$staging_dir/worst_setup_critical_path.svg"

puts "GUI_VISUAL_EXPORT_COMPLETE"
puts "GUI_VISUAL_STAGING=$staging_dir"
