# NanoRISCV-C2: Automated Execution & Verification Report

**Project:** NanoRISCV-C2 — Ultra-Compact 2-Stage RISC-V Core for Embedded Control  
**Programme:** HCLTech Career Shaper Programme — 4-Week VLSI Project  
**Target Architecture:** RV32I (32-bit Base Integer RISC-V)  
**Pipeline Topology:** 2-Stage (Stage 1: IF, Stage 2: EX/MEM/WB)  

---

## 1. Executive Summary & Verification Status

| Metric | Measured Value | Verification Target | Status |
| :--- | :--- | :--- | :--- |
| **System Verification Requirements** | 17 / 17 Verified | 17 Checkpoints | **PASS** |
| **ALU Unit Test Suite** | 30 / 30 Passed | 30 Operations & Corners | **PASS** |
| **Architectural State Invariance (x0)** | Strictly Zero (0x00000000) | Hardwired 0 | **PASS** |
| **Program Termination Trap** | Clean EBREAK Halt | Graceful Halt | **PASS** |
| **Register File Correctness** | x1=0x48, x2=10, x3=50, x8=50, x9=45, x10=180, x11=42 | Match Expected | **PASS** |
| **Data Memory Integrity** | Mem[256]=50, Mem[260]=180 | Match Expected | **PASS** |

---

## 2. Microarchitectural Performance Metrics

Measured from cycle-accurate trace execution of `program.hex` (75 retired instructions):

- **Total Retired Instructions:** `75`
- **Total Processor Clock Cycles:** `89`
- **Measured CPI (Cycles Per Instruction):** `1.187`
- **Branch Evaluation Count:** `11`
- **Branches Taken:** `1`
- **Branches Not-Taken:** `10`
- **Branch-Taken Rate:** `9.1%`
- **Memory Load Operations (LW):** `1` (1.3%)
- **Memory Store Operations (SW):** `2` (2.7%)

---

## 3. Microarchitectural CPI Analysis

The NanoRISCV-C2 2-stage core achieves an ideal base CPI of **1.0** for uninterrupted sequential execution. The measured CPI of **1.187** is rigorously explained by control hazard penalties:
1. **Loop Jumps (`JAL x0, -20`):** 10 iterations × 1 flush cycle penalty = **10 penalty cycles**
2. **Loop Exit Branch (`BEQ taken`):** 1 taken branch × 1 flush cycle penalty = **1 penalty cycle**
3. **Subroutine Call (`JAL x1, 16`):** 1 call × 1 flush cycle penalty = **1 penalty cycle**
4. **Subroutine Return (`JALR x0, 0(x1)`):** 1 return × 1 flush cycle penalty = **1 penalty cycle**
5. **Initial Pipeline Fill:** 1 cycle on reset de-assertion = **1 cycle**

$$\text{Total Cycles} = 75 \text{ instructions} + 14 \text{ penalty cycles} = 89 \text{ cycles}$$
$$\text{Measured CPI} = \frac{89}{75} = 1.187$$

---

## 4. Generated Artifacts Summary

- **Execution Trace Dataset:** `data/dataset.csv` (75 records)
- **Data Dictionary:** `data/data_dictionary.csv`
- **Statistical Tables:**
  - `results/summary_tables/opcode_distribution.csv`
  - `results/summary_tables/branch_summary.csv`
  - `results/summary_tables/register_usage.csv`
  - `results/summary_tables/cycle_summary.csv`
- **Visualizations:**
  - `results/visualizations/instruction_distribution_by_opcode.png`
  - `results/visualizations/branch_taken_vs_not_taken.png`
  - `results/visualizations/distribution_of_cycles_taken.png`
  - `results/visualizations/register_destination_usage.png`
- **RTL Source Files:** 12 modules in `rtl/`
- **Verification Testbenches:** `testbench/tb_alu.sv`, `testbench/tb_nanoriscv_c2.sv`, `testbench/program.hex`
