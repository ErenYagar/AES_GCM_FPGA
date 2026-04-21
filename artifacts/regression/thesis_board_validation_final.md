## 板級驗證目的與結果

本研究之板級驗證目標，在於確認 AES-GCM 設計不僅於 RTL 與核心層級具備正確性，亦能在 Arty A7-100T 平台上，透過既有 UART 主機介面穩定完成實際封包型態之加解密與完整性驗證。基於此目的，驗證流程區分為兩個層次：其一為使用 NIST 官方 `.rsp` 測資進行 RTL/core-only correctness 驗證，以確認演算法實作與已知標準向量一致 [REF_NIST_GCM]；其二為建立具協定靈感之 packet profiles，作為板級實務驗證案例，以評估系統在實際封包長度、標頭型 AAD、唯一 IV 與竄改拒絕情境下之整體行為。

採用 packet profiles 進行板級驗證之理由，在於 NIST `.rsp` 著重演算法正確性與標準測資覆蓋，適合用於 RTL 與核心層級比對；然而，論文所需之板級驗證尚須證明設計能在實際主機傳輸、封包封裝與板上 I/O 互動條件下穩定運作。因此，本研究以 TLS/IPsec/SRTP 常見之封包保護概念作為設計靈感，建立具固定長度標頭欄位、96-bit 唯一 IV 與不同 payload 大小之封包型態，但不主張與既有通訊協定線路格式完全相容 [REF_TLS13] [REF_IPSEC_GCM] [REF_SRTP_GCM]。

在凍結之板級驗證結果中，三組 packet profiles 皆完成完整測試，且無板級失敗。`control_command` profile 共 30 筆案例，其中 24 筆正常案例全部通過，6 筆竄改拒絕案例全部通過，板級失敗數為 0。`uav_telemetry` profile 共 30 筆案例，其中 24 筆正常案例全部通過，6 筆竄改拒絕案例全部通過，板級失敗數為 0。`video_microchunk` profile 共 30 筆案例，其中 24 筆正常案例全部通過，6 筆竄改拒絕案例全部通過，板級失敗數為 0。上述結果已彙整於凍結之 thesis summary artifacts 中，可直接作為論文驗證章節之定稿依據。

此外，為排除偶然性與單次燒錄成功所造成之誤判，本研究另完成兩輪 fresh reprogram 驗證循環；每一輪皆以重新燒錄目前既有 bitstream 作為 fresh state 起點，並重新執行完整 packet-profile 板級驗證。兩輪 fresh reprogram cycles 均成功完成，且三組 profiles 皆維持 `24 normal pass + 6 tamper reject pass + 0 board failures` 之相同結果。此結果顯示本研究所提出之 packet-profile 板級驗證流程已具備可重現性，足以作為論文中板上實作驗證之最終證據。

## 板級驗證總表

| profile | total cases | normal pass | tamper rejection pass | board failures | reproducibility status |
|---|---:|---:|---:|---:|---|
| control_command | 30 | 24 | 6 | 0 | 兩輪 fresh reprogram 均全數通過 |
| uav_telemetry | 30 | 24 | 6 | 0 | 兩輪 fresh reprogram 均全數通過 |
| video_microchunk | 30 | 24 | 6 | 0 | 兩輪 fresh reprogram 均全數通過 |

> 註：reproducibility status 係指在重新燒錄既有 bitstream 之 fresh 狀態下，重複完成完整 profile 驗證後，仍得到一致之板級結果。

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

## 竄改測試摘要

本研究於每一個 packet profile 中皆納入三類竄改測試，分別為 AAD tamper、ciphertext tamper 與 tag tamper。其目的在於驗證 AES-GCM 不僅能提供資料保密性，亦能在板級實作中正確執行完整性驗證與認證失敗拒絕機制 [REF_NIST_GCM]。

### AAD Tamper Rejection

AAD tamper 測試模擬封包標頭或控制欄位遭修改之情境，例如序號、時間戳記、命令類型或 payload 長度資訊被竄改。由於 AAD 雖不加密，但必須納入 GCM 驗證流程，因此只要 AAD 內容與原始產生 tag 時所用資料不一致，解密端即應回報認證失敗，而不得接受該封包。此測試對實務系統特別重要，因為許多控制性欄位直接決定封包語意與處理流程。

### Ciphertext Tamper Rejection

ciphertext tamper 測試模擬傳輸中之密文位元遭竄改，或封包內容在儲存/傳輸過程中被惡意修改。若 AES-GCM 實作正確，解密流程不應僅輸出錯誤明文，而必須先以認證機制偵測異常並拒絕該封包。此結果確保接收端不會誤接受被竄改之資料內容。

### Tag Tamper Rejection

tag tamper 測試則直接針對認證標記（authentication tag）進行修改，模擬攻擊者企圖偽造合法封包之情境。由於 tag 為 AES-GCM 完整性與認證機制之核心輸出，只要 tag 與加解密上下文不一致，接收端即應回報認證失敗。此測試可直接驗證板級系統對偽造封包的拒絕能力。

### 實務意義

上述三類竄改測試之意義，在於將 AES-GCM 由「演算法正確」提升到「系統實作可用」之層次。若僅驗證正常 encrypt/decrypt 案例，僅能說明核心於理想資料流下之正確性；加入 AAD、ciphertext 與 tag 三類竄改拒絕測試後，方能證明系統於實際封包傳輸情境中，確實具備資料保密、標頭認證與完整性保護之能力。此亦為本研究採用 packet-profile board validation 作為論文最終板級驗證方法之主要原因。
