import argparse
import hashlib
import sys
import time

import serial


CMD_MODE = 0x01
CMD_KEY = 0x02
CMD_IV = 0x03
CMD_AAD = 0x04
CMD_PT = 0x05
CMD_CT = 0x06
CMD_TAG = 0x07
CMD_RUN = 0x08

RSP_STATUS = 0x80
RSP_PC = 0x81
RSP_TAG = 0x82

STAT_ENC_OK = 0x00
STAT_DEC_OK = 0x01
STAT_AUTH_FAIL = 0xFF
STAT_BAD_CFG = 0xFE
STAT_BUSY = 0xFD


def clean_hex(text: str) -> str:
    text = text.strip().lower()
    if text.startswith("0x"):
        text = text[2:]
    text = text.replace("_", "").replace(" ", "")
    if len(text) % 2:
        text = "0" + text
    return text


def hex_to_bytes(text: str) -> bytes:
    text = clean_hex(text)
    if text == "":
        return b""
    return bytes.fromhex(text)


def bytes_to_hex(data: bytes) -> str:
    return data.hex()


def build_packet(cmd: int, bit_length: int, payload: bytes) -> bytes:
    frame = bytearray()
    frame.append(cmd & 0xFF)
    frame.append((bit_length >> 8) & 0xFF)
    frame.append(bit_length & 0xFF)
    frame.extend(payload)
    return bytes(frame)


def send_packet(ser: serial.Serial, cmd: int, bit_length: int, payload: bytes) -> bytes:
    frame = build_packet(cmd, bit_length, payload)
    ser.write(frame)
    ser.flush()
    return frame


def recv_exact(ser: serial.Serial, count: int) -> bytes:
    data = bytearray()
    deadline = time.time() + ser.timeout
    while len(data) < count:
        chunk = ser.read(count - len(data))
        if chunk:
            data.extend(chunk)
            continue
        if time.time() > deadline:
            raise TimeoutError(f"Timeout waiting for {count} bytes, got {len(data)}")
    return bytes(data)


def recv_frame(ser: serial.Serial):
    header = recv_exact(ser, 3)
    frame_type = header[0]
    bit_length = (header[1] << 8) | header[2]
    byte_count = (bit_length + 7) // 8
    payload = recv_exact(ser, byte_count) if byte_count else b""
    return frame_type, bit_length, payload, header + payload


def status_name(code: int) -> str:
    mapping = {
        STAT_ENC_OK: "ENC_OK",
        STAT_DEC_OK: "DEC_OK",
        STAT_AUTH_FAIL: "AUTH_FAIL",
        STAT_BAD_CFG: "BAD_CFG",
        STAT_BUSY: "BUSY",
    }
    return mapping.get(code, f"UNKNOWN_{code:02X}")


def frames_hash(frames) -> str:
    digest = hashlib.sha256()
    for frame in frames:
        digest.update(frame)
    return f"sha256:{digest.hexdigest()}"


def run_transaction_fields(
    *,
    port: str,
    timeout: float,
    mode: str,
    key_hex: str,
    iv_hex: str,
    aad_hex: str = "",
    pt_hex: str = "",
    ct_hex: str = "",
    tag_hex: str = "",
    tag_bits: int = 128,
    settle_s: float = 0.02,
):
    mode_bit = 0 if mode == "enc" else 1
    key = hex_to_bytes(key_hex)
    iv = hex_to_bytes(iv_hex)
    aad = hex_to_bytes(aad_hex)
    pt = hex_to_bytes(pt_hex)
    ct = hex_to_bytes(ct_hex)
    tag = hex_to_bytes(tag_hex)

    if len(key) != 32:
        raise ValueError("KEY must be exactly 32 bytes (256 bits).")

    if mode == "enc":
        if tag_bits % 8 != 0:
            raise ValueError("tag_bits must be a multiple of 8.")
        if tag == b"":
            tag = bytes(tag_bits // 8)
        elif len(tag) * 8 != tag_bits:
            raise ValueError("Encrypt TAG payload length must match tag_bits.")
    else:
        if tag == b"":
            raise ValueError("Decrypt mode requires TAG.")
        tag_bits = len(tag) * 8

    data_payload = pt if mode == "enc" else ct
    data_cmd = CMD_PT if mode == "enc" else CMD_CT
    result = {
        "status": None,
        "status_name": None,
        "ct_bits": 0,
        "ct": b"",
        "tag_bits": 0,
        "tag": b"",
        "pt_bits": 0,
        "pt": b"",
        "tx_frame_hash": None,
        "rx_frame_hash": None,
        "latency_ms": None,
    }
    tx_frames = []
    rx_frames = []

    with serial.Serial(port, 115200, timeout=timeout) as ser:
        time.sleep(settle_s)
        ser.reset_input_buffer()
        ser.reset_output_buffer()

        tx_frames.append(send_packet(ser, CMD_MODE, 8, bytes([mode_bit])))
        tx_frames.append(send_packet(ser, CMD_KEY, 256, key))
        tx_frames.append(send_packet(ser, CMD_IV, len(iv) * 8, iv))
        tx_frames.append(send_packet(ser, CMD_AAD, len(aad) * 8, aad))
        tx_frames.append(send_packet(ser, data_cmd, len(data_payload) * 8, data_payload))
        tx_frames.append(send_packet(ser, CMD_TAG, tag_bits, tag))
        tx_frames.append(send_packet(ser, CMD_RUN, 0, b""))

        started = time.time()
        rsp_type, rsp_bits, rsp_payload, rsp_frame = recv_frame(ser)
        rx_frames.append(rsp_frame)
        if rsp_type != RSP_STATUS or rsp_bits != 8 or len(rsp_payload) != 1:
            raise RuntimeError(f"Unexpected first frame: type=0x{rsp_type:02x} bits={rsp_bits} payload={rsp_payload.hex()}")

        status = rsp_payload[0]
        result["status"] = status
        result["status_name"] = status_name(status)

        if mode == "enc":
            if len(data_payload) > 0:
                rsp_type, rsp_bits, rsp_payload, rsp_frame = recv_frame(ser)
                rx_frames.append(rsp_frame)
                if rsp_type != RSP_PC:
                    raise RuntimeError(f"Expected PC frame, got 0x{rsp_type:02X}")
                result["ct_bits"] = rsp_bits
                result["ct"] = rsp_payload

            if tag_bits > 0:
                rsp_type, rsp_bits, rsp_payload, rsp_frame = recv_frame(ser)
                rx_frames.append(rsp_frame)
                if rsp_type != RSP_TAG:
                    raise RuntimeError(f"Expected TAG frame, got 0x{rsp_type:02X}")
                result["tag_bits"] = rsp_bits
                result["tag"] = rsp_payload
        else:
            if status == STAT_DEC_OK and len(data_payload) > 0:
                rsp_type, rsp_bits, rsp_payload, rsp_frame = recv_frame(ser)
                rx_frames.append(rsp_frame)
                if rsp_type != RSP_PC:
                    raise RuntimeError(f"Expected PT frame, got 0x{rsp_type:02X}")
                result["pt_bits"] = rsp_bits
                result["pt"] = rsp_payload

    result["tx_frame_hash"] = frames_hash(tx_frames)
    result["rx_frame_hash"] = frames_hash(rx_frames)
    result["latency_ms"] = int((time.time() - started) * 1000)

    return result


def run_transaction(args):
    result = run_transaction_fields(
        port=args.port,
        timeout=args.timeout,
        mode=args.mode,
        key_hex=args.key,
        iv_hex=args.iv,
        aad_hex=args.aad,
        pt_hex=args.pt,
        ct_hex=args.ct,
        tag_hex=args.tag,
        tag_bits=args.tag_bits,
        settle_s=args.settle,
    )
    print(f"STATUS: 0x{result['status']:02X} ({result['status_name']})")
    if args.mode == "enc":
        if result["ct_bits"] > 0:
            print(f"CT[{result['ct_bits']}]: {bytes_to_hex(result['ct'])}")
        if result["tag_bits"] > 0:
            print(f"TAG[{result['tag_bits']}]: {bytes_to_hex(result['tag'])}")
    else:
        if result["pt_bits"] > 0:
            print(f"PT[{result['pt_bits']}]: {bytes_to_hex(result['pt'])}")


def main():
    parser = argparse.ArgumentParser(description="Minimal UART host for fpga_top_arty_a7_uart")
    parser.add_argument("--port", default="COM4")
    parser.add_argument("--mode", choices=["enc", "dec"], required=True)
    parser.add_argument("--key", required=True, help="hex string, 256-bit")
    parser.add_argument("--iv", required=True, help="hex string")
    parser.add_argument("--aad", default="", help="hex string")
    parser.add_argument("--pt", default="", help="hex string, used for encrypt")
    parser.add_argument("--ct", default="", help="hex string, used for decrypt")
    parser.add_argument("--tag", default="", help="hex string; required for decrypt, optional zeros for encrypt")
    parser.add_argument("--tag-bits", type=int, default=128, help="encrypt tag length in bits")
    parser.add_argument("--timeout", type=float, default=3.0)
    parser.add_argument("--settle", type=float, default=0.02, help="serial settle delay after opening COM port")
    args = parser.parse_args()

    try:
        run_transaction(args)
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
