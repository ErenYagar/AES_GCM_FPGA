from pathlib import Path
import re
import subprocess


ROOT = Path(r"C:\project\FPGA2")
PACKAGE = ROOT / "artifacts" / "工程報告(engineering_reports)" / "凍結UART警告修正(frozen_uart_warning_fixed)"
REPORTS = PACKAGE / "報告(reports)"
PROVENANCE = PACKAGE / "來源與紀錄(provenance)"

methodology = (REPORTS / "methodology.rpt").read_text(errors="replace")
timing = (REPORTS / "timing_summary.rpt").read_text(errors="replace")
route = (REPORTS / "route_status.rpt").read_text(errors="replace")
drc = (REPORTS / "drc.rpt").read_text(errors="replace")
check_timing = (REPORTS / "check_timing.rpt").read_text(errors="replace")
cdc = (REPORTS / "cdc.rpt").read_text(errors="replace")
build_result = (PROVENANCE / "build_result.txt").read_text(errors="replace")

checks = {
    "methodology_violations_zero": "Violations found: 0" in methodology,
    "timing_2_removed": "TIMING-2" not in methodology,
    "timing_4_removed": "TIMING-4" not in methodology,
    "timing_18_removed": "TIMING-18" not in methodology,
    "setup_hold_pass": bool(re.search(r"7\.376\s+0\.000\s+0\s+58921\s+0\.016\s+0\.000\s+0\s+58921", timing)),
    "timing_constraints_met": "All user specified timing constraints are met." in timing,
    "routing_fully_routed": "# of fully routed nets............. :       42484" in route,
    "routing_errors_zero": "# of nets with routing errors.......... :           0" in route,
    "drc_violations_zero": "Violations found: 0" in drc,
    "no_unexcepted_input_delay_gaps": "There are 0 input ports with no input delay specified." in check_timing,
    "no_unexcepted_output_delay_gaps": "There are 0 ports with no output delay specified." in check_timing,
    "generated_core_clock_25mhz": "clock=core_clk_mmcm,period_ns=40.000" in build_result,
    "system_clock_100mhz": "clock=sys_clk_pin,period_ns=10.000" in build_result,
}

rtl_diff = subprocess.run(
    ["git", "diff", "--name-only", "--", "rtl"],
    cwd=ROOT,
    check=True,
    capture_output=True,
    text=True,
).stdout.strip()
checks["rtl_unchanged"] = rtl_diff == ""

cdc_counts = {}
for cdc_id in ("CDC-1", "CDC-2", "CDC-13"):
    match = re.search(rf"^{cdc_id}\s+\S+\s+(\d+)\s+", cdc, re.MULTILINE)
    cdc_counts[cdc_id] = int(match.group(1)) if match else 0

constraint_result = "PASS" if all(checks.values()) else "FAIL"
cdc_result = "REQUIRES_RTL_FIX" if sum(cdc_counts.values()) else "PASS"

lines = [
    f"constraint_warning_fix={constraint_result}",
    f"cdc_signoff={cdc_result}",
    f"cdc_1_count={cdc_counts['CDC-1']}",
    f"cdc_2_count={cdc_counts['CDC-2']}",
    f"cdc_13_count={cdc_counts['CDC-13']}",
    "",
]
lines.extend(f"{name}={'PASS' if passed else 'FAIL'}" for name, passed in checks.items())
(PROVENANCE / "validation_summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

if constraint_result != "PASS":
    raise SystemExit("Constraint warning fix validation failed")
print(f"Constraint warning fix passed; CDC still requires RTL ({cdc_counts}).")
