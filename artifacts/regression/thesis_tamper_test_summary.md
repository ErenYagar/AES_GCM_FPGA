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
