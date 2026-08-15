# Packet Profile 驗證方法

## 資料範圍

本方法文件只描述三份 frozen JSONL profile records 的實際欄位與案例配置。這些 profile 是用來組織封包型驗證案例的資料集合；本文件不宣稱其與任何外部通訊協定線路格式相容。

## 共通 record 參數

| 欄位 | frozen records 中的觀察值 |
|---|---:|
| `key` | 每個 profile 都只有 1 個 unique key，長度為 256 bits |
| `iv` | 每筆 record 為 96 bits |
| `aad` | 每筆 record 為 16 bytes |
| `tag_bits` | 每筆 record 為 128 bits |
| 每個 profile 的 records | 30 |

`mode`、`notes`、`expected_status`、`pt`、`ct_input` 與 `tag_input` 用來區分 encrypt、normal decrypt 與 tamper records。驗證結果中的 pass/fail 統計以 frozen summary 為準；JSONL 的 `expected_status` 用於描述案例預期狀態。

## Profile 欄位與 payload 配置

### `uav_telemetry`

`aad_fields` 提供下列固定寬度欄位，合計 16 bytes：

`msg_type(1) + stream_id(1) + reserved(2) + seq(4) + timestamp(4) + payload_len(4)`

frozen records 的 payload lengths 為 16、24、32 bytes。案例配置為 12 筆 normal encrypt、12 筆 normal decrypt、2 筆 `tamper aad`、2 筆 `tamper ct` 與 2 筆 `tamper tag`。

### `control_command`

`aad_fields` 提供下列固定寬度欄位，合計 16 bytes：

`cmd_type(1) + target_id(1) + flags(2) + seq(4) + timestamp(4) + payload_len(4)`

frozen records 的 payload lengths 為 8、16 bytes。案例配置為 12 筆 normal encrypt、12 筆 normal decrypt、2 筆 `tamper aad`、2 筆 `tamper ct` 與 2 筆 `tamper tag`。

### `video_microchunk`

`aad_fields` 提供下列固定寬度欄位，合計 16 bytes：

`frame_id(4) + chunk_id(2) + stream_id(2) + timestamp(4) + payload_len(4)`

frozen records 的 payload lengths 為 32、40、48 bytes。案例配置為 12 筆 normal encrypt、12 筆 normal decrypt、2 筆 `tamper aad`、2 筆 `tamper ct` 與 2 筆 `tamper tag`。

## 案例配置與狀態

每個 profile 的 JSONL 狀態分布均為：

| `expected_status` | Count | 對應案例 |
|---|---:|---|
| `ENC_OK` | 12 | normal encrypt |
| `DEC_OK` | 12 | normal decrypt |
| `AUTH_FAIL` | 6 | 三類 tamper，各 2 筆 |

因此，正常案例合計為 24 筆，tamper 案例合計為 6 筆。這個 JSONL 組成與 summary 中每個 run 的 `normal_pass=24`、`tamper_reject_pass=6` 對應，但不取代 summary 對板級結果的定義。

## 方法邊界

本文件只說明 frozen records 中可直接觀察的 key、IV、AAD、payload、tag、mode、notes 與 expected status。它不推論 nonce 產生策略、外部協定相容性、硬體 timing、plaintext release ordering 或未出現在輸入檔案中的介面行為。

## 來源

- `txt/profiles/uav_telemetry_profile.jsonl`
- `txt/profiles/control_command_profile.jsonl`
- `txt/profiles/video_microchunk_profile.jsonl`
- `artifacts/regression/profile_thesis_summary.csv`
