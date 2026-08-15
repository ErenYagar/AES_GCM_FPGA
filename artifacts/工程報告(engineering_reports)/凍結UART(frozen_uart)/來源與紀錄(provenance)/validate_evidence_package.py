from __future__ import annotations

import hashlib
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image


ROOT = Path(r"C:\project\FPGA2")
PACKAGE = ROOT / "artifacts" / "工程報告(engineering_reports)" / "凍結UART(frozen_uart)"
REPORTS = PACKAGE / "報告(reports)"
VISUALS = PACKAGE / "圖像(visuals)"
PROVENANCE = PACKAGE / "來源與紀錄(provenance)"
CHECKPOINT = PACKAGE / "檢查點(checkpoint)" / "fpga_top_arty_a7_uart_routed.dcp"
INDEX = PACKAGE / "工程報告總覽(engineering_report_index).md"

passes: list[str] = []
failures: list[str] = []


def check(condition: bool, label: str) -> None:
    (passes if condition else failures).append(label)


required_reports = [
    "timing_summary.rpt",
    "critical_paths_setup_top10.rpt",
    "critical_paths_hold_top10.rpt",
    "utilization.rpt",
    "utilization_hierarchical.rpt",
    "route_status.rpt",
    "drc.rpt",
    "methodology.rpt",
    "design_analysis_timing_setup.rpt",
    "design_analysis_timing_hold.rpt",
    "design_analysis_complexity.rpt",
    "design_analysis_congestion.rpt",
    "design_analysis_logic_levels.rpt",
    "design_analysis_qor_summary.rpt",
    "qor_assessment.rpt",
    "clock_interaction.rpt",
    "cdc.rpt",
    "check_timing.rpt",
    "clocks.rpt",
    "clock_networks.rpt",
    "power.rpt",
]
for name in required_reports:
    path = REPORTS / name
    check(path.is_file() and path.stat().st_size > 0, f"report exists and is non-empty: {name}")

timing = (REPORTS / "timing_summary.rpt").read_text(errors="replace")
timing_match = re.search(
    r"\n\s*7\.376\s+0\.000\s+0\s+58921\s+0\.016\s+0\.000\s+0\s+58921\s+3\.000\s+0\.000\s+0\s+22180",
    timing,
)
check(timing_match is not None, "timing signoff row is WNS 7.376, TNS 0, WHS 0.016, THS 0 with no failing endpoints")
check("All user specified timing constraints are met." in timing, "Vivado reports all timing constraints met")

route = (REPORTS / "route_status.rpt").read_text(errors="replace")
check("# of fully routed nets............. :       42484" in route, "42,484 routable nets are fully routed")
check("# of nets with routing errors.......... :           0" in route, "route status has zero routing errors")

drc = (REPORTS / "drc.rpt").read_text(errors="replace")
check("Design State : Fully Routed" in drc and "Violations found: 0" in drc, "DRC is fully routed with zero violations")

checkpoint_validation = (PROVENANCE / "checkpoint_validation.txt").read_text(errors="replace")
for entry in [
    "checkpoint_open=PASS",
    "vivado_version=2021.1",
    "part=xc7a100tcsg324-1",
    "setup_wns_ns=7.376",
    "hold_whs_ns=0.016",
    "drc_violation_count=0",
    "unrouted_net_count=0",
    "clock=sys_clk_pin,period_ns=10.000",
    "clock=core_clk,period_ns=40.000",
]:
    check(entry in checkpoint_validation, f"checkpoint re-open validation: {entry}")
check(CHECKPOINT.is_file() and CHECKPOINT.stat().st_size > 1_000_000, "routed DCP exists and is non-trivial")
check(INDEX.is_file() and INDEX.stat().st_size > 0, "engineering report index exists and is non-empty")

for report in REPORTS.glob("*.rpt"):
    text = report.read_text(errors="replace")
    if "Tool Version" in text:
        check("Vivado v.2021.1" in text, f"Vivado version matches in {report.name}")
    if "| Design       :" in text or "| Design      :" in text:
        check("fpga_top_arty_a7_uart" in text, f"design name matches in {report.name}")
    if "| Device" in text:
        check("7a100t" in text.lower(), f"device family matches in {report.name}")

required_svgs = [
    "elaborated_rtl_top.svg",
    "elaborated_aes_gcm_core.svg",
    "synthesized_top_netlist.svg",
    "synthesized_crypto_datapath.svg",
    "worst_setup_critical_path.svg",
]
for name in required_svgs:
    path = VISUALS / name
    try:
        ET.parse(path)
        check(path.stat().st_size > 0, f"SVG parses and is non-empty: {name}")
    except Exception:
        check(False, f"SVG parses and is non-empty: {name}")

for name in ["implemented_device_placement.png", "worst_setup_path_routing_resources.png"]:
    path = VISUALS / name
    try:
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            check(image.width >= 1200 and image.height >= 800, f"PNG verifies at report resolution: {name}")
    except Exception:
        check(False, f"PNG verifies at report resolution: {name}")

manifest_ok = True
for line in (PROVENANCE / "source_manifest.sha256").read_text().splitlines():
    expected, relative = line.split("  ", 1)
    actual = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
    manifest_ok &= actual == expected
check(manifest_ok, "all RTL/XDC SHA-256 values still match the build manifest")

old_timing = (ROOT / "artifacts" / "fpga_top_arty_a7_uart_fixed_timing.rpt").read_text(errors="replace")
old_util = (ROOT / "artifacts" / "fpga_top_arty_a7_uart_fixed_util.rpt").read_text(errors="replace")
old_drc = (ROOT / "artifacts" / "fpga_top_arty_a7_uart_fixed_drc.rpt").read_text(errors="replace")
new_util = (REPORTS / "utilization.rpt").read_text(errors="replace")
for token in ["7.376", "0.016", "58921"]:
    check(token in timing and token in old_timing, f"new/frozen timing parity token: {token}")
for token in [
    "| Slice LUTs              | 26716",
    "| Slice Registers         | 21970",
    "| Block RAM Tile    | 52.5",
    "| DSPs      |    0",
]:
    check(token in new_util and token in old_util, f"new/frozen utilization parity: {token.strip()}")
check("Violations found: 0" in drc and "Violations found: 0" in old_drc, "new/frozen DRC parity: zero violations")

for pattern in ("*.bit", "*.bin", "*.ltx"):
    check(not any(PACKAGE.rglob(pattern)), f"package contains no generated {pattern} hardware image")

tracked_diff = subprocess.run(
    ["git", "diff", "--name-only", "--", "rtl", "arty_a7_100t_uart.xdc", "artifacts/scripts", "txt/profiles"],
    cwd=ROOT,
    check=True,
    capture_output=True,
    text=True,
).stdout.strip()
check(tracked_diff == "", "no tracked RTL/XDC/existing script/profile changes")

git_status_after = subprocess.run(
    ["git", "status", "--short"],
    cwd=ROOT,
    check=True,
    capture_output=True,
    text=True,
).stdout
(PROVENANCE / "git_status_after.txt").write_text(git_status_after, encoding="utf-8")

result = "PASS" if not failures else "FAIL"
lines = [
    f"validation_result={result}",
    f"passed_checks={len(passes)}",
    f"failed_checks={len(failures)}",
    "",
    "[PASS]",
    *passes,
]
if failures:
    lines.extend(["", "[FAIL]", *failures])
(PROVENANCE / "validation_summary.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

if failures:
    raise SystemExit("Evidence package validation failed: " + "; ".join(failures))
print(f"Evidence package validation passed ({len(passes)} checks).")
