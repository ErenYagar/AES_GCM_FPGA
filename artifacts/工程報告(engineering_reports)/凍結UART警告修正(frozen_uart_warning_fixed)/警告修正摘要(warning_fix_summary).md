# Frozen UART Warning 修正摘要

## 已完成的修正

本次只修改 `arty_a7_100t_uart.xdc`，未改變 RTL、AES-GCM 介面、UART baud rate、100 MHz 系統時脈或 25 MHz 核心時脈。

1. 移除在 `u_core_clk_buf/O` 重新建立 primary clock 的 `create_clock`。
2. 改由 Vivado 根據 MMCM 自動推導 `core_clk_mmcm`，period 為 40.000 ns。
3. 將非同步 reset button、UART RX、UART TX 與 LED 明確標示為 false-path I/O，避免加入無依據的 input/output delay 數值。

## 修正後結果

| 項目 | 修正前 | 修正後 |
|---|---:|---:|
| Methodology violations | 9 | 0 |
| `TIMING-2` | 1 Critical Warning | 0 |
| `TIMING-4` | 1 Critical Warning | 0 |
| `TIMING-18` | 7 Warnings | 0 |
| WNS / TNS | 7.376 ns / 0 ns | 7.376 ns / 0 ns |
| WHS / THS | 0.016 ns / 0 ns | 0.016 ns / 0 ns |
| Routing errors | 0 | 0 |
| DRC violations | 0 | 0 |
| LUT / FF / BRAM | 26,716 / 21,970 / 52.5 | 不變 |

證據：

- [Methodology report](報告(reports)/methodology.rpt)
- [Check timing](報告(reports)/check_timing.rpt)
- [Timing summary](報告(reports)/timing_summary.rpt)
- [Route status](報告(reports)/route_status.rpt)
- [DRC](報告(reports)/drc.rpt)
- [Routed checkpoint](檢查點(checkpoint)/fpga_top_arty_a7_uart_warning_fixed_routed.dcp)

## 不能誤稱為已修正的項目

更正 clock 定義後，Vivado CDC 能看見先前被錯誤 clock redefinition 遮蔽的非同步 reset 路徑。修正後的 [CDC report](報告(reports)/cdc.rpt) 列出：

| CDC ID | Severity | Count | 主要來源 |
|---|---|---:|---|
| `CDC-1` | Critical | 23,240 | `rst_btn` 到大量 reset/control pins |
| `CDC-2` | Warning | 11 | 10 個 reset path，加上 UART RX synchronizer 缺少 `ASYNC_REG` |
| `CDC-13` | Critical | 636 | `rst_btn` 到 BRAM 等 non-FD primitive control pins |

這些 CDC 項目不能只靠 waiver 或任意 timing 數值當作已修復。安全的下一步需要修改 RTL：

1. 為 100 MHz 與 25 MHz clock domain 建立 asynchronous-assert、synchronous-deassert reset synchronizer。
2. 為 `uart_rx` 的 `rx_meta`、`rx_sync` registers 加入 `ASYNC_REG` 屬性，並只對輸入到第一級 synchronizer 的路徑設定 exception。
3. 重新執行 CDC、methodology、timing、routing 與 DRC。

另外，Vivado synthesis 仍提示 MMCM 的 `CLKFBOUTB` 未列在 instance connection list；消除此提示需要在 RTL instance 中加入明確的 `.CLKFBOUTB()` 空接腳。這是無功能變更的 RTL 清理，但不在本次 XDC-only 修正範圍內。

Power report 仍有 `Power 33-332`，原因是 vectorless estimate 推測部分高 fanout reset 長時間 asserted。這只能透過可信的 SAIF/simulation activity 或板端量測改善，不能用假 switching activity 消除。

## 判讀

原本的 9 個 timing/methodology warnings 已歸零，且實作結果仍通過 timing、routing 與 DRC。但目前不能宣稱「全部 warning 已修好」或「CDC signoff 已完成」，因為 reset synchronizer 仍需要 RTL 層修正。
