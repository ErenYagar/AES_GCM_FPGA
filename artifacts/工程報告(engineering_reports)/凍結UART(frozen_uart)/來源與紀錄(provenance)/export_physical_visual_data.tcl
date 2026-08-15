set root_dir "C:/project/FPGA2"
set package_dir "$root_dir/artifacts/\u5de5\u7a0b\u5831\u544a(engineering_reports)/\u51cd\u7d50UART(frozen_uart)"
set checkpoint "$package_dir/\u6aa2\u67e5\u9ede(checkpoint)/fpga_top_arty_a7_uart_routed.dcp"
set staging_dir "$root_dir/.Xil/frozen_uart_visuals"
file mkdir $staging_dir

proc csv_quote {value} {
    set escaped [string map [list "\"" "\"\""] $value]
    return "\"$escaped\""
}

proc csv_join {values} {
    set quoted [list]
    foreach value $values {
        lappend quoted [csv_quote $value]
    }
    return [join $quoted ","]
}

open_checkpoint $checkpoint

set placement_fp [open "$staging_dir/placement_data.csv" w]
puts $placement_fp "cell,primitive_type,loc,bel,tile,grid_x,grid_y,clock_region"
set placement_count 0
foreach cell [get_cells -quiet -hierarchical -filter {IS_PRIMITIVE}] {
    set loc [get_property LOC $cell]
    if {$loc eq ""} {
        continue
    }
    set tiles [get_tiles -quiet -of_objects [get_sites -quiet $loc]]
    set tile [lindex $tiles 0]
    set grid_x ""
    set grid_y ""
    if {$tile ne ""} {
        set grid_x [get_property GRID_POINT_X $tile]
        set grid_y [get_property GRID_POINT_Y $tile]
    }
    set clock_region [lindex [get_clock_regions -quiet -of_objects $cell] 0]
    set values [list $cell [get_property PRIMITIVE_TYPE $cell] $loc [get_property BEL $cell] $tile $grid_x $grid_y $clock_region]
    puts $placement_fp [csv_join $values]
    incr placement_count
}
close $placement_fp

set worst_path [get_timing_paths -delay_type max -max_paths 1]
set path_fp [open "$staging_dir/worst_setup_route_data.csv" w]
puts $path_fp "net,node_index,node,tile,grid_x,grid_y"
foreach net [get_nets -quiet -of_objects $worst_path] {
    set index 0
    foreach node [get_nodes -quiet -of_objects $net] {
        set tile [lindex [get_tiles -quiet -of_objects $node] 0]
        set grid_x ""
        set grid_y ""
        if {$tile ne ""} {
            set grid_x [get_property GRID_POINT_X $tile]
            set grid_y [get_property GRID_POINT_Y $tile]
        }
        set values [list $net $index $node $tile $grid_x $grid_y]
        puts $path_fp [csv_join $values]
        incr index
    }
}
close $path_fp

set path_cell_fp [open "$staging_dir/worst_setup_path_cells.csv" w]
puts $path_cell_fp "cell,loc,tile,grid_x,grid_y"
foreach cell [get_cells -quiet -of_objects $worst_path] {
    set loc [get_property LOC $cell]
    set tile [lindex [get_tiles -quiet -of_objects [get_sites -quiet $loc]] 0]
    set grid_x ""
    set grid_y ""
    if {$tile ne ""} {
        set grid_x [get_property GRID_POINT_X $tile]
        set grid_y [get_property GRID_POINT_Y $tile]
    }
    set values [list $cell $loc $tile $grid_x $grid_y]
    puts $path_cell_fp [csv_join $values]
}
close $path_cell_fp

set metadata_fp [open "$staging_dir/physical_visual_metadata.txt" w]
puts $metadata_fp "design=[current_design]"
puts $metadata_fp "part=[get_property PART [current_design]]"
puts $metadata_fp "vivado_version=[version -short]"
puts $metadata_fp "worst_setup_slack_ns=[get_property SLACK $worst_path]"
puts $metadata_fp "worst_setup_startpoint=[get_property STARTPOINT_PIN $worst_path]"
puts $metadata_fp "worst_setup_endpoint=[get_property ENDPOINT_PIN $worst_path]"
puts $metadata_fp "placement_cell_count=$placement_count"
puts $metadata_fp "path_net_count=[llength [get_nets -quiet -of_objects $worst_path]]"
puts $metadata_fp "path_cell_count=[llength [get_cells -quiet -of_objects $worst_path]]"
close $metadata_fp

puts "PHYSICAL_VISUAL_DATA_EXPORT_COMPLETE"
exit
