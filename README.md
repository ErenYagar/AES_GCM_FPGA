# AES-GCM FPGA Secure IoT Packet Engine

An FPGA-based AES-GCM authenticated-encryption project for secure IoT packet transmission. The design is implemented in Verilog RTL, validated with NIST GCM vectors, and exercised through UART packet profiles on an Arty A7-100T board.

## Project highlights

- AES-GCM-128/192/256 RTL datapath with AES, GCTR, GHASH, and authentication-tag verification.
- IoT-inspired packet profiles for control commands, UAV telemetry, and video micro-chunks.
- UART and keyed-SPI integration paths for board-level packet transport.
- 59,161 NIST `.rsp` encryption, decryption, and tag-mismatch cases passed.
- 180 UART board cases passed: 144 normal cases and 36 tamper-rejection cases.
- AES-GCM-256 core-only throughput: **1.065 Gbps** at 125 MHz with a 64 KiB payload.
- Core implementation snapshot: 4,506 LUT, 3,957 FF, 0 BRAM, and 0 DSP.
- End-to-end prototype with Raspberry Pi 4, Arty FPGA, and a PC ground station.

## Repository map

| Path | Purpose |
|---|---|
| `rtl/` | AES-GCM, AES core, GCTR, GHASH, UART, and FPGA top-level RTL |
| `tb/` | SystemVerilog simulation testbenches |
| `artifacts/regression/` | Frozen validation summaries and packet-profile evidence |
| `hardware/` | Secure telemetry interface board design and release notes |
| `docs/aes-gcm-ip.md` | Public IP architecture and integration notes |
| `docs/index.html` | Bilingual project showcase website |
| `論文/01_論文/M1181422.pdf` | Local thesis source; not included in the public release by default |

## Validation scope

The public summary uses frozen results only. The three packet profiles each contain 30 cases per run: 12 encrypt, 12 decrypt, 2 AAD tamper, 2 ciphertext tamper, and 2 tag tamper cases. Two runs were completed for each profile with zero board failures.

Core-only throughput and end-to-end transport metrics are reported separately. The 1.065 Gbps figure is the FPGA AES-GCM-256 core rate, not a PC/Wi-Fi/Raspberry Pi/SPI-to-FPGA link rate.

## Website

Open `docs/index.html` locally, or enable GitHub Pages with the repository's `docs/` folder as the publishing source. The page includes a Traditional Chinese / English language switch.

The portfolio is split into two interview themes: [AES-GCM FPGA IP Core](docs/projects/ip-core.html) for throughput, resource, and power characterization, and [Secure IoT Packet Transmission](docs/projects/iot-system.html) for application-level integration and board validation.

## Reproduction and safety

Use the existing project scripts and board notes for local reproduction. Do not commit keys, private packet captures, generated Vivado folders, WDB files, or personal thesis material. Hardware tests should only be run on the intended board and with the correct UART/SPI wiring.

## Thesis reference

The project results are summarized from the thesis **Design and Board-Level Validation of an AES-GCM-256 FPGA Encryption, Decryption, and Authentication System for IoT Packet Transmission**. The full PDF remains a local source document unless a separate publication decision is made.
