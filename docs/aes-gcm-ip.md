# AES-GCM IP / Secure IoT Packet Engine

## 1. Purpose

This IP provides authenticated encryption for packet-oriented IoT links. It combines confidentiality and integrity so a receiver can reject a packet when the associated metadata, ciphertext, or authentication tag has been modified.

## 2. RTL building blocks

| Block | Responsibility |
|---|---|
| AES core | AES-128/192/256 block cipher and key expansion |
| GCTR | Counter-mode encryption/decryption stream generation |
| GHASH | Polynomial hash over AAD and ciphertext in GF(2^128) |
| Tag verification | Compares the received tag and produces `AUTH_FAIL` on mismatch |
| Packet wrapper | Frames IV, AAD, payload, tag, status, and length fields |
| UART/SPI interface | Moves packets between the FPGA and the surrounding system |

## 3. Packet model

The profiles use a 256-bit session key, a 96-bit IV, 16-byte AAD headers, variable-length plaintext/ciphertext, and a 128-bit authentication tag. The AAD is authenticated but is not encrypted.

Three protocol-inspired profiles exercise different packet shapes:

- `control_command`: short command payloads and command metadata.
- `uav_telemetry`: telemetry metadata, sequence number, timestamp, and payload length.
- `video_microchunk`: frame/chunk metadata with larger payloads.

Each profile run contains 30 cases: 12 encryption, 12 decryption, 2 AAD-tamper, 2 ciphertext-tamper, and 2 tag-tamper cases.

## 4. System integration

The prototype uses a Raspberry Pi 4 for camera capture, H.264 processing, and packetization; an Arty A7-100T FPGA for keyed-SPI AES-GCM-256 protection; and a PC as the ground station. ML-KEM-768 and HKDF-SHA256 are used in the prototype session-key derivation flow.

## 5. Frozen results

| Measurement | Result |
|---|---:|
| NIST AES-GCM-128/192/256 cases | 59,161 passed |
| UART board cases | 180 |
| Normal board cases | 144 passed |
| Tamper-rejection board cases | 36 passed |
| Board failures | 0 |
| AES-GCM-256 core throughput | 1.065 Gbps |
| Core clock / payload | 125 MHz / 64 KiB |
| Core resources | 4,506 LUT; 3,957 FF; 0 BRAM; 0 DSP |
| Command/ACK transactions | 900 matched; 0 lost |

The core-only rate must not be interpreted as the end-to-end PC, Wi-Fi, Raspberry Pi, SPI, and FPGA transport rate. In the integrated prototype, the active verified rate was 0.984 Mbps and completion goodput was 0.477 Mbps. These measurements include the surrounding software and transport path.

## 6. Integration checklist

1. Provide a unique 96-bit IV for each key and packet context.
2. Keep AAD byte order and field lengths identical at both endpoints.
3. Do not release plaintext until tag verification succeeds.
4. Treat `AUTH_FAIL` as a rejected packet and record the tamper class for diagnostics.
5. Verify UART/SPI framing, length fields, reset behavior, and timeout handling before board bring-up.

## 7. Public-release boundary

This document intentionally describes the interface and verified behavior without publishing secret keys, private captures, generated simulator databases, or the full thesis PDF. Refer to `artifacts/regression/profile_thesis_summary.md` for the frozen packet-profile totals.
