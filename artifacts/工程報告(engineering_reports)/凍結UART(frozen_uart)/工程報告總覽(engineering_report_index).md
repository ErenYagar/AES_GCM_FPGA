# Frozen UART Vivado 工程證據包總覽

> 後續狀態：本證據包完成後，`arty_a7_100t_uart.xdc` 已進行 clock 與 I/O exception 修正。此處的 DCP、報告與 SHA-256 仍保留修正前 Frozen UART 重建狀態；修正後結果見[警告修正摘要](../凍結UART警告修正(frozen_uart_warning_fixed)/警告修正摘要(warning_fix_summary).md)。

## 結論

本證據包以 Vivado 2021.1 對 Frozen UART 追蹤來源進行純軟體重建，設計 `fpga_top_arty_a7_uart`、元件 `xc7a100tcsg324-1`、系統時脈 100 MHz、核心時脈 25 MHz。重建結果已完成 routing，setup/hold timing 均通過，DRC 與 routing error 均為 0。

本次結果代表「與 Frozen UART 相同追蹤來源的重建」，不宣稱與既有正式 `.bit` 二進位完全相同；本證據包未產生 bitstream、未開啟 Hardware Manager、未連接或燒錄開發板，也不是新的板端驗證。

來源 Git commit 為 `ef6d1b8fa36911e2ec1582eb07a68538c495cd44`。追蹤中的 RTL/XDC 內容與 Frozen UART 基準 commit `ef6d1b8f` 相同，個別 SHA-256 見[來源清單](來源與紀錄(provenance)/source_manifest.sha256)。

## Signoff 摘要

| 類別 | Routed 結果 | 判讀 |
|---|---:|---|
| WNS / TNS | 7.376 ns / 0.000 ns | Setup 通過，0 failing endpoints |
| WHS / THS | 0.016 ns / 0.000 ns | Hold 通過，0 failing endpoints |
| Pulse width | WPWS 3.000 ns、TPWS 0.000 ns | 0 failing endpoints |
| Routing | 42,484 / 42,484 routable nets fully routed | 0 routing errors |
| DRC | 0 violations | Fully Routed |
| Slice LUT | 26,716 / 63,400（42.14%） | 與 frozen 報告相同 |
| Slice registers | 21,970 / 126,800（17.33%） | 與 frozen 報告相同 |
| Block RAM tile | 52.5 / 135（38.89%） | 105 個 RAMB18 |
| DSP | 0 / 240（0%） | 未使用 DSP |
| QoR assessment | Score 5 | Vivado 判定設計會通過 timing；仍要求處理或 waiver methodology critical warnings |
| Congestion | 無 level 3 以上 congestion window | placer 與 initial router estimate 皆未偵測到 |
| Power estimate | 0.296 W | 0.195 W dynamic、0.101 W static；Medium confidence vectorless estimate，非板端實測 |

完整 timing 證據見 [timing_summary.rpt](報告(reports)/timing_summary.rpt)，資源見 [utilization.rpt](報告(reports)/utilization.rpt)，routing 與 DRC 分別見 [route_status.rpt](報告(reports)/route_status.rpt) 與 [drc.rpt](報告(reports)/drc.rpt)。

## Clock、CDC 與 constraints

Routed checkpoint 重新開啟後確認主要 clock 為：

| Clock | Period | Frequency |
|---|---:|---:|
| `sys_clk_pin` | 10.000 ns | 100 MHz |
| `core_clk` | 40.000 ns | 25 MHz |

[clock_interaction.rpt](報告(reports)/clock_interaction.rpt) 顯示 `core_clk → core_clk` 與 `sys_clk_pin → sys_clk_pin` 都是 Clean/Timed，沒有 failing endpoints；[cdc.rpt](報告(reports)/cdc.rpt) 回報 `All paths are Safely Timed.`。這只代表 Vivado 在目前 constraints 下辨識並分析到的路徑，不能用來取代缺少的外部 I/O timing constraints。

[check_timing.rpt](報告(reports)/check_timing.rpt) 仍列出 2 個缺少 input delay 的輸入（`rst_btn`、`uart_txd_in`）與 5 個缺少 output delay 的輸出（`led[3:0]`、`uart_rxd_out`）。[methodology.rpt](報告(reports)/methodology.rpt) 共 9 項：

- `TIMING-2` Critical Warning ×1：Invalid primary clock source pin。
- `TIMING-4` Critical Warning ×1：Invalid primary clock redefinition on a clock tree。
- `TIMING-18` Warning ×7：Missing input or output delay。

這些警告未被修改或隱藏；因此本結果可證明目前約束下的內部 timing closure，但不能宣稱外部 UART/LED 介面的完整板級 I/O timing signoff。

## Power 與 QoR 邊界

[power.rpt](報告(reports)/power.rpt) 是 routed design 的 vectorless estimate，未載入 simulation activity file，overall confidence 為 Medium。報告指出部分 I/O activity 未指定、內部節點 user-specified activity 低於 25%；Advisory 也把部分 high-fanout reset/set 網路標成 Low confidence，例如 fanout 9,339 與 4,272 的網路。這些 switching activity 必須先用模擬或量測校正，因此 0.296 W 應作為設計估算值，不是量測值。

[qor_assessment.rpt](報告(reports)/qor_assessment.rpt) 的 utilization、clocking、congestion 與 timing 狀態皆為 OK，QoR score 為 5；同一報告也保留上述 methodology warnings，且 Vivado 2021.1 不對 7-series 提供 ML strategy。

## Frozen 報告對照

本次新 routed 結果與既有 frozen 報告逐項交叉比對：

| 指標 | Frozen | 本次重建 | 結果 |
|---|---:|---:|---|
| WNS / WHS | 7.376 / 0.016 ns | 7.376 / 0.016 ns | 相同 |
| TNS / THS | 0.000 / 0.000 ns | 0.000 / 0.000 ns | 相同 |
| LUT / FF | 26,716 / 21,970 | 26,716 / 21,970 | 相同 |
| BRAM tile / DSP | 52.5 / 0 | 52.5 / 0 | 相同 |
| DRC | 0 violations | 0 violations | 相同 |

對照來源為既有 `artifacts/fpga_top_arty_a7_uart_fixed_timing.rpt`、`artifacts/fpga_top_arty_a7_uart_fixed_util.rpt` 與 `artifacts/fpga_top_arty_a7_uart_fixed_drc.rpt`；本次沒有覆寫這三份 frozen 報告。

## 報告索引

### Timing 與 critical paths

- [Timing Summary](報告(reports)/timing_summary.rpt)
- [Setup Top-10 critical paths](報告(reports)/critical_paths_setup_top10.rpt)
- [Hold Top-10 critical paths](報告(reports)/critical_paths_hold_top10.rpt)
- [Design Analysis — setup](報告(reports)/design_analysis_timing_setup.rpt)
- [Design Analysis — hold](報告(reports)/design_analysis_timing_hold.rpt)
- [Clock definitions](報告(reports)/clocks.rpt)
- [Clock networks](報告(reports)/clock_networks.rpt)
- [Clock interaction](報告(reports)/clock_interaction.rpt)
- [Check timing](報告(reports)/check_timing.rpt)

### Utilization、routing 與 design analysis

- [Flat utilization](報告(reports)/utilization.rpt)
- [Hierarchical utilization](報告(reports)/utilization_hierarchical.rpt)
- [Route status](報告(reports)/route_status.rpt)
- [DRC](報告(reports)/drc.rpt)
- [Methodology](報告(reports)/methodology.rpt)
- [Complexity](報告(reports)/design_analysis_complexity.rpt)
- [Congestion](報告(reports)/design_analysis_congestion.rpt)
- [Logic-level distribution](報告(reports)/design_analysis_logic_levels.rpt)
- [QoR summary](報告(reports)/design_analysis_qor_summary.rpt)
- [QoR assessment](報告(reports)/qor_assessment.rpt)
- [CDC](報告(reports)/cdc.rpt)
- [Routed power estimate](報告(reports)/power.rpt)

## 圖像索引

Vivado GUI 的 `write_schematic` 產生下列 SVG：

- [Elaborated RTL top](圖像(visuals)/elaborated_rtl_top.svg)
- [Elaborated AES-GCM core](圖像(visuals)/elaborated_aes_gcm_core.svg)
- [Synthesized top netlist](圖像(visuals)/synthesized_top_netlist.svg)
- [Synthesized crypto datapath](圖像(visuals)/synthesized_crypto_datapath.svg)
- [Worst setup critical-path schematic（post-route）](圖像(visuals)/worst_setup_critical_path.svg)

兩張 physical PNG 由同一份 routed DCP 的 Vivado physical database 匯出資料重繪，而不是桌面截圖；它們保留 LOC/BEL/tile、routed node 與 worst setup path 的可追溯性：

- [Implemented device placement](圖像(visuals)/implemented_device_placement.png)
- [Worst setup path routing resources](圖像(visuals)/worst_setup_path_routing_resources.png)

Vivado 匯出的原始物理資料位於[來源與紀錄](來源與紀錄(provenance)/)：`placement_data.csv`、`worst_setup_route_data.csv`、`worst_setup_path_cells.csv` 與 `physical_visual_metadata.txt`。這項呈現方式不等同於 Vivado Device Window 的直接 GUI screenshot。

## Checkpoint 與重現資料

- [Routed DCP](檢查點(checkpoint)/fpga_top_arty_a7_uart_routed.dcp)
- [Build Tcl](來源與紀錄(provenance)/build_engineering_evidence.tcl)
- [GUI schematic export Tcl](來源與紀錄(provenance)/generate_visuals_gui.tcl)
- [Physical data export Tcl](來源與紀錄(provenance)/export_physical_visual_data.tcl)
- [Physical PNG renderer](來源與紀錄(provenance)/render_physical_visuals.py)
- [Checkpoint independent reopen result](來源與紀錄(provenance)/checkpoint_validation.txt)
- [Package validation result](來源與紀錄(provenance)/validation_summary.txt)
- [Source SHA-256 manifest](來源與紀錄(provenance)/source_manifest.sha256)

獨立重開 DCP 已再次查得 part `xc7a100tcsg324-1`、WNS 7.376 ns、WHS 0.016 ns、0 DRC violations、0 unrouted nets。整個證據包已通過 116 項自動檢查，且沒有新增 `.bit`、`.bin` 或 `.ltx`。
