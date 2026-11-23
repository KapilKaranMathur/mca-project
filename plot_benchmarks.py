import csv
import sys
from pathlib import Path
import matplotlib.pyplot as plt

csv_path = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
output_dir.mkdir(parents=True, exist_ok=True)

with csv_path.open(newline="") as f:
    rows = list(csv.DictReader(f))

data = sorted(
    [r for r in rows if r["operation"].strip() == "ADD"],
    key=lambda r: int(r["elements"])
)

if not data:
    raise ValueError("ADD results not found in CSV")

labels = [r["elements"] for r in data]
x = list(range(len(data)))
width = 0.35

def plot_comparison(scalar_key, simd_key, title, ylabel, filename):
    scalar = [float(r[scalar_key]) for r in data]
    simd = [float(r[simd_key]) for r in data]

    fig, ax = plt.subplots(figsize=(10, 6))

    ax.bar([i - width/2 for i in x], scalar, width, label="Scalar")
    ax.bar([i + width/2 for i in x], simd, width, label="SIMD")

    ax.set_xticks(x, labels)
    ax.set_xlabel("Number of Elements")
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.legend()
    ax.grid(axis="y", alpha=0.3)

    fig.tight_layout()
    fig.savefig(output_dir / filename, dpi=200)
    plt.close(fig)

    print(f"Created: {filename}")

plot_comparison(
    "scalar_execute_cycles",
    "simd_execute_cycles",
    "Scalar vs SIMD Execution Cycles",
    "Clock Cycles",
    "execution_cycles.png"
)

plot_comparison(
    "scalar_total_cycles",
    "simd_total_cycles",
    "Scalar vs SIMD Total Cycles",
    "Clock Cycles",
    "total_cycles.png"
)

plot_comparison(
    "scalar_throughput_elem_per_cycle",
    "simd_throughput_elem_per_cycle",
    "Scalar vs SIMD Throughput",
    "Elements per Cycle",
    "execution_throughput.png"
)

print("SUCCESS: All 3 graphs generated!")
