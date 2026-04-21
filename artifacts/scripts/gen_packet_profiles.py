import json
import random
from pathlib import Path

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError as exc:
    raise SystemExit(
        "cryptography is not installed. Install it with: python -m pip install cryptography"
    ) from exc


ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "txt" / "profiles"


def randbytes(rng: random.Random, length: int) -> bytes:
    return bytes(rng.getrandbits(8) for _ in range(length))


def mutate_one_byte(data: bytes, tweak: int) -> bytes:
    if not data:
        return data
    idx = tweak % len(data)
    mutated = bytearray(data)
    mutated[idx] ^= (0xA5 ^ (tweak & 0xFF))
    if mutated[idx] == data[idx]:
        mutated[idx] ^= 0x01
    return bytes(mutated)


def pack_u32(value: int) -> bytes:
    return value.to_bytes(4, "big")


def pack_u16(value: int) -> bytes:
    return value.to_bytes(2, "big")


def build_uav_aad(packet_index: int, payload_len: int):
    msg_type = 0x40 + (packet_index % 8)
    stream_id = 0x01
    reserved = 0
    seq = packet_index + 1
    timestamp = 0x65000000 + packet_index * 20
    aad = bytes(
        [
            msg_type,
            stream_id,
        ]
    ) + pack_u16(reserved) + pack_u32(seq) + pack_u32(timestamp) + pack_u32(payload_len)
    fields = {
        "msg_type": msg_type,
        "stream_id": stream_id,
        "reserved": reserved,
        "seq": seq,
        "timestamp": timestamp,
        "payload_len": payload_len,
    }
    return aad, fields


def build_control_aad(packet_index: int, payload_len: int):
    cmd_type = 0x10 + (packet_index % 6)
    target_id = 0x20 + (packet_index % 4)
    flags = 0x0001 | ((packet_index & 0x7) << 4)
    seq = 0x1000 + packet_index
    timestamp = 0x66000000 + packet_index * 10
    aad = bytes([cmd_type, target_id]) + pack_u16(flags) + pack_u32(seq) + pack_u32(timestamp) + pack_u32(payload_len)
    fields = {
        "cmd_type": cmd_type,
        "target_id": target_id,
        "flags": flags,
        "seq": seq,
        "timestamp": timestamp,
        "payload_len": payload_len,
    }
    return aad, fields


def build_video_aad(packet_index: int, payload_len: int):
    frame_id = 0x20000000 + packet_index
    chunk_id = packet_index % 64
    stream_id = 0x0001
    timestamp = 0x67000000 + packet_index * 33
    aad = (
        pack_u32(frame_id)
        + pack_u16(chunk_id)
        + pack_u16(stream_id)
        + pack_u32(timestamp)
        + pack_u32(payload_len)
    )
    fields = {
        "frame_id": frame_id,
        "chunk_id": chunk_id,
        "stream_id": stream_id,
        "timestamp": timestamp,
        "payload_len": payload_len,
    }
    return aad, fields


PROFILES = {
    "uav_telemetry": {
        "pt_lengths": [16, 24, 32],
        "aad_builder": build_uav_aad,
        "seed": 0x13579,
    },
    "control_command": {
        "pt_lengths": [8, 16],
        "aad_builder": build_control_aad,
        "seed": 0x24680,
    },
    "video_microchunk": {
        "pt_lengths": [32, 40, 48],
        "aad_builder": build_video_aad,
        "seed": 0xABCDE,
    },
}


def generate_profile(profile_name: str, config: dict):
    rng = random.Random(config["seed"])
    key = randbytes(rng, 32)
    salt = randbytes(rng, 4)
    aesgcm = AESGCM(key)

    base_packets = []
    for packet_index in range(18):
        pt_len = config["pt_lengths"][packet_index % len(config["pt_lengths"])]
        pt = randbytes(rng, pt_len)
        aad, aad_fields = config["aad_builder"](packet_index, pt_len)
        iv = salt + (packet_index + 1).to_bytes(8, "big")
        encrypted = aesgcm.encrypt(iv, pt, aad)
        ct = encrypted[:-16]
        tag = encrypted[-16:]
        base_packets.append(
            {
                "packet_index": packet_index,
                "key": key,
                "iv": iv,
                "aad": aad,
                "pt": pt,
                "ct": ct,
                "tag": tag,
                "tag_bits": 128,
                "aad_fields": aad_fields,
            }
        )

    cases = []
    for idx, packet in enumerate(base_packets[:12]):
        cases.append(
            {
                "profile": profile_name,
                "case_id": f"{profile_name}_enc_{idx:02d}",
                "mode": "enc",
                "key": packet["key"].hex(),
                "iv": packet["iv"].hex(),
                "aad": packet["aad"].hex(),
                "pt": packet["pt"].hex(),
                "ct_expected": packet["ct"].hex(),
                "tag_expected": packet["tag"].hex(),
                "ct_input": "",
                "tag_input": "",
                "tag_bits": packet["tag_bits"],
                "aad_fields": packet["aad_fields"],
                "expected_status": "ENC_OK",
                "notes": "normal encrypt",
            }
        )
        cases.append(
            {
                "profile": profile_name,
                "case_id": f"{profile_name}_dec_{idx:02d}",
                "mode": "dec",
                "key": packet["key"].hex(),
                "iv": packet["iv"].hex(),
                "aad": packet["aad"].hex(),
                "pt": packet["pt"].hex(),
                "ct_expected": packet["ct"].hex(),
                "tag_expected": packet["tag"].hex(),
                "ct_input": packet["ct"].hex(),
                "tag_input": packet["tag"].hex(),
                "tag_bits": packet["tag_bits"],
                "aad_fields": packet["aad_fields"],
                "expected_status": "DEC_OK",
                "notes": "normal decrypt",
            }
        )

    tamper_packets = base_packets[12:]
    tamper_kinds = ["aad", "aad", "ct", "ct", "tag", "tag"]
    for idx, (packet, tamper_kind) in enumerate(zip(tamper_packets, tamper_kinds)):
        case = {
            "profile": profile_name,
            "case_id": f"{profile_name}_{tamper_kind}_tamper_{idx:02d}",
            "mode": "dec",
            "key": packet["key"].hex(),
            "iv": packet["iv"].hex(),
            "aad": packet["aad"].hex(),
            "pt": packet["pt"].hex(),
            "ct_expected": packet["ct"].hex(),
            "tag_expected": packet["tag"].hex(),
            "ct_input": packet["ct"].hex(),
            "tag_input": packet["tag"].hex(),
            "tag_bits": packet["tag_bits"],
            "aad_fields": packet["aad_fields"],
            "expected_status": "AUTH_FAIL",
            "notes": f"tamper {tamper_kind}",
            "tamper_kind": tamper_kind,
        }
        if tamper_kind == "aad":
            case["aad"] = mutate_one_byte(packet["aad"], idx).hex()
        elif tamper_kind == "ct":
            case["ct_input"] = mutate_one_byte(packet["ct"], idx).hex()
        elif tamper_kind == "tag":
            case["tag_input"] = mutate_one_byte(packet["tag"], idx).hex()
        cases.append(case)

    return cases


def write_jsonl(path: Path, records):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, sort_keys=True) + "\n")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for profile_name, config in PROFILES.items():
        cases = generate_profile(profile_name, config)
        out_path = OUT_DIR / f"{profile_name}_profile.jsonl"
        write_jsonl(out_path, cases)
        print(f"{profile_name}: wrote {len(cases)} cases to {out_path}")


if __name__ == "__main__":
    main()
