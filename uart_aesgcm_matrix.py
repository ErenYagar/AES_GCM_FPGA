import argparse
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RSP_RUNNER = ROOT / "uart_aesgcm_rsp.py"
REGRESSION_ROOT = ROOT / "artifacts" / "regression"
DEFAULT_ENCRYPT_RSP = ROOT / "txt" / "gcmEncryptExtIV256.rsp"
DEFAULT_DECRYPT_RSP = ROOT / "txt" / "gcmDecrypt256.rsp"


MATRIX_MODES = {
    "fresh-encrypt-only": {
        "description": "Run the selected encrypt case(s) in fresh-program mode only.",
        "mode_filter": "enc",
        "target_mode_filter": "enc",
        "uses_fresh_program": True,
        "prelude": None,
    },
    "fresh-decrypt-only": {
        "description": "Run the selected decrypt case(s) in fresh-program mode only.",
        "mode_filter": "dec",
        "target_mode_filter": "dec",
        "uses_fresh_program": True,
        "prelude": None,
    },
    "fresh-encrypt-then-decrypt": {
        "description": "In one fresh session, run encrypt selection first, then decrypt selection.",
        "mode_filter": None,
        "target_mode_filter": "dec",
        "uses_fresh_program": True,
        "prelude": "enc",
    },
    "fresh-decrypt-then-decrypt": {
        "description": "In one fresh session, run decrypt selection immediately followed by decrypt selection.",
        "mode_filter": "dec",
        "target_mode_filter": "dec",
        "uses_fresh_program": True,
        "prelude": "dec",
    },
    "dirty-state-replay": {
        "description": "Replay a minimal prefix without reprogramming, then execute the selected target range.",
        "mode_filter": None,
        "target_mode_filter": "all",
        "uses_fresh_program": False,
        "prelude": "range",
    },
}


def normalize_path(path_str, default_name):
    REGRESSION_ROOT.mkdir(parents=True, exist_ok=True)
    if path_str:
        path = Path(path_str)
        if not path.is_absolute():
            path = REGRESSION_ROOT / path
    else:
        path = REGRESSION_ROOT / default_name
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def build_rsp_cmd(
    *,
    port,
    timeout,
    verbose,
    stop_on_fail,
    repeat,
    jsonl_log,
    first_fail_json,
    fresh_program_cmd,
    dump_debug_on_fail,
    summary_md,
    run_label,
    mode_filter="all",
    start_global_index=None,
    end_global_index=None,
    global_index=None,
    files=None,
):
    cmd = ["python", str(RSP_RUNNER), "--port", port, "--timeout", str(timeout)]
    if verbose:
        cmd.append("--verbose")
    if stop_on_fail:
        cmd.append("--stop-on-fail")
    if mode_filter != "all":
        cmd.extend(["--mode-filter", mode_filter])
    if repeat is not None:
        cmd.extend(["--repeat", str(repeat)])
    if jsonl_log is not None:
        cmd.extend(["--jsonl-log", str(jsonl_log)])
    if first_fail_json is not None:
        cmd.extend(["--first-fail-json", str(first_fail_json)])
    if summary_md is not None:
        cmd.extend(["--summary-md", str(summary_md)])
    if run_label is not None:
        cmd.extend(["--run-label", run_label])
    if fresh_program_cmd:
        cmd.extend(["--fresh-program-cmd", fresh_program_cmd])
    if dump_debug_on_fail:
        cmd.append("--dump-debug-on-fail")
    if global_index is not None:
        cmd.extend(["--global-index", str(global_index)])
    if start_global_index is not None:
        cmd.extend(["--start-global-index", str(start_global_index)])
    if end_global_index is not None:
        cmd.extend(["--end-global-index", str(end_global_index)])
    if files:
        cmd.extend(str(Path(f)) for f in files)
    return cmd


def run_and_capture(cmd, log_path):
    proc = subprocess.run(cmd, capture_output=True, text=True)
    log_path.write_text(proc.stdout + proc.stderr, encoding="utf-8")
    return proc


def parse_summary_markdown(path):
    if not path.exists():
        return {}
    lines = [line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(lines) < 3:
        return {}
    headers = [part.strip() for part in lines[0].strip("|").split("|")]
    values = [part.strip() for part in lines[2].strip("|").split("|")]
    return dict(zip(headers, values))


def emit_matrix_summary(path, payload):
    path.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description="Matrix runner for board-level AES-GCM RSP verification.")
    parser.add_argument("--matrix-mode", choices=sorted(MATRIX_MODES.keys()), required=True)
    parser.add_argument("--port", default="COM4")
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument("--repeat", type=int, default=1)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--stop-on-fail", action="store_true")
    parser.add_argument("--dump-debug-on-fail", action="store_true")
    parser.add_argument("--fresh-program-cmd", default=None)
    parser.add_argument("--global-index", type=int, default=None)
    parser.add_argument("--start-global-index", type=int, default=None)
    parser.add_argument("--end-global-index", type=int, default=None)
    parser.add_argument("--prelude-start-global-index", type=int, default=None)
    parser.add_argument("--prelude-end-global-index", type=int, default=None)
    parser.add_argument("--output-prefix", default=None)
    parser.add_argument("files", nargs="*")
    args = parser.parse_args()

    mode_cfg = MATRIX_MODES[args.matrix_mode]
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_prefix = args.output_prefix or f"{timestamp}_{args.matrix_mode}"

    files = [Path(p) for p in args.files] if args.files else [DEFAULT_ENCRYPT_RSP, DEFAULT_DECRYPT_RSP]
    matrix_log = normalize_path(None, f"{output_prefix}.log")
    matrix_summary = normalize_path(None, f"{output_prefix}_matrix.json")

    phases = []

    if mode_cfg["prelude"] == "enc":
        prelude_summary = normalize_path(None, f"{output_prefix}_prelude_enc_summary.md")
        phases.append(
            {
                "label": "prelude_encrypt",
                "cmd": build_rsp_cmd(
                    port=args.port,
                    timeout=args.timeout,
                    verbose=args.verbose,
                    stop_on_fail=False,
                    repeat=1,
                    jsonl_log=normalize_path(None, f"{output_prefix}_prelude_enc.jsonl"),
                    first_fail_json=normalize_path(None, f"{output_prefix}_prelude_enc_first_fail.json"),
                    summary_md=prelude_summary,
                    run_label=f"{output_prefix}_prelude_enc",
                    mode_filter="enc",
                    fresh_program_cmd=args.fresh_program_cmd if mode_cfg["uses_fresh_program"] else None,
                    dump_debug_on_fail=args.dump_debug_on_fail,
                    global_index=args.global_index,
                    files=files,
                ),
                "summary_path": prelude_summary,
            }
        )

    if mode_cfg["prelude"] == "dec":
        prelude_summary = normalize_path(None, f"{output_prefix}_prelude_dec_summary.md")
        phases.append(
            {
                "label": "prelude_decrypt",
                "cmd": build_rsp_cmd(
                    port=args.port,
                    timeout=args.timeout,
                    verbose=args.verbose,
                    stop_on_fail=False,
                    repeat=1,
                    jsonl_log=normalize_path(None, f"{output_prefix}_prelude_dec.jsonl"),
                    first_fail_json=normalize_path(None, f"{output_prefix}_prelude_dec_first_fail.json"),
                    summary_md=prelude_summary,
                    run_label=f"{output_prefix}_prelude_dec",
                    mode_filter="dec",
                    fresh_program_cmd=args.fresh_program_cmd if mode_cfg["uses_fresh_program"] else None,
                    dump_debug_on_fail=args.dump_debug_on_fail,
                    global_index=args.global_index,
                    files=files,
                ),
                "summary_path": prelude_summary,
            }
        )

    if mode_cfg["prelude"] == "range":
        if args.prelude_start_global_index is None or args.prelude_end_global_index is None:
            raise ValueError("dirty-state-replay requires --prelude-start-global-index and --prelude-end-global-index")
        prelude_summary = normalize_path(None, f"{output_prefix}_prelude_summary.md")
        phases.append(
            {
                "label": "dirty_prelude",
                "cmd": build_rsp_cmd(
                    port=args.port,
                    timeout=args.timeout,
                    verbose=args.verbose,
                    stop_on_fail=False,
                    repeat=1,
                    jsonl_log=normalize_path(None, f"{output_prefix}_prelude.jsonl"),
                    first_fail_json=normalize_path(None, f"{output_prefix}_prelude_first_fail.json"),
                    summary_md=prelude_summary,
                    run_label=f"{output_prefix}_prelude",
                    mode_filter="all",
                    fresh_program_cmd=args.fresh_program_cmd if mode_cfg["uses_fresh_program"] else None,
                    dump_debug_on_fail=args.dump_debug_on_fail,
                    start_global_index=args.prelude_start_global_index,
                    end_global_index=args.prelude_end_global_index,
                    files=files,
                ),
                "summary_path": prelude_summary,
            }
        )

    target_summary = normalize_path(None, f"{output_prefix}_target_summary.md")
    phases.append(
        {
            "label": "target",
            "cmd": build_rsp_cmd(
                port=args.port,
                timeout=args.timeout,
                verbose=args.verbose,
                stop_on_fail=args.stop_on_fail,
                repeat=args.repeat,
                jsonl_log=normalize_path(None, f"{output_prefix}_target.jsonl"),
                first_fail_json=normalize_path(None, f"{output_prefix}_target_first_fail.json"),
                summary_md=target_summary,
                run_label=f"{output_prefix}_target",
                mode_filter=mode_cfg["target_mode_filter"],
                fresh_program_cmd=args.fresh_program_cmd if mode_cfg["uses_fresh_program"] and not phases else None,
                dump_debug_on_fail=args.dump_debug_on_fail,
                global_index=args.global_index,
                start_global_index=args.start_global_index,
                end_global_index=args.end_global_index,
                files=files,
            ),
            "summary_path": target_summary,
        }
    )

    run_payload = {
        "matrix_mode": args.matrix_mode,
        "description": mode_cfg["description"],
        "phases": [],
    }

    consolidated_log = []

    for phase in phases:
        cmd = phase["cmd"]
        if cmd is None:
            continue
        phase_log_path = normalize_path(None, f"{output_prefix}_{phase['label']}.log")
        proc = run_and_capture(cmd, phase_log_path)
        consolidated_log.append(f"### {phase['label']}\n")
        consolidated_log.append(phase_log_path.read_text(encoding="utf-8"))
        phase_summary = parse_summary_markdown(phase["summary_path"])
        run_payload["phases"].append(
            {
                "label": phase["label"],
                "command": cmd,
                "exit_code": proc.returncode,
                "summary": phase_summary,
                "log_path": str(phase_log_path),
            }
        )
        if proc.returncode != 0 and phase["label"] != "target":
            emit_matrix_summary(matrix_summary, run_payload)
            matrix_log.write_text("\n".join(consolidated_log), encoding="utf-8")
            sys.exit(proc.returncode)

    matrix_log.write_text("\n".join(consolidated_log), encoding="utf-8")
    emit_matrix_summary(matrix_summary, run_payload)

    target_exit = run_payload["phases"][-1]["exit_code"] if run_payload["phases"] else 0
    sys.exit(target_exit)


if __name__ == "__main__":
    main()
