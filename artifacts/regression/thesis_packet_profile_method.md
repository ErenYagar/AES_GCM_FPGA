## Packet Profile 驗證方法

本研究於板級驗證階段未直接宣稱與既有 TLS、IPsec 或 SRTP 線路格式完全相容，而是借鏡其常見之封包保護概念，建立具代表性之 packet profiles，以驗證 AES-GCM 核心在實際封包保護情境下之可用性與穩定性 [REF_TLS13] [REF_IPSEC_GCM] [REF_SRTP_GCM]。所有 profiles 均固定使用 256-bit 金鑰，並於單一 profile run 中維持同一 session key，不在板級驗證過程中任意切換金鑰，以便聚焦於封包格式、AAD、IV 與資料竄改拒絕行為之觀察。

### IV 設計

本研究採用 96-bit 唯一 IV，格式定義為 `salt32 + counter64`。其中，前 32 位元作為 profile 級別之固定 salt，後 64 位元則作為遞增封包計數器。此設計符合 AES-GCM 對唯一 nonce/IV 之基本要求，亦便於模擬具序列性之封包傳輸情境 [REF_NIST_GCM]。

### AAD 設計

AAD 採用 header-style metadata 形式，以固定寬度、big-endian 二進位打包方式組成，用於承載不需加密但必須受完整性保護之欄位資訊。其目的在於模擬實際封包系統中，封包型別、序號、時間戳記、串流識別、負載長度等控制資訊受認證保護之需求。

### PT 設計

明文負載（PT）之設計以 protocol-inspired payloads 為原則，選用多組固定長度 payload，以模擬不同資料型態之封包內容。各 profile 之 payload 長度均受目前板級 UART wrapper 之資料長度限制約束，但仍足以涵蓋短控制封包、中小型遙測封包與較長之微型影像片段封包。

### 三種 Packet Profiles

1. **UAV telemetry**
   - AAD 為 16 bytes，欄位為：`msg_type(1), stream_id(1), reserved(2), seq(4), timestamp(4), payload_len(4)`。
   - PT 長度採用 16、24、32 bytes，用以模擬無人載具遙測資訊之不同封包尺寸。

2. **control command**
   - AAD 為 16 bytes，欄位為：`cmd_type(1), target_id(1), flags(2), seq(4), timestamp(4), payload_len(4)`。
   - PT 長度採用 8、16 bytes，用以模擬控制指令類封包之精簡負載。

3. **video micro-chunk**
   - AAD 為 16 bytes，欄位為：`frame_id(4), chunk_id(2), stream_id(2), timestamp(4), payload_len(4)`。
   - PT 長度採用 32、40、48 bytes，用以模擬影像微分塊（micro-chunk）資料之片段化傳輸。

### 測試案例配置

每一個 profile 共包含 30 筆測試案例，配置如下：

- 12 筆正常 encrypt 案例
- 12 筆正常 decrypt 案例
- 2 筆 AAD tamper 案例
- 2 筆 ciphertext tamper 案例
- 2 筆 tag tamper 案例

此配置使板級驗證不僅檢查 AES-GCM 正常加解密之正確性，亦同時驗證其對封包控制欄位與資料內容遭竄改時之拒絕能力，形成兼具實用性與可重現性之 thesis-grade 板級驗證流程。
