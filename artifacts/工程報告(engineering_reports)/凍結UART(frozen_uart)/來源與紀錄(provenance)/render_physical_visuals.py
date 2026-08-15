from __future__ import annotations

import csv
from collections import Counter, defaultdict
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
import numpy as np


ROOT = Path(r"C:\project\FPGA2")
STAGING = ROOT / ".Xil" / "frozen_uart_visuals"
OUTPUT = (
    ROOT
    / "artifacts"
    / "工程報告(engineering_reports)"
    / "凍結UART(frozen_uart)"
    / "圖像(visuals)"
)
OUTPUT.mkdir(parents=True, exist_ok=True)


def read_rows(name: str) -> list[dict[str, str]]:
    with (STAGING / name).open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def coordinates(rows: list[dict[str, str]]) -> tuple[np.ndarray, np.ndarray]:
    points = [
        (float(row["grid_x"]), float(row["grid_y"]))
        for row in rows
        if row.get("grid_x") not in (None, "") and row.get("grid_y") not in (None, "")
    ]
    if not points:
        raise RuntimeError("Vivado export contained no physical grid coordinates")
    x, y = zip(*points)
    return np.asarray(x), np.asarray(y)


placement = read_rows("placement_data.csv")
px, py = coordinates(placement)
occupancy = Counter(zip(px.astype(int), py.astype(int)))
ox = np.asarray([point[0] for point in occupancy])
oy = np.asarray([point[1] for point in occupancy])
oc = np.asarray(list(occupancy.values()))

fig, ax = plt.subplots(figsize=(16, 10), dpi=180)
scatter = ax.scatter(
    ox,
    oy,
    c=oc,
    s=12 + 7 * np.sqrt(oc),
    cmap="viridis",
    norm=LogNorm(vmin=1, vmax=max(oc)),
    linewidths=0,
    alpha=0.88,
)
fig.colorbar(scatter, ax=ax, pad=0.01, label="Placed primitive cells per physical tile (log scale)")
ax.set_title("Frozen UART — Implemented Device Placement\nVivado 2021.1 routed DCP, xc7a100tcsg324-1")
ax.set_xlabel("Vivado device grid X")
ax.set_ylabel("Vivado device grid Y")
ax.grid(color="#d9d9d9", linewidth=0.35, alpha=0.6)
ax.set_aspect("equal", adjustable="box")
ax.text(
    0.01,
    0.01,
    f"{len(placement):,} placed primitive cells; generated from LOC/BEL/tile coordinates in the routed checkpoint",
    transform=ax.transAxes,
    fontsize=9,
    color="#444444",
)
fig.tight_layout()
fig.savefig(OUTPUT / "implemented_device_placement.png", bbox_inches="tight")
plt.close(fig)

route = read_rows("worst_setup_route_data.csv")
route_cells = read_rows("worst_setup_path_cells.csv")
rx, ry = coordinates(route)

fig, ax = plt.subplots(figsize=(16, 10), dpi=180)
ax.scatter(px, py, s=1.2, c="#c7c7c7", alpha=0.16, linewidths=0, label="All placed primitives")
grouped: dict[str, list[tuple[int, float, float]]] = defaultdict(list)
for row in route:
    if row.get("grid_x") in (None, "") or row.get("grid_y") in (None, ""):
        continue
    grouped[row["net"]].append(
        (int(row["node_index"]), float(row["grid_x"]), float(row["grid_y"]))
    )
colors = plt.cm.plasma(np.linspace(0.08, 0.92, max(1, len(grouped))))
for color, (net, points) in zip(colors, sorted(grouped.items())):
    points.sort()
    nx = [point[1] for point in points]
    ny = [point[2] for point in points]
    ax.plot(nx, ny, color=color, linewidth=1.8, alpha=0.85)
    ax.scatter(nx, ny, color=color, s=9, alpha=0.9, linewidths=0)
    ax.annotate(net, (nx[0], ny[0]), xytext=(4, 3), textcoords="offset points", fontsize=7, color=color)

cell_points = [
    (float(row["grid_x"]), float(row["grid_y"]))
    for row in route_cells
    if row.get("grid_x") not in (None, "") and row.get("grid_y") not in (None, "")
]
if cell_points:
    cx, cy = zip(*cell_points)
    ax.scatter(cx, cy, marker="s", s=70, facecolor="#00d4ff", edgecolor="#00394a", linewidth=0.8, label="Critical-path cells")

ax.set_title("Frozen UART — Worst Setup Path Routing Resources\nPost-route WNS path, Vivado 2021.1 routed DCP")
ax.set_xlabel("Vivado device grid X")
ax.set_ylabel("Vivado device grid Y")
ax.grid(color="#d9d9d9", linewidth=0.35, alpha=0.6)
ax.set_aspect("equal", adjustable="box")
route_margin_x = max(2.0, (float(rx.max()) - float(rx.min())) * 0.35)
route_margin_y = max(2.0, (float(ry.max()) - float(ry.min())) * 0.20)
ax.set_xlim(float(rx.min()) - route_margin_x, float(rx.max()) + route_margin_x)
ax.set_ylim(float(ry.min()) - route_margin_y, float(ry.max()) + route_margin_y)
ax.legend(loc="upper right", frameon=True)
ax.text(
    0.01,
    0.01,
    f"{len(grouped)} path nets; {len(route):,} routed nodes; cyan squares mark path cells",
    transform=ax.transAxes,
    fontsize=9,
    color="#444444",
)
fig.tight_layout()
fig.savefig(OUTPUT / "worst_setup_path_routing_resources.png")
plt.close(fig)
