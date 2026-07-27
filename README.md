# AES-GCM FPGA Secure IoT Packet Engine

An FPGA-based AES-GCM authenticated-encryption project for secure IoT packet transmission. The design is implemented in Verilog RTL, validated with NIST GCM vectors, and exercised through UART packet profiles on an Arty A7-100T board.

## Project highlights

- AES-GCM-128/192/256 RTL datapath with AES, GCTR, GHASH, and authentication-tag verification.
- IoT-inspired packet profiles for control commands, UAV telemetry, and video micro-chunks.
- UART and keyed-SPI integration paths for board-level packet transport.
- 59,161 NIST `.rsp` encryption, decryption, and tag-mismatch cases passed.
- Six UART-over-COM4 packet-profile runs completed with zero board failures: 72 encryption cases passed, 72 decryption cases passed, and 36 AAD/ciphertext/tag tamper cases were rejected.
- Cycle-count-derived AES-GCM-256 throughput: **1.065 Gbps** at 125 MHz for a 64 KiB payload on the Stage 8 internal-traffic datapath. Both the traffic source and sink were inside the FPGA.
- Final-routed Stage 8 internal-traffic top on the Arty A7-100T: 4,506 LUT, 3,957 FF, 0 BRAM, and 0 DSP at 125 MHz.
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

## Validation scope

The public summary uses frozen results only. The three packet profiles each contain 30 cases per run: 12 encrypt, 12 decrypt, 2 AAD tamper, 2 ciphertext tamper, and 2 tag tamper cases. Two runs were completed for each profile with zero board failures.

Core-only throughput and end-to-end transport metrics are reported separately. The 1.065 Gbps figure is cycle-count-derived from the Stage 8 internal-traffic datapath with both the source and sink inside the FPGA; it is not a UART, SPI, wireless, or PC/Wi-Fi/Raspberry Pi/FPGA end-to-end rate.

## Website

Open `docs/index.html` locally, or enable GitHub Pages with the repository's `docs/` folder as the publishing source. The page includes a Traditional Chinese / English language switch.

The portfolio is split into two interview themes: [AES-GCM FPGA IP Core](docs/projects/ip-core.html) for throughput, resource, and power characterization, and [Secure IoT Packet Transmission](docs/projects/iot-system.html) for application-level integration and board validation.

## Reproduction and safety

Use the available project scripts, board notes, and preserved summaries to trace and reproduce the published results within their stated hardware and measurement boundaries. Do not commit keys, private packet captures, generated Vivado folders, WDB files, or personal thesis material. Hardware tests should only be run on the intended board and with the correct UART/SPI wiring.

## Thesis reference

The project results are summarized from the thesis **Design and Board-Level Validation of an AES-GCM-256 FPGA Encryption, Decryption, and Authentication System for IoT Packet Transmission**. The public repository excludes the full thesis PDF, personal material, secret keys, private captures, and generated tool databases unless a separate publication decision is made.
