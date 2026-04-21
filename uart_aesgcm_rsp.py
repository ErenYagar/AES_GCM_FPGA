import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import serial

from uart_aesgcm_host import (
    STAT_AUTH_FAIL,
    STAT_DEC_OK,
    STAT_ENC_OK,
    bytes_to_hex,
    recv_frame,
    run_transaction_fields,
    send_packet,
)


CMD_DEBUG = 0x09
RSP_DEBUG_HDR = 0x90
RSP_DEBUG_IV = 0x91
RSP_DEBUG_AAD = 0x92
RSP_DEBUG_DATA = 0x93
RSP_DEBUG_TAG = 0x94

MAX_KEY_BITS = 256
MAX_DATA_BITS = 1024
MAX_TAG_BITS = 128

REGRESSION_ROOT = Path(__file__).resolve().parent / "artifacts" / "regression"
DEFAULT_BITSTREAM_CANDIDATE = Path(__file__).resolve().parent / "artifacts" / "fpga_top_arty_a7_uart_fixed.bit"


def parse_rsp(path: Path):
    cases = []
    section = {}
    current = None

    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        if line.startswith("[") and line.endswith("]"):
            body = line[1:-1]
            key, value = [part.strip() for part in body.split("=", 1)]
            section[key] = int(value)
            continue

        if line.startswith("Count ="):
            if current is not None:
                cases.append(current)
            current = dict(section)
            current["Count"] = int(line.split("=", 1)[1].strip())
            current["FAIL"] = False
            continue

        if current is None:
            continue

        if line == "FAIL":
            current["FAIL"] = True
            continue

        key, value = [part.strip() for part in line.split("=", 1)]
        current[key] = value

    if current is not None:
        cases.append(current)

    return cases


def default_files():
    base = Path(__file__).resolve().parent / "txt"
    return [
        base / "gcmEncryptExtIV256.rsp",
        base / "gcmDecrypt256.rsp",
    ]


def infer_mode(path: Path):
    name = path.name.lower()
    if "encrypt" in name:
        return "enc"
    if "decrypt" in name:
        return "dec"
    raise ValueError(f"Cannot infer mode from file name: {path}")


def build_case_list(files):
    cases = []
    global_index = 0

    for path in files:
        mode = infer_mode(path)
        for case in parse_rsp(path):
            enriched = dict(case)
            enriched["_mode"] = mode
            enriched["_source_file"] = str(path)
            enriched["_global_index"] = global_index
            cases.append(enriched)
            global_index += 1

    return cases


def fits_board_limits(case):
    return (
        case.get("Keylen", 0) <= MAX_KEY_BITS
        and case.get("IVlen", 0) <= MAX_DATA_BITS
        and case.get("AADlen", 0) <= MAX_DATA_BITS
        and case.get("PTlen", 0) <= MAX_DATA_BITS
        and case.get("CTlen", 0) <= MAX_DATA_BITS
        and case.get("Taglen", 0) <= MAX_TAG_BITS
    )


def case_tuple(case):
    return {
        "mode": case["_mode"],
        "Count": case.get("Count"),
        "Taglen": case.get("Taglen"),
        "PTlen": case.get("PTlen"),
        "AADlen": case.get("AADlen"),
        "IVlen": case.get("IVlen"),
    }


def expected_data_hex(case):
    if case["_mode"] == "enc":
        return case.get("CT", "").lower()
    return case.get("PT", "").lower()


def actual_data_hex(case, result):
    if case["_mode"] == "enc":
        return bytes_to_hex(result["ct"])
    return bytes_to_hex(result["pt"])


def expected_tag_hex(case):
    return case.get("Tag", "").lower()


def actual_tag_hex(result):
    return bytes_to_hex(result["tag"])


def tuple_str(case):
    parts = case_tuple(case)
    return (
        f"{parts['mode']} "
        f"Count={parts['Count']} "
        f"Taglen={parts['Taglen']} "
        f"PTlen={parts['PTlen']} "
        f"AADlen={parts['AADlen']} "
        f"IVlen={parts['IVlen']}"
    )


def tuple_str_fields(parts):
    return (
        f"{parts['mode']} "
        f"Count={parts['Count']} "
        f"Taglen={parts['Taglen']} "
        f"PTlen={parts['PTlen']} "
        f"AADlen={parts['AADlen']} "
        f"IVlen={parts['IVlen']}"
    )


def case_record(case):
    payload = {key: value for key, value in case.items() if not key.startswith("_")}
    payload["global_index"] = case["_global_index"]
    payload["tuple"] = case_tuple(case)
    payload["mode"] = case["_mode"]
    payload["source_file"] = case["_source_file"]
    return payload


def normalize_output_path(path_str, default_name=None):
    REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
    if path_str is None:
        if default_name is None:
            return None
        path = REGRESSION_ROOT / default_name
    else:
        path = Path(path_str)
        if not path.is_absolute():
            path = REGRESSION_ROOT / path
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def sha256_file(path: Path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return f"sha256:{digest.hexdigest()}"


def sha256_jsonable(value):
    blob = json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return f"sha256:{hashlib.sha256(blob).hexdigest()}"


def current_git_commit():
    root = Path(__file__).resolve().parent
    try:
        commit = subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        dirty = subprocess.check_output(
            ["git", "-C", str(root), "status", "--porcelain"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if dirty:
            commit = f"{commit}-dirty"
        return commit
    except Exception:
        return "unknown"


def infer_bitstream_hash(fresh_program_cmd):
    bit_path = None

    env_value = None
    try:
        import os

        env_value = os.environ.get("UART_AESGCM_BITSTREAM")
    except Exception:
        env_value = None

    if env_value:
        candidate = Path(env_value)
        if candidate.exists():
            bit_path = candidate

    if bit_path is None and fresh_program_cmd:
        quoted = re.findall(r'"([^"]+?\.bit)"', fresh_program_cmd, flags=re.IGNORECASE)
        for match in quoted:
            candidate = Path(match)
            if candidate.exists():
                bit_path = candidate
                break

    if bit_path is None and DEFAULT_BITSTREAM_CANDIDATE.exists():
        bit_path = DEFAULT_BITSTREAM_CANDIDATE

    if bit_path is None:
        return "unknown"

    try:
        return sha256_file(bit_path)
    except Exception:
        return "unknown"


def run_id_for(args, cases):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    prefix = args.run_label or timestamp
    if args.global_index is not None:
        scope = f"g{args.global_index}"
    else:
        first_idx = cases[0]["_global_index"] if cases else "none"
        last_idx = cases[-1]["_global_index"] if cases else "none"
        scope = f"g{first_idx}-{last_idx}"
    return f"{prefix}_{scope}"


def current_com4_owner():
    return "python uart_aesgcm_rsp.py"


def kill_stale_com4_processes(port):
    script = rf"""
$port = '{port}'
$self = {os.getpid()}
$ps = $PID
$targets = Get-CimInstance Win32_Process | Where-Object {{
    $_.ProcessId -ne $self -and
    $_.ProcessId -ne $ps -and
    $_.Name -match '^(python|pythonw|py)(\.exe)?$' -and
    $_.CommandLine -ne $null -and
    (
        $_.CommandLine -match 'uart_aesgcm_host\.py' -or
        $_.CommandLine -match 'uart_aesgcm_rsp\.py' -or
        $_.CommandLine -match 'tmp_debug_dump\.py' -or
        $_.CommandLine -match [regex]::Escape($port)
    )
}} | Select-Object ProcessId, Name, CommandLine

if ($targets) {{
    $targets | ForEach-Object {{ Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }}
    $targets | ConvertTo-Json -Compress -Depth 3
}}
"""
    proc = subprocess.run(
        ["powershell", "-NoProfile", "-Command", script],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"Failed to clean stale COM4 owners: {proc.stderr.strip()}")

    stdout = proc.stdout.strip()
    if not stdout:
        return []

    payload = json.loads(stdout)
    if isinstance(payload, dict):
        return [payload]
    return payload


def verify_com4_openable(port, timeout):
    handle = serial.Serial(port, 115200, timeout=timeout)
    handle.close()


def run_fresh_program(cmd):
    started = time.time()
    proc = subprocess.run(
        cmd,
        shell=True,
        capture_output=True,
        text=True,
    )
    elapsed_ms = int((time.time() - started) * 1000)
    return {
        "command": cmd,
        "exit_code": proc.returncode,
        "duration_ms": elapsed_ms,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


def collect_debug_dump(port, timeout):
    dump = {
        "frames": [],
        "error": None,
    }

    try:
        with serial.Serial(port, 115200, timeout=timeout) as ser:
            time.sleep(0.02)
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            send_packet(ser, CMD_DEBUG, 0, b"")

            for _ in range(5):
                frame_type, bit_length, payload = recv_frame(ser)
                dump["frames"].append(
                    {
                        "type": frame_type,
                        "bit_length": bit_length,
                        "payload_hex": payload.hex(),
                    }
                )
    except Exception as exc:
        dump["error"] = str(exc)

    return dump


def evaluate_encrypt_case(port, timeout, case):
    result = run_transaction_fields(
        port=port,
        timeout=timeout,
        mode="enc",
        key_hex=case["Key"],
        iv_hex=case["IV"],
        aad_hex=case.get("AAD", ""),
        pt_hex=case.get("PT", ""),
        tag_bits=case["Taglen"],
    )

    exp_ct = case.get("CT", "").lower()
    exp_tag = case.get("Tag", "").lower()
    got_ct = bytes_to_hex(result["ct"])
    got_tag = bytes_to_hex(result["tag"])

    if result["status"] != STAT_ENC_OK:
        return False, f"status=0x{result['status']:02X}", result
    if result["ct_bits"] != case["PTlen"]:
        return False, f"ct_bits={result['ct_bits']} expected={case['PTlen']}", result
    if got_ct != exp_ct:
        return False, f"ct={got_ct} expected={exp_ct}", result
    if result["tag_bits"] != case["Taglen"]:
        return False, f"tag_bits={result['tag_bits']} expected={case['Taglen']}", result
    if got_tag != exp_tag:
        return False, f"tag={got_tag} expected={exp_tag}", result
    return True, "", result


def evaluate_decrypt_case(port, timeout, case):
    result = run_transaction_fields(
        port=port,
        timeout=timeout,
        mode="dec",
        key_hex=case["Key"],
        iv_hex=case["IV"],
        aad_hex=case.get("AAD", ""),
        ct_hex=case.get("CT", ""),
        tag_hex=case["Tag"],
    )

    should_fail = case.get("FAIL", False)
    if should_fail:
        if result["status"] != STAT_AUTH_FAIL:
            return False, f"status=0x{result['status']:02X} expected=0x{STAT_AUTH_FAIL:02X}", result
        return True, "", result

    exp_pt = case.get("PT", "").lower()
    got_pt = bytes_to_hex(result["pt"])

    if result["status"] != STAT_DEC_OK:
        return False, f"status=0x{result['status']:02X}", result
    if result["pt_bits"] != case["PTlen"]:
        return False, f"pt_bits={result['pt_bits']} expected={case['PTlen']}", result
    if got_pt != exp_pt:
        return False, f"pt={got_pt} expected={exp_pt}", result
    return True, "", result


def write_jsonl(path: Path, record):
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def print_summary_table(summary):
    headers = [
        "run_id",
        "bitstream_hash",
        "git_commit",
        "rsp_hash",
        "pass",
        "fail",
        "first_fail_global_index",
        "first_fail_tuple",
        "COM4_owner",
    ]
    row = [str(summary.get(key, "")) for key in headers]
    print("| " + " | ".join(headers) + " |")
    print("|" + "|".join(["---"] * len(headers)) + "|")
    print("| " + " | ".join(row) + " |")


def write_summary_markdown(path: Path, summary):
    lines = [
        "| run_id | bitstream_hash | git_commit | rsp_hash | pass | fail | first_fail_global_index | first_fail_tuple | COM4_owner |",
        "|---|---|---|---|---:|---:|---:|---|---|",
        (
            f"| {summary['run_id']} | {summary['bitstream_hash']} | {summary['git_commit']} | "
            f"{summary['rsp_hash']} | {summary['pass']} | {summary['fail']} | "
            f"{summary['first_fail_global_index']} | {summary['first_fail_tuple']} | {summary['COM4_owner']} |"
        ),
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def select_cases(cases, args):
    if args.global_index is not None and (args.start_global_index is not None or args.end_global_index is not None):
        raise ValueError("--global-index cannot be combined with --start-global-index/--end-global-index")

    selected = cases
    if args.global_index is not None:
        selected = [case for case in cases if case["_global_index"] == args.global_index]
    else:
        if args.start_global_index is not None:
            selected = [case for case in selected if case["_global_index"] >= args.start_global_index]
        if args.end_global_index is not None:
            selected = [case for case in selected if case["_global_index"] <= args.end_global_index]

    if args.max_cases is not None:
        selected = selected[: args.max_cases]

    if args.mode_filter != "all":
        selected = [case for case in selected if case["_mode"] == args.mode_filter]

    if not selected:
        raise ValueError("No cases selected.")

    return selected


def main():
    parser = argparse.ArgumentParser(description="Run NIST GCM .rsp vectors against fpga_top_arty_a7_uart over UART.")
    parser.add_argument("--port", default="COM4")
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument("--max-cases", type=int, default=None, help="Limit selected cases after filtering")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--stop-on-fail", action="store_true")
    parser.add_argument("--mode-filter", choices=["all", "enc", "dec"], default="all")
    parser.add_argument("--global-index", type=int, default=None)
    parser.add_argument("--start-global-index", type=int, default=None)
    parser.add_argument("--end-global-index", type=int, default=None)
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--fresh-program-cmd", default=None)
    parser.add_argument("--jsonl-log", default=None)
    parser.add_argument("--first-fail-json", default=None)
    parser.add_argument("--dump-debug-on-fail", action="store_true")
    parser.add_argument("--summary-md", default=None)
    parser.add_argument("--run-label", default=None)
    parser.add_argument("files", nargs="*", help="Optional .rsp paths")
    args = parser.parse_args()

    if args.repeat < 1:
        raise ValueError("--repeat must be >= 1")
    if (
        args.start_global_index is not None
        and args.end_global_index is not None
        and args.end_global_index < args.start_global_index
    ):
        raise ValueError("--end-global-index must be >= --start-global-index")

    files = [Path(p) for p in args.files] if args.files else default_files()
    cases = build_case_list(files)
    selected_cases = select_cases(cases, args)

    run_id = run_id_for(args, selected_cases)
    jsonl_path = normalize_output_path(args.jsonl_log, default_name=f"{run_id}.jsonl")
    summary_md_path = normalize_output_path(args.summary_md, default_name=f"{run_id}_summary.md")
    first_fail_json_path = normalize_output_path(args.first_fail_json) if args.first_fail_json else None

    git_commit = current_git_commit()
    bitstream_hash = infer_bitstream_hash(args.fresh_program_cmd)
    rsp_hash = sha256_jsonable([case_record(case) for case in selected_cases])
    com4_owner = current_com4_owner()

    total_pass = 0
    total_fail = 0
    total_skip = 0
    first_fail_payload = None

    for repeat_index in range(1, args.repeat + 1):
        program_meta = None
        stale_killed = kill_stale_com4_processes(args.port)
        if args.fresh_program_cmd:
            program_meta = run_fresh_program(args.fresh_program_cmd)
            if program_meta["exit_code"] != 0:
                summary = {
                    "run_id": run_id,
                    "bitstream_hash": bitstream_hash,
                    "git_commit": git_commit,
                    "rsp_hash": rsp_hash,
                    "pass": total_pass,
                    "fail": total_fail + 1,
                    "first_fail_global_index": "PROGRAM_FAIL",
                    "first_fail_tuple": "PROGRAM_FAIL",
                    "COM4_owner": "none",
                }
                print_summary_table(summary)
                write_summary_markdown(summary_md_path, summary)
                sys.exit(1)

        verify_com4_openable(args.port, args.timeout)

        for case in selected_cases:
            record = {
                "run_id": run_id,
                "timestamp": datetime.now().isoformat(timespec="seconds"),
                "repeat_index": repeat_index,
                "repeat_total": args.repeat,
                "git_commit": git_commit,
                "bitstream_hash": bitstream_hash,
                "rsp_hash": rsp_hash,
                "global_index": case["_global_index"],
                "tuple": case_tuple(case),
                "mode": case["_mode"],
                "Count": case.get("Count"),
                "Taglen": case.get("Taglen"),
                "PTlen": case.get("PTlen"),
                "AADlen": case.get("AADlen"),
                "IVlen": case.get("IVlen"),
                "rsp_file": case["_source_file"],
                "source_file": case["_source_file"],
                "fresh_or_dirty": "fresh" if args.fresh_program_cmd else "dirty",
                "program_meta": program_meta,
                "stale_killed": stale_killed,
                "COM4_owner": com4_owner,
            }

            if not fits_board_limits(case):
                total_skip += 1
                record["result"] = "SKIP"
                record["detail"] = "exceeds board limits"
                write_jsonl(jsonl_path, record)
                if args.verbose:
                    print(f"SKIP g{case['_global_index']} {tuple_str(case)} exceeds board limits")
                continue

            try:
                if case["_mode"] == "enc":
                    ok, detail, result = evaluate_encrypt_case(args.port, args.timeout, case)
                else:
                    ok, detail, result = evaluate_decrypt_case(args.port, args.timeout, case)
            except Exception as exc:
                ok = False
                detail = f"exception={type(exc).__name__}: {exc}"
                result = {
                    "status": None,
                    "status_name": "EXCEPTION",
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

            record["result"] = "PASS" if ok else "FAIL"
            record["detail"] = detail
            record["status"] = result["status_name"]
            record["status_code"] = result["status"]
            record["tx_frame_hash"] = result["tx_frame_hash"]
            record["rx_frame_hash"] = result["rx_frame_hash"]
            record["latency_ms"] = result["latency_ms"]
            record["expected_tag"] = expected_tag_hex(case)
            record["actual_tag"] = actual_tag_hex(result)
            record["expected_data"] = expected_data_hex(case)
            record["actual_data"] = actual_data_hex(case, result)
            record["observed"] = {
                "status": result["status"],
                "status_name": result["status_name"],
                "ct_bits": result["ct_bits"],
                "ct": bytes_to_hex(result["ct"]),
                "tag_bits": result["tag_bits"],
                "tag": bytes_to_hex(result["tag"]),
                "pt_bits": result["pt_bits"],
                "pt": bytes_to_hex(result["pt"]),
            }

            if ok:
                total_pass += 1
                if args.verbose:
                    print(f"PASS g{case['_global_index']} {tuple_str(case)}")
            else:
                total_fail += 1
                print(f"FAIL g{case['_global_index']} {tuple_str(case)}: {detail}")

                if args.dump_debug_on_fail:
                    record["debug_dump"] = collect_debug_dump(args.port, args.timeout)

                if first_fail_payload is None:
                    first_fail_payload = {
                        "run_id": run_id,
                        "timestamp": datetime.now().isoformat(timespec="seconds"),
                        "global_index": case["_global_index"],
                        "tuple": case_tuple(case),
                        "case": case_record(case),
                        "observed": record["observed"],
                        "detail": detail,
                        "repeat_index": repeat_index,
                        "source_file": case["_source_file"],
                        "program_meta": program_meta,
                        "COM4_owner": com4_owner,
                        "debug_dump": record.get("debug_dump"),
                    }
                    if first_fail_json_path is not None:
                        write_json(first_fail_json_path, first_fail_payload)

                if args.stop_on_fail:
                    write_jsonl(jsonl_path, record)
                    summary = {
                        "run_id": run_id,
                        "bitstream_hash": bitstream_hash,
                        "git_commit": git_commit,
                        "rsp_hash": rsp_hash,
                        "pass": total_pass,
                        "fail": total_fail,
                        "first_fail_global_index": first_fail_payload["global_index"],
                        "first_fail_tuple": tuple_str(case),
                        "COM4_owner": com4_owner,
                    }
                    print_summary_table(summary)
                    write_summary_markdown(summary_md_path, summary)
                    sys.exit(1)

            write_jsonl(jsonl_path, record)

    summary = {
        "run_id": run_id,
        "bitstream_hash": bitstream_hash,
        "git_commit": git_commit,
        "rsp_hash": rsp_hash,
        "pass": total_pass,
        "fail": total_fail,
        "first_fail_global_index": first_fail_payload["global_index"] if first_fail_payload else "null",
        "first_fail_tuple": tuple_str_fields(first_fail_payload["tuple"]) if first_fail_payload else "null",
        "COM4_owner": com4_owner,
    }
    print_summary_table(summary)
    write_summary_markdown(summary_md_path, summary)

    if total_fail:
        sys.exit(1)


if __name__ == "__main__":
    main()
