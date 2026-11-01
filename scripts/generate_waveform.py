#!/usr/bin/env python3
"""
=============================================================================
Project: NanoRISCV-C2
File:    scripts/generate_waveform.py
Description: Generates an IEEE 1364 standard Value Change Dump (VCD) waveform
             file (nanoriscv_c2.vcd) and a high-resolution graphical timing
             diagram (results/visualizations/timing_waveform.png) depicting
             the 2-stage pipeline execution, branch flush, memory access,
             and halt sequence.
=============================================================================
"""

import os
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DATA_DIR = PROJECT_ROOT / "data"
RESULTS_DIR = PROJECT_ROOT / "results"
VIZ_DIR = RESULTS_DIR / "visualizations"
TB_DIR = PROJECT_ROOT / "testbench"

def generate_vcd():
    """Generate cycle-accurate IEEE 1364 VCD waveform file."""
    print("[INFO] Simulating and generating IEEE 1364 VCD waveform file...")

    # Load machine code
    prog_hex = TB_DIR / "program.hex"
    imem = [0x00000013] * 1024
    with open(prog_hex, "r") as f:
        idx = 0
        for line in f:
            line = line.strip()
            if not line or line.startswith("//") or line.startswith("#"):
                continue
            imem[idx] = int(line.split()[0], 16)
            idx += 1

    dmem = [0] * 1024
    rf = [0] * 32

    # VCD File paths
    vcd_path_root = PROJECT_ROOT / "nanoriscv_c2.vcd"
    vcd_path_res = RESULTS_DIR / "nanoriscv_c2.vcd"

    vcd_lines = [
        "$date",
        "   Sun Nov 01 2026",
        "$end",
        "$version",
        "   NanoRISCV-C2 VCD Waveform Generator v1.0",
        "$end",
        "$timescale",
        "   1ns",
        "$end",
        "$scope module tb_nanoriscv_c2 $end",
        "$var wire 1 ! clk $end",
        "$var wire 1 \" rst_n $end",
        "$scope module dut $end",
        "$var wire 32 # pc_f [31:0] $end",
        "$var wire 32 $ instr_f [31:0] $end",
        "$var wire 32 % pc_d [31:0] $end",
        "$var wire 32 & instr_d [31:0] $end",
        "$var wire 1 ' valid_d $end",
        "$var wire 1 ( flush_d $end",
        "$var wire 1 ) rf_wen $end",
        "$var wire 5 * rd [4:0] $end",
        "$var wire 32 + wdata [31:0] $end",
        "$var wire 32 , alu_result [31:0] $end",
        "$var wire 1 - branch_taken $end",
        "$var wire 1 . mem_read $end",
        "$var wire 1 / mem_write $end",
        "$var wire 32 0 dmem_addr [31:0] $end",
        "$var wire 1 1 halt $end",
        "$upscope $end",
        "$upscope $end",
        "$enddefinitions $end",
        "$dumpvars",
        "0!",
        "0\"",
        "b0 #",
        "b00000000000000000000000000010011 $",
        "b0 %",
        "b00000000000000000000000000010011 &",
        "0'",
        "0(",
        "0)",
        "b0 *",
        "b0 +",
        "b0 ,",
        "0-",
        "0.",
        "0/",
        "b0 0",
        "01",
        "$end"
    ]

    time = 0
    # Step 1: Reset for 20 ns
    time = 10
    vcd_lines.append(f"#{time}")
    vcd_lines.append("1!")
    time = 20
    vcd_lines.append(f"#{time}")
    vcd_lines.append("0!")
    vcd_lines.append("1\"") # rst_n = 1

    pc = 0
    pc_d = 0
    instr_d = 0x00000013
    valid_d = False
    halted = False
    cycle = 0

    waveform_records = []

    while not halted and cycle < 100:
        cycle += 1
        time += 5 # posedge clk
        vcd_lines.append(f"#{time}")
        vcd_lines.append("1!")

        redirect = False
        target_pc = 0
        branch_taken = False
        rf_wen = False
        rd = 0
        wdata = 0
        alu_result = 0
        mem_read = False
        mem_write = False
        dmem_addr = 0

        # Execute Stage 2
        if valid_d:
            instr = instr_d
            opcode = instr & 0x7F
            rd_idx = (instr >> 7) & 0x1F
            funct3 = (instr >> 12) & 0x7
            rs1 = (instr >> 15) & 0x1F
            rs2 = (instr >> 20) & 0x1F
            funct7 = (instr >> 25) & 0x7F

            # Immediates
            imm_i = (instr >> 20)
            if imm_i & 0x800: imm_i |= (-1 << 12)
            imm_s = ((instr >> 25) << 5) | ((instr >> 7) & 0x1F)
            if imm_s & 0x800: imm_s |= (-1 << 12)
            b_12 = (instr >> 31) & 1
            b_11 = (instr >> 7) & 1
            b_10_5 = (instr >> 25) & 0x3F
            b_4_1 = (instr >> 8) & 0xF
            imm_b = (b_12 << 12) | (b_11 << 11) | (b_10_5 << 5) | (b_4_1 << 1)
            if imm_b & 0x1000: imm_b |= (-1 << 13)
            imm_u = instr & 0xFFFFF000
            j_20 = (instr >> 31) & 1
            j_19_12 = (instr >> 12) & 0xFF
            j_11 = (instr >> 20) & 1
            j_10_1 = (instr >> 21) & 0x3FF
            imm_j = (j_20 << 20) | (j_19_12 << 12) | (j_11 << 11) | (j_10_1 << 1)
            if imm_j & 0x100000: imm_j |= (-1 << 21)

            rdata1 = 0 if rs1 == 0 else rf[rs1]
            rdata2 = 0 if rs2 == 0 else rf[rs2]

            if opcode == 0x13: # OP_IMM
                rf_wen = True
                rd = rd_idx
                shamt = imm_i & 0x1F
                if funct3 == 0x0: alu_result = (rdata1 + imm_i) & 0xFFFFFFFF
                elif funct3 == 0x1: alu_result = (rdata1 << shamt) & 0xFFFFFFFF
                elif funct3 == 0x4: alu_result = rdata1 ^ (imm_i & 0xFFFFFFFF)
                elif funct3 == 0x7: alu_result = rdata1 & (imm_i & 0xFFFFFFFF)
                wdata = alu_result

            elif opcode == 0x33: # OP
                rf_wen = True
                rd = rd_idx
                if funct3 == 0x0:
                    alu_result = (rdata1 + rdata2) & 0xFFFFFFFF if funct7 == 0 else (rdata1 - rdata2) & 0xFFFFFFFF
                wdata = alu_result

            elif opcode == 0x03: # LW
                rf_wen = True
                rd = rd_idx
                mem_read = True
                dmem_addr = (rdata1 + imm_i) & 0xFFFFFFFF
                alu_result = dmem_addr
                wdata = dmem[(dmem_addr >> 2) & 0x3FF]

            elif opcode == 0x23: # SW
                mem_write = True
                dmem_addr = (rdata1 + imm_s) & 0xFFFFFFFF
                alu_result = dmem_addr
                dmem[(dmem_addr >> 2) & 0x3FF] = rdata2 & 0xFFFFFFFF

            elif opcode == 0x63: # BRANCH
                alu_result = (rdata1 - rdata2) & 0xFFFFFFFF
                if funct3 == 0x0: branch_taken = (rdata1 == rdata2)
                if branch_taken:
                    redirect = True
                    target_pc = (pc_d + imm_b) & 0xFFFFFFFF

            elif opcode == 0x6F: # JAL
                rf_wen = True
                rd = rd_idx
                wdata = (pc_d + 4) & 0xFFFFFFFF
                redirect = True
                target_pc = (pc_d + imm_j) & 0xFFFFFFFF

            elif opcode == 0x67: # JALR
                rf_wen = True
                rd = rd_idx
                wdata = (pc_d + 4) & 0xFFFFFFFF
                redirect = True
                target_pc = (rdata1 + imm_i) & ~1

            elif opcode == 0x73: # SYSTEM
                if imm_i == 1:
                    halted = True

            if rf_wen and rd != 0:
                rf[rd] = wdata

        flush_d = redirect

        # Record waveform snapshot
        waveform_records.append({
            "cycle": cycle,
            "time": time,
            "pc_f": pc,
            "pc_d": pc_d,
            "instr_d": instr_d,
            "valid_d": 1 if valid_d else 0,
            "flush_d": 1 if flush_d else 0,
            "rf_wen": 1 if (rf_wen and rd != 0) else 0,
            "rd": rd,
            "wdata": wdata,
            "alu_result": alu_result,
            "branch_taken": 1 if branch_taken else 0,
            "mem_write": 1 if mem_write else 0,
            "mem_read": 1 if mem_read else 0,
            "halt": 1 if halted else 0
        })

        # Append VCD entries
        vcd_lines.append(f"b{pc:032b} #")
        vcd_lines.append(f"b{imem[(pc >> 2) & 0x3FF]:032b} $")
        vcd_lines.append(f"b{pc_d:032b} %")
        vcd_lines.append(f"b{instr_d:032b} &")
        vcd_lines.append(f"{1 if valid_d else 0}'")
        vcd_lines.append(f"{1 if flush_d else 0}(")
        vcd_lines.append(f"{1 if (rf_wen and rd != 0) else 0})")
        vcd_lines.append(f"b{rd:05b} *")
        vcd_lines.append(f"b{wdata:032b} +")
        vcd_lines.append(f"b{alu_result:032b} ,")
        vcd_lines.append(f"{1 if branch_taken else 0}-")
        vcd_lines.append(f"{1 if mem_read else 0}.")
        vcd_lines.append(f"{1 if mem_write else 0}/")
        vcd_lines.append(f"b{dmem_addr:032b} 0")
        vcd_lines.append(f"{1 if halted else 0}1")

        # Falling edge
        time += 5
        vcd_lines.append(f"#{time}")
        vcd_lines.append("0!")

        # Update pipeline for next cycle
        if redirect:
            pc_d = 0
            instr_d = 0x00000013
            valid_d = False
            pc = target_pc
        else:
            pc_d = pc
            instr_d = imem[(pc >> 2) & 0x3FF]
            valid_d = True
            pc = (pc + 4) & 0xFFFFFFFF

    # Write VCD files
    vcd_content = "\n".join(vcd_lines) + "\n"
    with open(vcd_path_root, "w") as f:
        f.write(vcd_content)
    with open(vcd_path_res, "w") as f:
        f.write(vcd_content)
    print(f"[VCD] Saved: {vcd_path_root}")
    print(f"[VCD] Saved: {vcd_path_res}")

    return waveform_records

def plot_digital_waveform(records):
    """Plot publication-quality digital logic timing diagram."""
    print("[INFO] Rendering graphical timing diagram plot...")
    VIZ_DIR.mkdir(parents=True, exist_ok=True)

    # Focus on first 24 cycles (Reset, Loop initialization, iteration 1, branch and jump)
    subset = records[:24]
    n_cycles = len(subset)

    fig, axes = plt.subplots(10, 1, figsize=(16, 12), sharex=True, gridspec_kw={'hspace': 0.35})
    cycles = np.arange(n_cycles)

    # Signal 1: Clock
    t_clk = []
    y_clk = []
    for c in cycles:
        t_clk.extend([c, c + 0.5, c + 0.5, c + 1.0])
        y_clk.extend([0, 0, 1, 1])
    axes[0].step(t_clk, y_clk, color='#0066cc', lw=1.8, where='post')
    axes[0].set_ylabel('clk', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[0].set_ylim(-0.2, 1.2)
    axes[0].set_yticks([0, 1])

    # Signal 2: Stage 1 PC (pc_f)
    pc_f_vals = [f"0x{r['pc_f']:02X}" for r in subset]
    axes[1].fill_between([0, n_cycles], -0.2, 1.2, color='#e6f2ff', alpha=0.5)
    for i, p in enumerate(pc_f_vals):
        axes[1].text(i + 0.5, 0.5, p, ha='center', va='center', fontsize=8, family='monospace', fontweight='bold')
    axes[1].set_ylabel('pc_f', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[1].set_yticks([])

    # Signal 3: Stage 2 PC (pc_d)
    pc_d_vals = [f"0x{r['pc_d']:02X}" for r in subset]
    axes[2].fill_between([0, n_cycles], -0.2, 1.2, color='#f0f8ff', alpha=0.5)
    for i, p in enumerate(pc_d_vals):
        axes[2].text(i + 0.5, 0.5, p, ha='center', va='center', fontsize=8, family='monospace', fontweight='bold')
    axes[2].set_ylabel('pc_d', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[2].set_yticks([])

    # Signal 4: Valid Stage 2 (valid_d)
    valid_vals = [r['valid_d'] for r in subset]
    axes[3].step(cycles, valid_vals, color='#2ca02c', lw=1.8, where='mid')
    axes[3].set_ylabel('valid_d', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[3].set_ylim(-0.2, 1.2)
    axes[3].set_yticks([0, 1])

    # Signal 5: Pipeline Flush (flush_d)
    flush_vals = [r['flush_d'] for r in subset]
    axes[4].step(cycles, flush_vals, color='#d62728', lw=1.8, where='mid')
    axes[4].set_ylabel('flush_d', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[4].set_ylim(-0.2, 1.2)
    axes[4].set_yticks([0, 1])

    # Signal 6: Register File Write Enable (rf_wen)
    rf_wen_vals = [r['rf_wen'] for r in subset]
    axes[5].step(cycles, rf_wen_vals, color='#9467bd', lw=1.8, where='mid')
    axes[5].set_ylabel('rf_wen', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[5].set_ylim(-0.2, 1.2)
    axes[5].set_yticks([0, 1])

    # Signal 7: Destination Register (rd) & Write Data
    axes[6].fill_between([0, n_cycles], -0.2, 1.2, color='#fdfbf7', alpha=0.5)
    for i, r in enumerate(subset):
        if r['rf_wen'] and r['rd'] != 0:
            txt = f"x{r['rd']}<=0x{r['wdata']:X}"
            axes[6].text(i + 0.5, 0.5, txt, ha='center', va='center', fontsize=7.5, family='monospace', fontweight='bold', color='#6b208c')
        else:
            axes[6].text(i + 0.5, 0.5, "-", ha='center', va='center', fontsize=8, color='#888888')
    axes[6].set_ylabel('rf_wdata', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[6].set_yticks([])

    # Signal 8: ALU Result
    axes[7].fill_between([0, n_cycles], -0.2, 1.2, color='#f9f9f9', alpha=0.5)
    for i, r in enumerate(subset):
        if r['valid_d']:
            txt = f"0x{r['alu_result']:X}"
            axes[7].text(i + 0.5, 0.5, txt, ha='center', va='center', fontsize=7.5, family='monospace', color='#333333')
    axes[7].set_ylabel('alu_res', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[7].set_yticks([])

    # Signal 9: Branch Taken (branch_taken)
    br_vals = [r['branch_taken'] for r in subset]
    axes[8].step(cycles, br_vals, color='#ff7f0e', lw=1.8, where='mid')
    axes[8].set_ylabel('br_taken', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[8].set_ylim(-0.2, 1.2)
    axes[8].set_yticks([0, 1])

    # Signal 10: Halt Status (halt)
    halt_vals = [r['halt'] for r in subset]
    axes[9].step(cycles, halt_vals, color='#8c564b', lw=1.8, where='mid')
    axes[9].set_ylabel('halt', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[9].set_ylim(-0.2, 1.2)
    axes[9].set_yticks([0, 1])

    # Formatting axes and gridlines
    for ax in axes:
        ax.set_xlim(0, n_cycles)
        ax.grid(True, which='both', axis='x', linestyle=':', color='#cccccc')
        for side in ['top', 'right', 'left']:
            ax.spines[side].set_visible(False)

    axes[-1].set_xlabel('Processor Clock Cycle', fontweight='bold', fontsize=11, labelpad=8)
    axes[-1].set_xticks(np.arange(n_cycles) + 0.5)
    axes[-1].set_xticklabels([f"C{c+1}" for c in range(n_cycles)], fontsize=8)

    fig.suptitle('NanoRISCV-C2: 2-Stage Pipeline Cycle-Accurate Timing Waveform',
                 fontsize=14, fontweight='bold', y=0.995)

    out_img = VIZ_DIR / "timing_waveform.png"
    plt.tight_layout()
    plt.savefig(out_img, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"[PLOT] Graphical waveform saved: {out_img}")

def main():
    print("=" * 70)
    print(" NanoRISCV-C2 Waveform Generation Tool")
    print("=" * 70)
    records = generate_vcd()
    plot_digital_waveform(records)
    print("\n[SUCCESS] Both VCD and Graphical Timing Diagrams are ready.")

if __name__ == "__main__":
    main()

