# 竄改測試摘要

## 測試範圍

三份 frozen JSONL profile 都標記了三類 tamper records：`tamper aad`、`tamper ct` 與 `tamper tag`。每個 profile 每一輪各有 2 筆，每個 profile 的三類 tamper 合計 6 筆；這 6 筆 records 的 `expected_status` 均為 `AUTH_FAIL`。

## Frozen run 統計

| profile | run | AAD tamper records | ciphertext tamper records | tag tamper records | JSONL `AUTH_FAIL` records | summary tamper rejection pass |
|---|---:|---:|---:|---:|---:|---:|
| control_command | run1 | 2 | 2 | 2 | 6 | 6 |
| control_command | run2 | 2 | 2 | 2 | 6 | 6 |
| uav_telemetry | run1 | 2 | 2 | 2 | 6 | 6 |
| uav_telemetry | run2 | 2 | 2 | 2 | 6 | 6 |
| video_microchunk | run1 | 2 | 2 | 2 | 6 | 6 |
| video_microchunk | run2 | 2 | 2 | 2 | 6 | 6 |

六個 frozen summary rows 合計記錄 36 筆 tamper rejection pass，且 `board_failures` 合計為 0。

## 三類 tamper 的證據解讀

### AAD tamper

JSONL 以 `notes=tamper aad` 標記 2 筆案例，代表案例分類是針對 AAD 欄位的竄改情境。其預期狀態為 `AUTH_FAIL`，summary 則記錄每個 profile/run 有 6 筆 tamper rejection pass。

### Ciphertext tamper

JSONL 以 `notes=tamper ct` 標記 2 筆案例，代表案例分類是針對 ciphertext 的竄改情境。其預期狀態為 `AUTH_FAIL`。

### Tag tamper

JSONL 以 `notes=tamper tag` 標記 2 筆案例，代表案例分類是針對 authentication tag 的竄改情境。其預期狀態為 `AUTH_FAIL`。

## 結論邊界

這些資料支持三種 tamper 類別的案例配置、`AUTH_FAIL` 預期狀態，以及 frozen summary 所記錄的 tamper rejection pass。輸入資料沒有提供完整的 plaintext release ordering 證據，因此本摘要不宣稱 authentication PASS 後才 release plaintext，也不宣稱 authentication FAIL 時的內部 buffer 行為。

## 來源

- `artifacts/regression/profile_thesis_summary.csv`
- `artifacts/regression/profile_thesis_summary.md`
- `txt/profiles/uav_telemetry_profile.jsonl`
- `txt/profiles/control_command_profile.jsonl`
- `txt/profiles/video_microchunk_profile.jsonl`
