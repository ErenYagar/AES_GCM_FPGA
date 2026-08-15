# 板級驗證結果與驗證目的

## 驗證目的與證據範圍

本節整理 frozen packet-profile validation summary 所記錄的板級驗證結果。分析範圍限定於三種 packet profile、兩個 frozen runs，以及 summary 中的 `case_count`、`normal_pass`、`tamper_reject_pass` 與 `board_failures` 欄位；不重新執行硬體測試，也不從其他 Vivado、RTL 或舊 regression 檔案補推結果。

三個 profile 分別為 `control_command`、`uav_telemetry` 與 `video_microchunk`。每個 profile 在 `run1` 與 `run2` 都記錄 30 個案例、24 個正常案例通過、6 個竄改拒絕案例通過，且 `board_failures` 為 0。六個 frozen run 合計 180 個案例，其中 144 個為正常案例通過，36 個為竄改拒絕通過，板級失敗數為 0。

## Profile 結果

`control_command` 在兩個 frozen runs 都記錄 30/30 個案例完成，包含 24 個正常通過與 6 個竄改拒絕通過，`board_failures` 為 0。

`uav_telemetry` 在兩個 frozen runs 都記錄 30/30 個案例完成，包含 24 個正常通過與 6 個竄改拒絕通過，`board_failures` 為 0。

`video_microchunk` 在兩個 frozen runs 都記錄 30/30 個案例完成，包含 24 個正常通過與 6 個竄改拒絕通過，`board_failures` 為 0。

兩個 run 的數字一致，表示在目前 frozen summary 所涵蓋的範圍內，三個 profile 的結果具有 run-to-run 一致性。這裡的 `run1` 與 `run2` 僅是 summary 中的 run 標籤，不將其額外解讀為特定燒錄或硬體重置程序。

## 與 profile records 的關係

三份 JSONL profile 各含 30 筆 records。每個 profile 的 record 組成為 12 筆 normal encrypt、12 筆 normal decrypt，以及各 2 筆 `tamper aad`、`tamper ct` 與 `tamper tag`。三種 tamper 類別合計 6 筆，與 summary 的 `tamper_reject_pass=6` 對應；JSONL 中這 6 筆的 `expected_status` 均為 `AUTH_FAIL`。

## 結論邊界

上述結果支持 frozen packet-profile summary 所定義的板級案例計數與通過結果。它不單獨證明未出現在 frozen inputs 中的 timing closure、外部 I/O timing、Vivado resource 使用量、plaintext release ordering 或其他硬體行為。

## 來源

- `artifacts/regression/profile_thesis_summary.md`
- `artifacts/regression/profile_thesis_summary.csv`
- `txt/profiles/uav_telemetry_profile.jsonl`
- `txt/profiles/control_command_profile.jsonl`
- `txt/profiles/video_microchunk_profile.jsonl`
