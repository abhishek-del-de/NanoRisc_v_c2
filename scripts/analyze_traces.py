#!/usr/bin/env python3
"""
=============================================================================
Project: NanoRISCV-C2
File:    scripts/analyze_traces.py
Description: Trace dataset analysis, performance metrics evaluation, summary
             table generation, and publication-quality visualization script.
             Outputs:
               - 4 Visualizations in results/visualizations/
               - 4 Summary CSV tables in results/summary_tables/
=============================================================================
"""

import sys
from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Paths relative to project root
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_DIR = PROJECT_ROOT / "data"
RESULTS_DIR = PROJECT_ROOT / "results"
VIZ_DIR = RESULTS_DIR / "visualizations"
TABLES_DIR = RESULTS_DIR / "summary_tables"

# Opcode dictionary for RV32I human-readable labeling
OPCODE_NAMES = {
    "0x13": "OP-IMM (ADDI, ANDI, XORI, SLLI...)",
    "0x33": "OP (ADD, SUB, SLL, SLT, XOR...)",
    "0x03": "LOAD (LW)",
    "0x23": "STORE (SW)",
    "0x63": "BRANCH (BEQ, BNE, BLT...)",
    "0x6F": "JAL",
    "0x67": "JALR",
    "0x37": "LUI",
    "0x17": "AUIPC",
    "0x73": "SYSTEM (ECALL/EBREAK)"
}

def setup_matplotlib():
    """Configure matplotlib parameters for clean academic aesthetics."""
    plt.rcParams.update({
        'font.sans-serif': 'DejaVu Sans',
        'font.family': 'sans-serif',
        'font.size': 11,
        'axes.labelsize': 12,
        'axes.titlesize': 13,
        'xtick.labelsize': 10,
        'ytick.labelsize': 10,
        'figure.titlesize': 14,
        'axes.grid': True,
        'grid.alpha': 0.3,
        'grid.linestyle': '--'
    })

def load_and_validate_dataset(csv_path):
    """Load, inspect, and validate dataset integrity."""
    print(f"[INFO] Loading trace dataset from: {csv_path}")
    if not csv_path.exists():
        raise FileNotFoundError(f"Dataset file {csv_path} does not exist. Run scripts/run_tests.py first.")

    df = pd.read_csv(csv_path)

    expected_cols = ["pc", "instruction_hex", "opcode", "rs1", "rs2", "rd", "cycles_taken", "branch_taken"]
    missing = [c for c in expected_cols if c not in df.columns]
    if missing:
        raise ValueError(f"Dataset missing required columns: {missing}")

    print(f"[INFO] Dataset loaded successfully: {len(df)} records.")
    print("Column Data Types:")
    for col, dtype in df.dtypes.items():
        print(f"  - {col}: {dtype}")

    # Integrity inspection
    null_counts = df.isnull().sum()
    print("Missing / Null Values:")
    for col, n in null_counts.items():
        print(f"  - {col}: {n}")

    # Standardize opcode format (uppercase 0xXX)
    df["opcode_norm"] = df["opcode"].astype(str).str.upper()
    df["opcode_name"] = df["opcode_norm"].map(OPCODE_NAMES).fillna("OTHER")

    return df

def generate_summary_tables(df):
    """Generate and export statistical CSV summary tables."""
    TABLES_DIR.mkdir(parents=True, exist_ok=True)

    # 1. Opcode Distribution Table
    opcode_counts = df["opcode_name"].value_counts().reset_index()
    opcode_counts.columns = ["Instruction_Type", "Count"]
    opcode_counts["Percentage"] = (opcode_counts["Count"] / len(df) * 100).round(2)
    opcode_file = TABLES_DIR / "opcode_distribution.csv"
    opcode_counts.to_csv(opcode_file, index=False)
    print(f"[TABLE] Opcode summary saved to: {opcode_file}")

    # 2. Branch Execution Summary Table
    branches = df[df["opcode_norm"] == "0X63"]
    total_branches = len(branches)
    taken_branches = int(branches["branch_taken"].sum()) if total_branches > 0 else 0
    not_taken_branches = total_branches - taken_branches
    taken_rate = (taken_branches / total_branches * 100) if total_branches > 0 else 0.0

    branch_summary = pd.DataFrame([{
        "Total_Branch_Evaluations": total_branches,
        "Branches_Taken": taken_branches,
        "Branches_Not_Taken": not_taken_branches,
        "Branch_Taken_Rate_Pct": round(taken_rate, 2)
    }])
    branch_file = TABLES_DIR / "branch_summary.csv"
    branch_summary.to_csv(branch_file, index=False)
    print(f"[TABLE] Branch summary saved to: {branch_file}")

    # 3. Register Destination Usage Table
    # Filter out rd == 0 (non-writing instructions or writes to x0)
    rd_writes = df[df["rd"] != 0]["rd"].value_counts().sort_index().reset_index()
    rd_writes.columns = ["Register", "Write_Count"]
    rd_writes["Register_Name"] = "x" + rd_writes["Register"].astype(str)
    rd_file = TABLES_DIR / "register_usage.csv"
    rd_writes.to_csv(rd_file, index=False)
    print(f"[TABLE] Register destination usage saved to: {rd_file}")

    # 4. Cycle Breakdown Summary Table
    total_cycles = int(df["cycles_taken"].sum()) + 1 # +1 initial pipeline fill
    cpi = total_cycles / len(df) if len(df) > 0 else 0.0
    cycle_summary = pd.DataFrame([{
        "Total_Instructions_Retired": len(df),
        "Total_Cycles_Consumed": total_cycles,
        "Single_Cycle_Instructions": int((df["cycles_taken"] == 1).sum()),
        "Multi_Cycle_Instructions": int((df["cycles_taken"] > 1).sum()),
        "Measured_CPI": round(cpi, 3)
    }])
    cycle_file = TABLES_DIR / "cycle_summary.csv"
    cycle_summary.to_csv(cycle_file, index=False)
    print(f"[TABLE] Cycle breakdown saved to: {cycle_file}")

    return opcode_counts, branch_summary, rd_writes, cycle_summary

def plot_instruction_distribution(df):
    """Visualization 1: Instruction Distribution by Opcode."""
    counts = df["opcode_name"].value_counts()

    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.barh(counts.index, counts.values, color="#1f77b4", edgecolor="#0e3d61", height=0.6)

    # Annotate bar values
    for bar in bars:
        width = bar.get_width()
        pct = (width / len(df)) * 100
        ax.text(width + 0.8, bar.get_y() + bar.get_height()/2,
                f"{int(width)} ({pct:.1f}%)",
                va='center', ha='left', fontsize=10, fontweight='bold', color="#222222")

    ax.set_title("NanoRISCV-C2: Instruction Distribution by Opcode Category", pad=15, fontweight='bold')
    ax.set_xlabel("Retired Instruction Count")
    ax.set_xlim(0, max(counts.values) * 1.2)
    ax.invert_yaxis()

    out_path = VIZ_DIR / "instruction_distribution_by_opcode.png"
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    plt.close()
    print(f"[PLOT 1] Saved: {out_path}")

def plot_branch_behavior(df):
    """Visualization 2: Branch Taken vs Not-Taken Counts."""
    branches = df[df["opcode_norm"] == "0X63"]
    taken = int(branches["branch_taken"].sum())
    not_taken = len(branches) - taken

    labels = ["Not Taken (Sequential Path)", "Taken (Pipeline Flushed)"]
    counts = [not_taken, taken]
    colors = ["#2ca02c", "#d62728"]

    fig, ax = plt.subplots(figsize=(8, 6))
    bars = ax.bar(labels, counts, color=colors, edgecolor="#333333", width=0.5)

    for bar in bars:
        height = bar.get_height()
        pct = (height / len(branches) * 100) if len(branches) > 0 else 0
        ax.text(bar.get_x() + bar.get_width()/2, height + 0.3,
                f"{int(height)} ({pct:.1f}%)",
                ha='center', va='bottom', fontsize=11, fontweight='bold')

    ax.set_title("NanoRISCV-C2: Conditional Branch Evaluation Outcomes", pad=15, fontweight='bold')
    ax.set_ylabel("Occurrence Count")
    ax.set_ylim(0, max(counts) * 1.25)

    out_path = VIZ_DIR / "branch_taken_vs_not_taken.png"
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    plt.close()
    print(f"[PLOT 2] Saved: {out_path}")

def plot_cycles_distribution(df):
    """Visualization 3: Distribution of cycles_taken."""
    counts = df["cycles_taken"].value_counts().sort_index()

    labels = [f"{c} Cycle{'s' if c > 1 else ''}" for c in counts.index]
    colors = ["#4285F4", "#EA4335"]

    fig, ax = plt.subplots(figsize=(8, 6))
    bars = ax.bar(labels, counts.values, color=colors[:len(counts)], edgecolor="#222222", width=0.45)

    for bar in bars:
        height = bar.get_height()
        pct = (height / len(df)) * 100
        ax.text(bar.get_x() + bar.get_width()/2, height + 1.2,
                f"{int(height)} instrs ({pct:.1f}%)",
                ha='center', va='bottom', fontsize=10, fontweight='bold')

    ax.set_title("NanoRISCV-C2: Retirement Latency Distribution (cycles_taken)", pad=15, fontweight='bold')
    ax.set_ylabel("Instruction Count")
    ax.set_xlabel("Effective Cycles per Instruction (Retirement + Pipeline Flush)")
    ax.set_ylim(0, max(counts.values) * 1.18)

    out_path = VIZ_DIR / "distribution_of_cycles_taken.png"
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    plt.close()
    print(f"[PLOT 3] Saved: {out_path}")

def plot_register_usage(df):
    """Visualization 4: Register Destination (rd) Usage."""
    rd_counts = df[df["rd"] != 0]["rd"].value_counts().sort_index()

    regs = [f"x{r}" for r in rd_counts.index]
    counts = rd_counts.values

    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.bar(regs, counts, color="#ff7f0e", edgecolor="#9e4c04", width=0.6)

    for bar in bars:
        height = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, height + 0.4,
                f"{int(height)}",
                ha='center', va='bottom', fontsize=9, fontweight='bold')

    ax.set_title("NanoRISCV-C2: Architectural Register Destination (rd) Write Distribution", pad=15, fontweight='bold')
    ax.set_xlabel("Destination Register")
    ax.set_ylabel("Write Frequency")
    ax.set_ylim(0, max(counts) * 1.15)

    out_path = VIZ_DIR / "register_destination_usage.png"
    plt.tight_layout()
    plt.savefig(out_path, dpi=300)
    plt.close()
    print(f"[PLOT 4] Saved: {out_path}")

def main():
    print("=" * 70)
    print(" NanoRISCV-C2 Trace Analysis and Visualization Pipeline")
    print("=" * 70)

    setup_matplotlib()
    VIZ_DIR.mkdir(parents=True, exist_ok=True)
    TABLES_DIR.mkdir(parents=True, exist_ok=True)

    csv_path = DATA_DIR / "dataset.csv"
    df = load_and_validate_dataset(csv_path)

    print("\n--- GENERATING STATISTICAL SUMMARY TABLES ---")
    generate_summary_tables(df)

    print("\n--- GENERATING PUBLICATION-QUALITY VISUALIZATIONS ---")
    plot_instruction_distribution(df)
    plot_branch_behavior(df)
    plot_cycles_distribution(df)
    plot_register_usage(df)

    print("\n[SUCCESS] Trace analysis and all visualizations generated successfully.")

if __name__ == "__main__":
    main()

