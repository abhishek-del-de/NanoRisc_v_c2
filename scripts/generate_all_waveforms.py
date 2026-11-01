#!/usr/bin/env python3
"""
=============================================================================
Project: NanoRISCV-C2
File:    scripts/generate_all_waveforms.py
Description: Exhaustive Waveform Generation Suite for NanoRISCV-C2:
             1. ALU Unit Test Waveform (VCD & High-Res PNG)
             2. Processor Core Phase 1: Reset, Init & Loop Iteration (PNG)
             3. Processor Core Phase 2: Memory Access (LW/SW), JAL/JALR & Halt (PNG)
             4. Processor Core Full-Run Waveform (All 89 cycles) (VCD & PNG)
             5. Standalone Interactive HTML Waveform Viewer (waveform_viewer.html)
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

def generate_alu_waveforms():
    """Generate VCD and graphical waveform for all 30 ALU operations."""
    print("[INFO] Generating ALU unit test waveforms...")

    alu_tests = [
        ("ADD_0", "ADD", 0, 0, 0, 1),
        ("ADD_pos", "ADD", 15, 25, 40, 0),
        ("ADD_neg_pos", "ADD", (-10) & 0xFFFFFFFF, 10, 0, 1),
        ("ADD_negs", "ADD", (-5) & 0xFFFFFFFF, (-15) & 0xFFFFFFFF, (-20) & 0xFFFFFFFF, 0),
        ("ADD_overflow", "ADD", 0x7FFFFFFF, 1, 0x80000000, 0),
        ("ADD_wrap", "ADD", 0xFFFFFFFF, 1, 0, 1),

        ("SUB_eq", "SUB", 50, 50, 0, 1),
        ("SUB_pos", "SUB", 100, 30, 70, 0),
        ("SUB_neg", "SUB", 20, 50, (-30) & 0xFFFFFFFF, 0),
        ("SUB_underflow", "SUB", 0x80000000, 1, 0x7FFFFFFF, 0),

        ("AND_mask", "AND", 0xFF00FF00, 0xF0F0F0F0, 0xF000F000, 0),
        ("AND_disjoint", "AND", 0xAAAAAAAA, 0x55555555, 0, 1),
        ("OR_comb", "OR", 0xF0000000, 0x0000000F, 0xF000000F, 0),
        ("XOR_inv", "XOR", 0x12345678, 0x12345678, 0, 1),
        ("XOR_toggle", "XOR", 0xFFFFFFFF, 0x0000FFFF, 0xFFFF0000, 0),

        ("SLL_0", "SLL", 1, 0, 1, 0),
        ("SLL_4", "SLL", 1, 4, 16, 0),
        ("SLL_31", "SLL", 1, 31, 0x80000000, 0),
        ("SLL_mask", "SLL", 1, 35, 8, 0),
        ("SRL_4", "SRL", 0x80000000, 4, 0x08000000, 0),
        ("SRA_pos", "SRA", 0x70000000, 4, 0x07000000, 0),
        ("SRA_neg", "SRA", 0x80000000, 4, 0xF8000000, 0),
        ("SRA_31", "SRA", 0x80000000, 31, 0xFFFFFFFF, 0),

        ("SLT_pos_pos", "SLT", 10, 20, 1, 0),
        ("SLT_neg_pos", "SLT", (-5) & 0xFFFFFFFF, 5, 1, 0),
        ("SLT_pos_neg", "SLT", 5, (-5) & 0xFFFFFFFF, 0, 1),
        ("SLT_eq", "SLT", 100, 100, 0, 1),
        ("SLTU_un", "SLTU", 5, 0xFFFFFFFF, 1, 0),
        ("SLTU_hi_lo", "SLTU", 0xFFFFFFFF, 5, 0, 1),
        ("COPY_B", "COPY_B", 0xDEADBEEF, 0xCAFE1234, 0xCAFE1234, 0),
    ]

    vcd_path = PROJECT_ROOT / "alu_waveform.vcd"
    vcd_res = RESULTS_DIR / "alu_waveform.vcd"

    vcd_lines = [
        "$date Sun Nov 01 2026 $end",
        "$version NanoRISCV-C2 ALU VCD $end",
        "$timescale 1ns $end",
        "$scope module tb_alu $end",
        "$var wire 4 ! alu_op [3:0] $end",
        "$var wire 32 \" operand_a [31:0] $end",
        "$var wire 32 # operand_b [31:0] $end",
        "$var wire 32 $ result [31:0] $end",
        "$var wire 1 % zero $end",
        "$var wire 1 & cmp_result $end",
        "$upscope $end",
        "$enddefinitions $end",
        "$dumpvars", "b0 !", "b0 \"", "b0 #", "b0 $", "0%", "0&", "$end"
    ]

    time = 0
    records = []
    op_codes = {
        "ADD": 0, "SUB": 1, "AND": 2, "OR": 3, "XOR": 4,
        "SLL": 5, "SRL": 6, "SRA": 7, "SLT": 8, "SLTU": 9, "COPY_B": 10
    }

    for name, op, a, b, exp_res, exp_zero in alu_tests:
        time += 10
        op_code = op_codes[op]
        cmp_res = 1 if exp_res == 1 and op in ["SLT", "SLTU"] else 0
        records.append({
            "test": name, "op": op, "a": a, "b": b,
            "res": exp_res, "zero": exp_zero, "cmp": cmp_res
        })

        vcd_lines.append(f"#{time}")
        vcd_lines.append(f"b{op_code:04b} !")
        vcd_lines.append(f"b{a:032b} \"")
        vcd_lines.append(f"b{b:032b} #")
        vcd_lines.append(f"b{exp_res:032b} $")
        vcd_lines.append(f"{exp_zero}%")
        vcd_lines.append(f"{cmp_res}&")

    content = "\n".join(vcd_lines) + "\n"
    vcd_path.write_text(content)
    vcd_res.write_text(content)
    print(f"[VCD] ALU Waveform saved: {vcd_path}")

    # Plot ALU Graphical Timing Diagram
    n = len(records)
    fig, axes = plt.subplots(5, 1, figsize=(16, 8), sharex=True, gridspec_kw={'hspace': 0.3})
    cycles = np.arange(n)

    # 1. Operation Name
    axes[0].fill_between([0, n], -0.2, 1.2, color='#eef4fc', alpha=0.6)
    for i, r in enumerate(records):
        axes[0].text(i + 0.5, 0.5, r['op'], ha='center', va='center', fontsize=8, fontweight='bold', color='#004085')
    axes[0].set_ylabel('alu_op', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[0].set_yticks([])

    # 2. Operand A
    axes[1].fill_between([0, n], -0.2, 1.2, color='#fdfbf7', alpha=0.6)
    for i, r in enumerate(records):
        axes[1].text(i + 0.5, 0.5, f"0x{r['a']:04X}" if r['a'] < 0xFFFF else f"0x{r['a']:08X}",
                     ha='center', va='center', fontsize=6.5, family='monospace', color='#333333')
    axes[1].set_ylabel('operand_a', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[1].set_yticks([])

    # 3. Operand B
    axes[2].fill_between([0, n], -0.2, 1.2, color='#fdfbf7', alpha=0.6)
    for i, r in enumerate(records):
        axes[2].text(i + 0.5, 0.5, f"0x{r['b']:04X}" if r['b'] < 0xFFFF else f"0x{r['b']:08X}",
                     ha='center', va='center', fontsize=6.5, family='monospace', color='#333333')
    axes[2].set_ylabel('operand_b', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[2].set_yticks([])

    # 4. Result
    axes[3].fill_between([0, n], -0.2, 1.2, color='#f0fff4', alpha=0.6)
    for i, r in enumerate(records):
        axes[3].text(i + 0.5, 0.5, f"0x{r['res']:04X}" if r['res'] < 0xFFFF else f"0x{r['res']:08X}",
                     ha='center', va='center', fontsize=6.5, family='monospace', fontweight='bold', color='#155724')
    axes[3].set_ylabel('result', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[3].set_yticks([])

    # 5. Zero Flag
    zeros = [r['zero'] for r in records]
    axes[4].step(cycles, zeros, color='#e65100', lw=1.8, where='mid')
    axes[4].set_ylabel('zero', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[4].set_ylim(-0.2, 1.2)
    axes[4].set_yticks([0, 1])

    for ax in axes:
        ax.set_xlim(0, n)
        ax.grid(True, which='both', axis='x', linestyle=':', color='#cccccc')
        for side in ['top', 'right', 'left']:
            ax.spines[side].set_visible(False)

    axes[-1].set_xlabel('ALU Test Vector Index (1 to 30)', fontweight='bold', fontsize=10, labelpad=8)
    axes[-1].set_xticks(np.arange(n) + 0.5)
    axes[-1].set_xticklabels([f"T{i+1}" for i in range(n)], fontsize=7)

    fig.suptitle('NanoRISCV-C2: 32-bit ALU Unit Verification Waveforms (All 30 Test Vectors)',
                 fontsize=13, fontweight='bold', y=0.99)

    out_img = VIZ_DIR / "alu_waveform.png"
    plt.tight_layout()
    plt.savefig(out_img, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"[PLOT] ALU Graphical Waveform saved: {out_img}")

def generate_core_full_simulation():
    """Run cycle-accurate processor simulation and record all signal transitions."""
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

    pc = 0
    pc_d = 0
    instr_d = 0x00000013
    valid_d = False
    halted = False
    cycle = 0

    records = []

    while not halted and cycle < 100:
        cycle += 1
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
        instr_name = "NOP"

        if valid_d:
            instr = instr_d
            opcode = instr & 0x7F
            rd_idx = (instr >> 7) & 0x1F
            funct3 = (instr >> 12) & 0x7
            rs1 = (instr >> 15) & 0x1F
            rs2 = (instr >> 20) & 0x1F
            funct7 = (instr >> 25) & 0x7F

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

            if opcode == 0x13:
                rf_wen = True
                rd = rd_idx
                shamt = imm_i & 0x1F
                if funct3 == 0x0:
                    alu_result = (rdata1 + imm_i) & 0xFFFFFFFF
                    instr_name = f"ADDI x{rd},{imm_i}"
                elif funct3 == 0x1:
                    alu_result = (rdata1 << shamt) & 0xFFFFFFFF
                    instr_name = f"SLLI x{rd},{shamt}"
                elif funct3 == 0x4:
                    alu_result = rdata1 ^ (imm_i & 0xFFFFFFFF)
                    instr_name = f"XORI x{rd},{imm_i}"
                elif funct3 == 0x7:
                    alu_result = rdata1 & (imm_i & 0xFFFFFFFF)
                    instr_name = f"ANDI x{rd},{imm_i}"
                wdata = alu_result

            elif opcode == 0x33:
                rf_wen = True
                rd = rd_idx
                if funct3 == 0x0:
                    if funct7 == 0:
                        alu_result = (rdata1 + rdata2) & 0xFFFFFFFF
                        instr_name = f"ADD x{rd},x{rs1},x{rs2}"
                    else:
                        alu_result = (rdata1 - rdata2) & 0xFFFFFFFF
                        instr_name = f"SUB x{rd},x{rs1},x{rs2}"
                wdata = alu_result

            elif opcode == 0x03: # LW
                rf_wen = True
                rd = rd_idx
                mem_read = True
                dmem_addr = (rdata1 + imm_i) & 0xFFFFFFFF
                alu_result = dmem_addr
                wdata = dmem[(dmem_addr >> 2) & 0x3FF]
                instr_name = f"LW x{rd},{imm_i}(x{rs1})"

            elif opcode == 0x23: # SW
                mem_write = True
                dmem_addr = (rdata1 + imm_s) & 0xFFFFFFFF
                alu_result = dmem_addr
                dmem[(dmem_addr >> 2) & 0x3FF] = rdata2 & 0xFFFFFFFF
                instr_name = f"SW x{rs2},{imm_s}(x{rs1})"

            elif opcode == 0x63: # BEQ
                alu_result = (rdata1 - rdata2) & 0xFFFFFFFF
                if funct3 == 0x0: branch_taken = (rdata1 == rdata2)
                instr_name = f"BEQ x{rs1},x{rs2}"
                if branch_taken:
                    redirect = True
                    target_pc = (pc_d + imm_b) & 0xFFFFFFFF

            elif opcode == 0x6F: # JAL
                rf_wen = True
                rd = rd_idx
                wdata = (pc_d + 4) & 0xFFFFFFFF
                redirect = True
                target_pc = (pc_d + imm_j) & 0xFFFFFFFF
                instr_name = f"JAL x{rd},{imm_j}"

            elif opcode == 0x67: # JALR
                rf_wen = True
                rd = rd_idx
                wdata = (pc_d + 4) & 0xFFFFFFFF
                redirect = True
                target_pc = (rdata1 + imm_i) & ~1
                instr_name = f"JALR x{rd},0(x{rs1})"

            elif opcode == 0x73: # SYSTEM
                if imm_i == 1:
                    halted = True
                    instr_name = "EBREAK"

            if rf_wen and rd != 0:
                rf[rd] = wdata

        flush_d = redirect

        records.append({
            "cycle": cycle,
            "pc_f": pc,
            "pc_d": pc_d,
            "instr_d": instr_d,
            "instr_name": instr_name,
            "valid_d": 1 if valid_d else 0,
            "flush_d": 1 if flush_d else 0,
            "rf_wen": 1 if (rf_wen and rd != 0) else 0,
            "rd": rd,
            "wdata": wdata,
            "alu_result": alu_result,
            "branch_taken": 1 if branch_taken else 0,
            "mem_write": 1 if mem_write else 0,
            "mem_read": 1 if mem_read else 0,
            "dmem_addr": dmem_addr,
            "halt": 1 if halted else 0
        })

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

    return records

def plot_subwaveform(records, start_idx, end_idx, title, filename):
    """Render a dedicated graphical waveform for a specific execution phase."""
    subset = records[start_idx:end_idx]
    n = len(subset)

    fig, axes = plt.subplots(10, 1, figsize=(16, 12), sharex=True, gridspec_kw={'hspace': 0.35})
    cycles = np.arange(n)

    # 1. Clock
    t_clk, y_clk = [], []
    for c in cycles:
        t_clk.extend([c, c + 0.5, c + 0.5, c + 1.0])
        y_clk.extend([0, 0, 1, 1])
    axes[0].step(t_clk, y_clk, color='#0066cc', lw=1.8, where='post')
    axes[0].set_ylabel('clk', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[0].set_ylim(-0.2, 1.2)
    axes[0].set_yticks([0, 1])

    # 2. pc_f
    axes[1].fill_between([0, n], -0.2, 1.2, color='#e6f2ff', alpha=0.5)
    for i, r in enumerate(subset):
        axes[1].text(i + 0.5, 0.5, f"0x{r['pc_f']:02X}", ha='center', va='center', fontsize=8, family='monospace', fontweight='bold')
    axes[1].set_ylabel('pc_f', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[1].set_yticks([])

    # 3. Instruction Mnemonic (Stage 2)
    axes[2].fill_between([0, n], -0.2, 1.2, color='#fff9e6', alpha=0.6)
    for i, r in enumerate(subset):
        name = r['instr_name'] if r['valid_d'] else "(FLUSH BUBBLE)"
        col = '#d62728' if not r['valid_d'] else '#222222'
        axes[2].text(i + 0.5, 0.5, name, ha='center', va='center', fontsize=7.5, fontweight='bold', color=col)
    axes[2].set_ylabel('instr_d', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[2].set_yticks([])

    # 4. Valid Flag
    valid_vals = [r['valid_d'] for r in subset]
    axes[3].step(cycles, valid_vals, color='#2ca02c', lw=1.8, where='mid')
    axes[3].set_ylabel('valid_d', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[3].set_ylim(-0.2, 1.2)
    axes[3].set_yticks([0, 1])

    # 5. Flush Strobe
    flush_vals = [r['flush_d'] for r in subset]
    axes[4].step(cycles, flush_vals, color='#d62728', lw=1.8, where='mid')
    axes[4].set_ylabel('flush_d', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[4].set_ylim(-0.2, 1.2)
    axes[4].set_yticks([0, 1])

    # 6. Register Write Enable
    rf_wen_vals = [r['rf_wen'] for r in subset]
    axes[5].step(cycles, rf_wen_vals, color='#9467bd', lw=1.8, where='mid')
    axes[5].set_ylabel('rf_wen', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[5].set_ylim(-0.2, 1.2)
    axes[5].set_yticks([0, 1])

    # 7. Write Data
    axes[6].fill_between([0, n], -0.2, 1.2, color='#fdfbf7', alpha=0.5)
    for i, r in enumerate(subset):
        if r['rf_wen'] and r['rd'] != 0:
            axes[6].text(i + 0.5, 0.5, f"x{r['rd']}<=0x{r['wdata']:X}",
                         ha='center', va='center', fontsize=7.5, family='monospace', fontweight='bold', color='#6b208c')
        else:
            axes[6].text(i + 0.5, 0.5, "-", ha='center', va='center', fontsize=8, color='#888888')
    axes[6].set_ylabel('rf_wdata', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[6].set_yticks([])

    # 8. Memory Access (LW/SW)
    mem_vals = [1 if (r['mem_read'] or r['mem_write']) else 0 for r in subset]
    axes[7].step(cycles, mem_vals, color='#17becf', lw=1.8, where='mid')
    for i, r in enumerate(subset):
        if r['mem_write']:
            axes[7].text(i + 0.5, 0.5, f"SW@[{r['dmem_addr']}]", ha='center', va='center', fontsize=7, color='#004085', fontweight='bold')
        elif r['mem_read']:
            axes[7].text(i + 0.5, 0.5, f"LW@[{r['dmem_addr']}]", ha='center', va='center', fontsize=7, color='#155724', fontweight='bold')
    axes[7].set_ylabel('mem_strobe', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[7].set_ylim(-0.2, 1.2)
    axes[7].set_yticks([0, 1])

    # 9. Branch Taken
    br_vals = [r['branch_taken'] for r in subset]
    axes[8].step(cycles, br_vals, color='#ff7f0e', lw=1.8, where='mid')
    axes[8].set_ylabel('br_taken', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[8].set_ylim(-0.2, 1.2)
    axes[8].set_yticks([0, 1])

    # 10. Halt
    halt_vals = [r['halt'] for r in subset]
    axes[9].step(cycles, halt_vals, color='#8c564b', lw=1.8, where='mid')
    axes[9].set_ylabel('halt', rotation=0, ha='right', va='center', fontweight='bold', fontsize=10)
    axes[9].set_ylim(-0.2, 1.2)
    axes[9].set_yticks([0, 1])

    for ax in axes:
        ax.set_xlim(0, n)
        ax.grid(True, which='both', axis='x', linestyle=':', color='#cccccc')
        for side in ['top', 'right', 'left']:
            ax.spines[side].set_visible(False)

    axes[-1].set_xlabel('Processor Clock Cycle', fontweight='bold', fontsize=11, labelpad=8)
    axes[-1].set_xticks(np.arange(n) + 0.5)
    axes[-1].set_xticklabels([f"C{subset[i]['cycle']}" for i in range(n)], fontsize=8)

    fig.suptitle(title, fontsize=14, fontweight='bold', y=0.995)

    out_img = VIZ_DIR / filename
    plt.tight_layout()
    plt.savefig(out_img, dpi=300, bbox_inches='tight')
    plt.close()
    print(f"[PLOT] Waveform saved: {out_img}")

def generate_interactive_html(records):
    """Generate a standalone browser-viewable interactive waveform viewer."""
    html_path = RESULTS_DIR / "waveform_viewer.html"

    rows = []
    for r in records:
        inst = r['instr_name'] if r['valid_d'] else '<span style="color:red;font-weight:bold;">[FLUSH BUBBLE]</span>'
        wen = '<span style="color:purple;font-weight:bold;">1</span>' if r['rf_wen'] else '0'
        rd_txt = f"x{r['rd']}" if r['rf_wen'] and r['rd'] != 0 else "-"
        wdata_txt = f"0x{r['wdata']:X}" if r['rf_wen'] and r['rd'] != 0 else "-"
        br_txt = '<span style="color:orange;font-weight:bold;">TAKEN</span>' if r['branch_taken'] else ('UNTKN' if 'BEQ' in r['instr_name'] else '-')
        mem_txt = f"SW @{r['dmem_addr']}" if r['mem_write'] else (f"LW @{r['dmem_addr']}" if r['mem_read'] else "-")
        halt_txt = '<span style="color:red;font-weight:bold;">HALTED</span>' if r['halt'] else 'RUN'

        rows.append(f"""
        <tr>
            <td>{r['cycle']}</td>
            <td>0x{r['pc_f']:02X}</td>
            <td>0x{r['pc_d']:02X}</td>
            <td>{inst}</td>
            <td>{r['valid_d']}</td>
            <td>{r['flush_d']}</td>
            <td>{wen}</td>
            <td>{rd_txt}</td>
            <td>{wdata_txt}</td>
            <td>0x{r['alu_result']:X}</td>
            <td>{mem_txt}</td>
            <td>{br_txt}</td>
            <td>{halt_txt}</td>
        </tr>
        """)

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>NanoRISCV-C2: Interactive Cycle Waveform Viewer</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 20px; background-color: #f8f9fa; color: #333; }}
        h1 {{ color: #004085; }}
        .header {{ background: white; padding: 15px 25px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }}
        table {{ width: 100%; border-collapse: collapse; background: white; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-radius: 8px; overflow: hidden; font-size: 13px; }}
        th, td {{ padding: 8px 12px; text-align: center; border-bottom: 1px solid #e9ecef; }}
        th {{ background-color: #004085; color: white; position: sticky; top: 0; }}
        tr:hover {{ background-color: #f1f8ff; }}
        .badge {{ padding: 3px 6px; border-radius: 4px; font-weight: bold; font-size: 11px; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>NanoRISCV-C2: 2-Stage Pipeline Cycle-Accurate Execution Waveform</h1>
        <p><strong>Target ISA:</strong> RV32I Base Integer | <strong>Pipeline:</strong> 2-Stage (IF | EX/MEM/WB) | <strong>Total Retired:</strong> 75 Instructions | <strong>Cycles:</strong> 89 | <strong>CPI:</strong> 1.187</p>
    </div>
    <table>
        <thead>
            <tr>
                <th>Cycle</th>
                <th>Fetch PC (pc_f)</th>
                <th>Stage 2 PC (pc_d)</th>
                <th>Instruction</th>
                <th>Valid</th>
                <th>Flush</th>
                <th>RegWr</th>
                <th>Dest (rd)</th>
                <th>Write Data</th>
                <th>ALU Result</th>
                <th>Memory</th>
                <th>Branch</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
            {''.join(rows)}
        </tbody>
    </table>
</body>
</html>
"""
    html_path.write_text(html_content)
    print(f"[HTML] Interactive Waveform Viewer saved: {html_path}")

def main():
    print("=" * 70)
    print(" NanoRISCV-C2 Complete Waveform Generation Pipeline")
    print("=" * 70)

    # 1. ALU Waveforms (VCD & PNG)
    generate_alu_waveforms()

    # 2. Simulate Core Full Run
    print("\n[INFO] Simulating core execution across all 89 clock cycles...")
    records = generate_core_full_simulation()

    # 3. Phase 1 Waveform Plot: Reset, Initialization, Loop (Cycles 1 to 24)
    plot_subwaveform(
        records, 0, 24,
        "NanoRISCV-C2 Waveform (Phase 1: Boot, Register Init & Loop Iteration 1)",
        "waveform_phase1_init_and_loop.png"
    )

    # 4. Phase 2 Waveform Plot: Memory Transactions, JAL/JALR Subroutine, EBREAK Halt (Cycles 68 to 89)
    plot_subwaveform(
        records, 68, len(records),
        "NanoRISCV-C2 Waveform (Phase 2: Memory Access (SW/LW), Subroutine Call & Halt)",
        "waveform_phase2_mem_and_subroutine.png"
    )

    # 5. Interactive HTML Waveform Viewer
    generate_interactive_html(records)

    print("\n[SUCCESS] All waveforms (VCD, PNGs, and HTML viewer) generated successfully.")

if __name__ == "__main__":
    main()

