## 板級驗證結果與驗證目的

本研究之板級驗證目標，在於確認 AES-GCM 設計不僅於 RTL 與核心層級具備正確性，亦能在 Arty A7-100T 平台上，透過既有 UART 主機介面穩定完成實際封包型態之加解密與完整性驗證。基於此目的，驗證流程區分為兩個層次：其一為使用 NIST 官方 `.rsp` 測資進行 RTL/core-only correctness 驗證，以確認演算法實作與已知標準向量一致 [REF_NIST_GCM]；其二為建立具協定靈感之 packet profiles，作為板級實務驗證案例，以評估系統在實際封包長度、標頭型 AAD、唯一 IV 與竄改拒絕情境下之整體行為。

採用 packet profiles 進行板級驗證之理由，在於 NIST `.rsp` 著重演算法正確性與標準測資覆蓋，適合用於 RTL 與核心層級比對；然而，論文所需之板級驗證尚須證明設計能在實際主機傳輸、封包封裝與板上 I/O 互動條件下穩定運作。因此，本研究以 TLS/IPsec/SRTP 常見之封包保護概念作為設計靈感，建立具固定長度標頭欄位、96-bit 唯一 IV 與不同 payload 大小之封包型態，但不主張與既有通訊協定線路格式完全相容 [REF_TLS13] [REF_IPSEC_GCM] [REF_SRTP_GCM]。

在凍結之板級驗證結果中，三組 packet profiles 皆完成完整測試，且無板級失敗。`control_command` profile 共 30 筆案例，其中 24 筆正常案例全部通過，6 筆竄改拒絕案例全部通過，板級失敗數為 0。`uav_telemetry` profile 共 30 筆案例，其中 24 筆正常案例全部通過，6 筆竄改拒絕案例全部通過，板級失敗數為 0。`video_microchunk` profile 共 30 筆案例，其中 24 筆正常案例全部通過，6 筆竄改拒絕案例全部通過，板級失敗數為 0。上述結果已彙整於凍結之 thesis summary artifacts 中，可直接作為論文驗證章節之定稿依據。

此外，為排除偶然性與單次燒錄成功所造成之誤判，本研究另完成兩輪 fresh reprogram 驗證循環；每一輪皆以重新燒錄目前既有 bitstream 作為 fresh state 起點，並重新執行完整 packet-profile 板級驗證。兩輪 fresh reprogram cycles 均成功完成，且三組 profiles 皆維持 `24 normal pass + 6 tamper reject pass + 0 board failures` 之相同結果。此結果顯示本研究所提出之 packet-profile 板級驗證流程已具備可重現性，足以作為論文中板上實作驗證之最終證據。
