## Packet Profiles 之設計目的

本研究之板級驗證除使用 NIST 官方 `.rsp` 測資確認 AES-GCM-256 核心於 RTL/core-only 層級之正確性外，亦額外建立 `control_command`、`uav_telemetry` 與 `video_microchunk` 三組 packet profiles，作為板級 practical validation 之測試資料。此三組 profiles 並非官方 NIST `.rsp` 檔案，亦非 TLS、IPsec 或 SRTP 之精確線路封包格式，而是借鏡實務通訊系統中常見之封包保護概念所設計的 protocol-inspired validation packets。其目的在於模擬 FPGA 系統於實際封包型態、標頭型 AAD、不同 payload 長度，以及正常解密與竄改拒絕情境下之整體行為。

### control_command

`control_command` profile 用以模擬短控制命令封包，例如無人載具控制指令、設備參數設定、模式切換或遠端控制訊息。在此類應用中，payload 通常較短，但封包語意高度敏感，若封包遭竄改，可能直接影響系統控制結果。因此，除資料保密外，標頭欄位與認證結果之正確性更為重要。

在 AAD 設計上，`control_command` 採用 16-byte header-style metadata，欄位包含 `cmd_type`、`target_id`、`flags`、`seq`、`timestamp` 與 `payload_len`。其中，`cmd_type` 用以區分命令種類，`target_id` 用以標示命令作用對象，`flags` 可承載控制狀態或命令屬性，`seq` 與 `timestamp` 用以描述命令次序與時序資訊，`payload_len` 則指出明文負載長度。這些欄位本身不加密，但必須納入 AES-GCM 認證保護，以避免控制語意被攻擊者竄改。

其 PT（plaintext）代表實際欲保護之控制命令內容或參數資料，包含較短之 8-byte 與 16-byte payload。此類設計可對應控制數值、執行參數、狀態切換資料或小型命令負載。由於 `control_command` 同時涵蓋正常 encrypt/decrypt 與 AAD、ciphertext、tag 三類 tamper rejection 測試，因此可驗證本研究架構不僅能保護短封包之機密性，也能在板級實作中正確拒絕遭竄改之控制封包。

### uav_telemetry

`uav_telemetry` profile 用以模擬無人機或感測節點定期回傳之遙測封包，例如姿態、速度、高度、電量、感測器狀態或系統健康資訊。此類封包通常具有週期性、順序性與時間關聯性，因此除 payload 本身外，封包型別、串流來源、序號與時間戳記亦需受到完整性保護。

在 AAD 設計上，`uav_telemetry` 同樣採用 16-byte 固定長度 header-style metadata，欄位包含 `msg_type`、`stream_id`、`reserved`、`seq`、`timestamp` 與 `payload_len`。其中，`msg_type` 表示遙測訊息種類，`stream_id` 用以區分資料來源或資料流，`reserved` 保留後續擴充使用，`seq` 與 `timestamp` 反映封包之順序與時間序列資訊，`payload_len` 則描述本筆遙測內容長度。

其 PT 代表實際遙測資料內容，payload 長度分布為 16、24 與 32 bytes，用以模擬不同資訊量之狀態回報封包。此類 profile 的重要性，在於其比短控制命令更接近持續資料回傳場景，可驗證 AES-GCM-256 於中等長度 payload、時間序列欄位保護，以及多筆連續封包處理下之板級運作穩定性。同時，透過 tamper rejection 案例，也能驗證系統是否能正確拒絕標頭欄位、密文內容或認證標籤遭修改之遙測封包。

### video_microchunk

`video_microchunk` profile 用以模擬將串流資料切分後之微型視訊片段封包。實務上，連續影音資料通常需切分為 frame/chunk 型態的小區塊傳輸，以降低單次傳輸延遲並提高封包處理彈性。本研究以 `video_microchunk` 作為較大 payload 類型之代表，用以觀察 AES-GCM-256 在串流片段化資料上的板級行為。

在 AAD 設計上，`video_microchunk` 之 16-byte metadata 由 `frame_id`、`chunk_id`、`stream_id`、`timestamp` 與 `payload_len` 組成。其中，`frame_id` 用於標示所屬影像幀，`chunk_id` 表示該幀內之分塊編號，`stream_id` 用以描述串流來源，`timestamp` 提供時間資訊，`payload_len` 則標明片段負載長度。此類欄位若遭竄改，可能導致資料重組錯誤或串流順序失真，因此必須由 AES-GCM 的 AAD 認證機制保護。

其 PT 代表微型視訊分塊之實際內容，payload 長度分布為 32、40 與 48 bytes，以模擬較大負載且具連續性之片段資料。此 profile 對板級驗證的重要性，在於其能補足短控制封包與中等遙測封包之外的測試範圍，驗證系統對較長 payload、chunk 化資料流與 frame/chunk 關聯欄位的處理能力。透過正常案例與竄改拒絕案例並行驗證，可進一步說明本研究之 AES-GCM-256 FPGA 實作不僅具備標準向量正確性，也具備面向實際資料流封裝情境之實用驗證價值。
