import argparse
import csv
import json
import os
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
    clean_hex,
    run_transaction_fields,
)


ROOT = Path(__file__).resolve().parent
REGRESSION_DIR = ROOT / "artifacts" / "regression"
PROFILE_SUMMARY_MD = REGRESSION_DIR / "profile_summary.md"
PROFILE_SUMMARY_CSV = REGRESSION_DIR / "profile_summary.csv"


def load_profile(path: Path):
    records = []
    with path.open("r", encoding="utf-8") as handle:
        for lineno, raw_line in enumerate(handle, start=1):
            line = raw_line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{lineno}: invalid JSON: {exc}") from exc
            records.append(record)
    if not records:
        raise ValueError(f"{path}: no profile records found")
    return records


def ensure_profile_schema(record, source: Path):
    required = [
        "profile",
        "case_id",
        "mode",
        "key",
        "iv",
        "aad",
        "pt",
        "ct_expected",
        "tag_expected",
        "tag_bits",
        "aad_fields",
        "notes",
    ]
    missing = [field for field in required if field not in record]
    if missing:
        raise ValueError(f"{source}: case_id={record.get('case_id')} missing fields: {missing}")


def expected_status_code(case):
    mapping = {
        "ENC_OK": STAT_ENC_OK,
        "DEC_OK": STAT_DEC_OK,
        "AUTH_FAIL": STAT_AUTH_FAIL,
    }
    status = case.get("expected_status", "ENC_OK" if case["mode"] == "enc" else "DEC_OK")
    if status not in mapping:
        raise ValueError(f"Unsupported expected_status {status} in case {case['case_id']}")
    return mapping[status], status


def current_timestamp():
    return datetime.now().isoformat(timespec="seconds")


def make_run_id(profile_path: Path):
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return f"{stamp}_{profile_path.stem}"


def kill_stale_com4_processes(port):
    script = rf"""
$port = '{port}'
$self = {os.getpid()}
$ps = $PID
$targets = Get-CimInstance Win32_Process | Where-Object {{
    $_.ProcessId -ne $self -and
    $_.ProcessId -ne $ps -and
    (
        ($_.Name -match '^(python|pythonw|py)(\.exe)?$' -and $_.CommandLine -ne $null) -or
        ($_.Name -match '^(powershell|pwsh)(\.exe)?$' -and $_.CommandLine -ne $null)
    ) -and (
        $_.CommandLine -match 'uart_aesgcm_host\.py' -or
        $_.CommandLine -match 'uart_aesgcm_rsp\.py' -or
        $_.CommandLine -match 'uart_aesgcm_profile\.py' -or
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
        raise RuntimeError(f"Failed to clean COM4 owners: {proc.stderr.strip()}")
    payload = proc.stdout.strip()
    if not payload:
        return []
    owners = json.loads(payload)
    if isinstance(owners, dict):
        owners = [owners]
    return owners


def verify_com4_openable(port, timeout):
    handle = serial.Serial(port, 115200, timeout=timeout)
    handle.close()


def append_jsonl(path: Path, record):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, sort_keys=True) + "\n")


def append_summary_csv(path: Path, row):
    path.parent.mkdir(parents=True, exist_ok=True)
    write_header = not path.exists()
    fieldnames = [
        "run_id",
        "profile",
        "cases_total",
        "normal_pass_cases",
        "tamper_reject_cases",
        "board_failures",
        "repeat",
        "log_path",
    ]
    with path.open("a", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        if write_header:
            writer.writeheader()
        writer.writerow(row)


def append_summary_md(path: Path, row):
    path.parent.mkdir(parents=True, exist_ok=True)
    header = (
        "| run_id | profile | cases_total | normal_pass_cases | "
        "tamper_reject_cases | board_failures | repeat | log_path |\n"
        "|---|---|---:|---:|---:|---:|---:|---|\n"
    )
    line = (
        f"| {row['run_id']} | {row['profile']} | {row['cases_total']} | "
        f"{row['normal_pass_cases']} | {row['tamper_reject_cases']} | "
        f"{row['board_failures']} | {row['repeat']} | {row['log_path']} |\n"
    )
    if not path.exists():
        path.write_text(header + line, encoding="utf-8")
    else:
        with path.open("a", encoding="utf-8") as handle:
            handle.write(line)


def case_inputs(case):
    mode = case["mode"]
    if mode == "enc":
        return {
            "mode": "enc",
            "aad_hex": case["aad"],
            "pt_hex": case["pt"],
            "ct_hex": "",
            "tag_hex": "",
        }
    return {
        "mode": "dec",
        "aad_hex": case["aad"],
        "pt_hex": "",
        "ct_hex": case.get("ct_input", case["ct_expected"]),
        "tag_hex": case.get("tag_input", case["tag_expected"]),
    }


def classify_case(case):
    return "tamper" if case.get("expected_status") == "AUTH_FAIL" else "normal"


def evaluate_case(port, timeout, case):
    expected_status_code_value, expected_status_name = expected_status_code(case)
    inputs = case_inputs(case)
    result = run_transaction_fields(
        port=port,
        timeout=timeout,
        mode=inputs["mode"],
        key_hex=case["key"],
        iv_hex=case["iv"],
        aad_hex=inputs["aad_hex"],
        pt_hex=inputs["pt_hex"],
        ct_hex=inputs["ct_hex"],
        tag_hex=inputs["tag_hex"],
        tag_bits=int(case["tag_bits"]),
    )

    pass_fail = "FAIL"
    if case["mode"] == "enc":
        pass_fail = (
            "PASS"
            if result["status"] == expected_status_code_value
            and bytes_to_hex(result["ct"]) == clean_hex(case["ct_expected"])
            and result["tag_bits"] == int(case["tag_bits"])
            and bytes_to_hex(result["tag"]) == clean_hex(case["tag_expected"])
            else "FAIL"
        )
    elif expected_status_code_value == STAT_DEC_OK:
        pass_fail = (
            "PASS"
            if result["status"] == expected_status_code_value
            and bytes_to_hex(result["pt"]) == clean_hex(case["pt"])
            else "FAIL"
        )
    else:
        pass_fail = "PASS" if result["status"] == expected_status_code_value else "FAIL"

    actual_ct = bytes_to_hex(result["ct"]) if case["mode"] == "enc" else clean_hex(inputs["ct_hex"])
    actual_tag = bytes_to_hex(result["tag"]) if case["mode"] == "enc" else clean_hex(inputs["tag_hex"])

    record = {
        "run_id": None,
        "profile": case["profile"],
        "case_id": case["case_id"],
        "mode": case["mode"],
        "iv": clean_hex(case["iv"]),
        "aad": clean_hex(case["aad"]),
        "pt_len": len(clean_hex(case["pt"])) // 2,
        "tag_bits": int(case["tag_bits"]),
        "expected_status": expected_status_name,
        "actual_status": result["status_name"],
        "expected_ct": clean_hex(case["ct_expected"]),
        "actual_ct": actual_ct,
        "expected_tag": clean_hex(case["tag_expected"]),
        "actual_tag": actual_tag,
        "pass_fail": pass_fail,
        "latency_ms": result["latency_ms"],
        "tx_frame_hash": result["tx_frame_hash"],
        "rx_frame_hash": result["rx_frame_hash"],
        "tamper_kind": case.get("tamper_kind", ""),
        "notes": case.get("notes", ""),
    }

    return record


def main():
    parser = argparse.ArgumentParser(description="Run protocol-inspired AES-GCM packet profiles over UART.")
    parser.add_argument("--port", default="COM4")
    parser.add_argument("--profile", required=True)
    parser.add_argument("--max-cases", type=int, default=None)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--stop-on-fail", action="store_true")
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=5.0)
    args = parser.parse_args()

    if args.repeat < 1:
        raise ValueError("--repeat must be >= 1")

    profile_path = Path(args.profile)
    records = load_profile(profile_path)
    for record in records:
        ensure_profile_schema(record, profile_path)

    if args.max_cases is not None:
        records = records[: args.max_cases]

    run_id = make_run_id(profile_path)
    log_path = REGRESSION_DIR / f"{run_id}.jsonl"

    total_normal_pass = 0
    total_tamper_pass = 0
    total_failures = 0

    for repeat_index in range(1, args.repeat + 1):
        kill_stale_com4_processes(args.port)
        verify_com4_openable(args.port, args.timeout)

        for case in records:
            started = time.time()
            try:
                record = evaluate_case(args.port, args.timeout, case)
            except Exception as exc:
                record = {
                    "run_id": run_id,
                    "profile": case["profile"],
                    "case_id": case["case_id"],
                    "mode": case["mode"],
                    "iv": clean_hex(case["iv"]),
                    "aad": clean_hex(case["aad"]),
                    "pt_len": len(clean_hex(case["pt"])) // 2,
                    "tag_bits": int(case["tag_bits"]),
                    "expected_status": case.get("expected_status", ""),
                    "actual_status": f"EXCEPTION:{type(exc).__name__}",
                    "expected_ct": clean_hex(case["ct_expected"]),
                    "actual_ct": "",
                    "expected_tag": clean_hex(case["tag_expected"]),
                    "actual_tag": "",
                    "pass_fail": "FAIL",
                    "latency_ms": int((time.time() - started) * 1000),
                    "tx_frame_hash": "",
                    "rx_frame_hash": "",
                    "tamper_kind": case.get("tamper_kind", ""),
                    "notes": f"{case.get('notes', '')} exception={exc}".strip(),
                }

            record["run_id"] = run_id
            record["repeat_index"] = repeat_index
            record["repeat_total"] = args.repeat
            record["timestamp"] = current_timestamp()
            append_jsonl(log_path, record)

            if record["pass_fail"] == "PASS":
                if classify_case(case) == "tamper":
                    total_tamper_pass += 1
                else:
                    total_normal_pass += 1
            else:
                total_failures += 1

            if args.verbose:
                print(
                    f"{record['pass_fail']} {record['case_id']} "
                    f"mode={record['mode']} expected={record['expected_status']} actual={record['actual_status']}"
                )

            if args.stop_on_fail and record["pass_fail"] == "FAIL":
                break

        if args.stop_on_fail and total_failures > 0:
            break

    summary_row = {
        "run_id": run_id,
        "profile": profile_path.name,
        "cases_total": len(records) * args.repeat,
        "normal_pass_cases": total_normal_pass,
        "tamper_reject_cases": total_tamper_pass,
        "board_failures": total_failures,
        "repeat": args.repeat,
        "log_path": str(log_path),
    }
    append_summary_csv(PROFILE_SUMMARY_CSV, summary_row)
    append_summary_md(PROFILE_SUMMARY_MD, summary_row)

    print(json.dumps(summary_row, indent=2))
    if total_failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
