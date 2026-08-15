# 板級驗證總表

| profile | run | case count | normal pass | tamper rejection pass | board failures |
|---|---:|---:|---:|---:|---:|
| control_command | run1 | 30 | 24 | 6 | 0 |
| control_command | run2 | 30 | 24 | 6 | 0 |
| uav_telemetry | run1 | 30 | 24 | 6 | 0 |
| uav_telemetry | run2 | 30 | 24 | 6 | 0 |
| video_microchunk | run1 | 30 | 24 | 6 | 0 |
| video_microchunk | run2 | 30 | 24 | 6 | 0 |
| **All profiles** | **aggregate** | **180** | **144** | **36** | **0** |

> `run1` 與 `run2` 是 frozen summary 中的 run labels。Aggregate row 為六個 summary rows 的算術合計，不代表另一個獨立的硬體 run。

## 來源

- `artifacts/regression/profile_thesis_summary.csv`
- `artifacts/regression/profile_thesis_summary.md`
