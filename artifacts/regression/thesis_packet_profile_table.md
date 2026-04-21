## Packet Profile 摘要表

| Profile | Real-world scenario | AAD meaning | PT meaning | Validation purpose |
|---|---|---|---|---|
| `control_command` | 模擬短控制命令封包，例如設備控制、參數設定、模式切換與遠端命令 | `cmd_type`、`target_id`、`flags`、`seq`、`timestamp`、`payload_len`，代表命令種類、作用對象、控制旗標、序號、時間資訊與負載長度 | 短控制參數或命令內容，代表實際需保密之控制資料 | 驗證 AES-GCM-256 對短封包控制資料之保護能力，並確認標頭欄位、密文與 tag 遭竄改時可正確拒絕 |
| `uav_telemetry` | 模擬無人機或感測節點之週期性遙測封包 | `msg_type`、`stream_id`、`reserved`、`seq`、`timestamp`、`payload_len`，代表資料種類、來源串流、保留欄位、序號、時間戳與負載長度 | 姿態、狀態、感測資訊等遙測內容，對應中等長度資料回報 | 驗證中等 payload、時間序列欄位與連續回傳情境下之板級加解密與完整性保護 |
| `video_microchunk` | 模擬片段化視訊串流之微分塊封包 | `frame_id`、`chunk_id`、`stream_id`、`timestamp`、`payload_len`，代表影像幀編號、分塊編號、串流來源、時間資訊與分塊長度 | 微型視訊資料塊，對應較長且具連續性的串流 payload | 驗證較大 payload 與 chunk 化資料流之處理能力，並觀察串流片段在 AAD 認證與 tamper rejection 下之板級行為 |
