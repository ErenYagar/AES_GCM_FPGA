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

The prototype uses a Raspberry Pi 4 for camera capture, H.264 processing, and packetization; an Arty A7-100T FPGA for keyed-SPI AES-GCM-256 protection; and a PC as the ground station. Host-side ML-KEM-768 and HKDF-SHA256 establish and derive the AES-256 session material; the resulting key and salt are provisioned to the FPGA through the keyed-SPI control path. ML-KEM and HKDF are not implemented as FPGA accelerator cores in this project.

## 5. Frozen results

| Measurement | Result |
|---|---:|
| NIST AES-GCM-128/192/256 cases | 59,161 passed |
| UART board cases | 180 |
| Normal encryption board cases | 72 passed |
| Normal decryption board cases | 72 passed |
| Tamper-rejection board cases | 36 passed |
| Board failures | 0 |
| AES-GCM-256 Stage 8 internal-traffic throughput | 1.065 Gbps, cycle-count-derived |
| Core clock / payload | 125 MHz / 64 KiB |
| Stage 8 internal-traffic routed-top resources | 4,506 LUT; 3,957 FF; 0 BRAM; 0 DSP |
| Protected command/ACK transport test | 900/900 matched; 0 transport loss |

The core-only rate must not be interpreted as UART, SPI, wireless, or end-to-end PC/Wi-Fi/Raspberry Pi/FPGA throughput. Both the traffic source and sink were inside the FPGA. In one representative end-to-end run, 237,600 verified payload bytes produced a 0.984 Mbps active verified receive rate over the active 1.931620 s receive window and 0.477 Mbps completion goodput over the full 3.989026 s completion window. The two rates use different time boundaries and are not interchangeable.

The 900 matched command/ACK results demonstrate protected transport behavior. The returned ACKs were controlled `DENIED` responses and do not demonstrate completion of a real flight-control action. ReplayGuard logic is implemented in the Pi command bridge and PC receiver, but the preserved negative-test evidence covers offline receiver injection rather than a demonstrated live Wi-Fi replay attack.

## 6. Integration checklist

1. Provide a unique 96-bit IV for each key and packet context.
2. Keep AAD byte order and field lengths identical at both endpoints.
3. Do not release plaintext until tag verification succeeds.
4. Treat `AUTH_FAIL` as a rejected packet and record the tamper class for diagnostics.
5. Verify UART/SPI framing, length fields, reset behavior, and timeout handling before board bring-up.

## 7. Public-release boundary

This public note intentionally describes the interface, measurement boundaries, and verified behavior without publishing secret keys, private captures, generated simulator databases, personal material, or the full thesis PDF. Refer to `artifacts/regression/profile_thesis_summary.md` for the frozen packet-profile totals.
