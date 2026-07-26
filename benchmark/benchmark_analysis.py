#!/usr/bin/env python3
import argparse
import csv
import glob
import os
import sys
from collections import defaultdict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter, NullFormatter

PARAM_COLUMNS = ["threads", "flights", "customers"]
VALUE_COLUMN = "time_ms"
OUTDIR = "plots"


def find_results_dirs():
    dirs = []
    for entry in sorted(os.listdir(".")):
        if os.path.isdir(entry) and glob.glob(os.path.join(entry, "*.csv")):
            dirs.append(entry)
    return dirs


def load_csv(path):
    rows = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for raw in reader:
            row = {}
            for key, val in raw.items():
                if key is None or val is None or val == "":
                    continue
                try:
                    row[key] = float(val)
                except ValueError:
                    row[key] = val
            rows.append(row)
    return rows


def mean(xs):
    return sum(xs) / len(xs)


def stddev(xs):
    if len(xs) < 2:
        return 0.0
    m = mean(xs)
    return (sum((x - m) ** 2 for x in xs) / (len(xs) - 1)) ** 0.5


def summarize(rows):
    distinct = {}
    for col in PARAM_COLUMNS:
        vals = {row[col] for row in rows if col in row}
        if vals:
            distinct[col] = vals

    varying = {c: v for c, v in distinct.items() if len(v) > 1}
    fixed = {c: next(iter(v)) for c, v in distinct.items() if len(v) == 1}

    if varying:
        x_column = max(varying, key=lambda c: len(varying[c]))
    else:
        x_column = next(iter(distinct)) if distinct else PARAM_COLUMNS[0]
        fixed.pop(x_column, None)

    covarying = [
        c
        for c in varying
        if c != x_column
        and all(row.get(c) == row.get(x_column) for row in rows)
    ]

    grouped = defaultdict(list)
    for row in rows:
        if x_column in row and VALUE_COLUMN in row:
            grouped[row[x_column]].append(row[VALUE_COLUMN])

    points = [
        (x, mean(times), stddev(times)) for x, times in sorted(grouped.items())
    ]
    return x_column, covarying, fixed, points


def format_fixed(fixed):
    if not fixed:
        return ""
    parts = []
    for col, val in fixed.items():
        parts.append(f"{col}={int(val) if float(val).is_integer() else val}")
    return "  (" + ", ".join(parts) + ")"


def spans_orders_of_magnitude(values, factor=100):
    positive = [v for v in values if v > 0]
    if len(positive) < 2:
        return False
    return max(positive) / min(positive) >= factor


def _plain_int(v, _pos=None):
    if float(v).is_integer():
        return f"{int(v):d}"
    return f"{v:g}"


def _thin_log_ticks(values, max_ticks=12):
    values = sorted(set(values))
    if len(values) <= max_ticks:
        return values
    import math

    lo, hi = math.log(values[0]), math.log(values[-1])
    chosen = []
    for i in range(max_ticks):
        target = lo + (hi - lo) * i / (max_ticks - 1)
        nearest = min(values, key=lambda x: abs(math.log(x) - target))
        if nearest not in chosen:
            chosen.append(nearest)
    return chosen


def _use_plain_log_ticks(axis, data_values):
    if data_values:
        axis.set_ticks(_thin_log_ticks(data_values))
    axis.set_major_formatter(FuncFormatter(_plain_int))
    axis.set_minor_formatter(NullFormatter())


def plot_experiment(experiment, per_dir_summary):
    fig, ax = plt.subplots(figsize=(8, 5))

    x_columns = set()
    all_x = []
    all_y = []
    for label, (x_column, covarying, fixed, points) in sorted(
        per_dir_summary.items()
    ):
        if not points:
            continue
        x_columns.add(" = ".join([x_column, *covarying]))
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        es = [p[2] for p in points]
        all_x.extend(xs)
        all_y.extend(ys)
        if len(xs) <= 24:
            ax.errorbar(
                xs,
                ys,
                yerr=es,
                marker="o",
                markersize=4,
                linewidth=1.5,
                alpha=0.9,
                capsize=3,
                elinewidth=1,
                label=label,
            )
        else:
            (line,) = ax.plot(xs, ys, linewidth=1.5, alpha=0.9, label=label)
            lo = [y - e for y, e in zip(ys, es)]
            hi = [y + e for y, e in zip(ys, es)]
            ax.fill_between(
                xs, lo, hi, color=line.get_color(), alpha=0.2, linewidth=0
            )

    if not all_x:
        plt.close(fig)
        return None

    x_label = x_columns.pop() if len(x_columns) == 1 else "parameter"

    fixed_note = ""
    for _, (_, _, fixed, points) in per_dir_summary.items():
        if points:
            fixed_note = format_fixed(fixed)
            break

    if spans_orders_of_magnitude(all_x):
        ax.set_xscale("log")
        _use_plain_log_ticks(ax.xaxis, sorted(set(all_x)))
    if spans_orders_of_magnitude(all_y):
        ax.set_yscale("log")
        _use_plain_log_ticks(ax.yaxis, None)

    ax.set_xlabel(x_label)
    ax.set_ylabel("mean time (ms)")
    ax.set_title(f"{experiment}: time vs {x_label}{fixed_note}")
    ax.grid(True, which="both", linestyle=":", alpha=0.5)
    ax.legend(title="dataset")
    fig.tight_layout()

    out_path = os.path.join(OUTDIR, f"{experiment}.png")
    fig.savefig(out_path, dpi=120)
    print(f"wrote {out_path}")
    plt.close(fig)
    return out_path


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("dirs", nargs="*")
    args = parser.parse_args(argv)

    dirs = args.dirs or find_results_dirs()
    if not dirs:
        parser.error("no results directories given and none auto-discovered")

    missing = [d for d in dirs if not os.path.isdir(d)]
    if missing:
        parser.error("not a directory: " + ", ".join(missing))

    experiments = defaultdict(dict)
    for d in dirs:
        label = os.path.basename(os.path.normpath(d))
        csv_files = sorted(glob.glob(os.path.join(d, "*.csv")))
        if not csv_files:
            print(f"warning: no CSV files in {d}", file=sys.stderr)
        for path in csv_files:
            experiment = os.path.splitext(os.path.basename(path))[0]
            rows = load_csv(path)
            if not rows:
                print(f"warning: no rows in {path}", file=sys.stderr)
                continue
            experiments[experiment][label] = summarize(rows)

    if not experiments:
        parser.error("no data found in the given directories")

    os.makedirs(OUTDIR, exist_ok=True)
    for experiment in sorted(experiments):
        plot_experiment(experiment, experiments[experiment])


if __name__ == "__main__":
    main()
