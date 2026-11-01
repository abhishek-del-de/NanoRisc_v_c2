# NanoRISCV-C2: Ultra-Compact 2-Stage RISC-V Processor Core for Embedded Control

[![HCLTech Career Shaper](https://img.shields.io/badge/Programme-HCLTech%20Career%20Shaper-blue.svg)](#)
[![ISA](https://img.shields.io/badge/ISA-RV32I%20Base%20Integer-orange.svg)](https://riscv.org)
[![Language](https://img.shields.io/badge/HDL-SystemVerilog%20IEEE%201800-green.svg)](#)
[![Verification](https://img.shields.io/badge/Verification-17%2F17%20Checks%20Passed-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-Academic%20Educational-lightgrey.svg)](#)

---

## 1. Project Overview

**NanoRISCV-C2** is a fully functional, synthesizable, ultra-compact 32-bit RISC-V processor implementing the unprivileged **RV32I Base Integer Instruction Set**. Developed as an individual four-week VLSI design and verification project under the **HCLTech Career Shaper Programme**, the core employs a streamlined **2-stage pipeline** microarchitecture optimized for area-constrained embedded control, IoT edge devices, and sensor interfaces.

### Core Objectives:
1. **Architectural Simplicity & Compactness:** Minimize silicon area and logic gate count by consolidating Decode, Execute, Memory, and Write-Back into a unified second stage.
2. **Strict RV32I ISA Compliance:** Full hardware support for arithmetic, logical, shift, comparison, memory, and control transfer instructions, plus explicit illegal instruction traps.
3. **Rigorous Verification:** Complete coverage of all 17 system verification points, self-checking SystemVerilog testbenches, and automated Python regression testing.
4. **Data-Driven Hardware Performance Analysis:** Generation and analysis of cycle-by-cycle execution traces, statistical summary tables, and publication-quality visualizations.

---

## 2. Microarchitecture

The processor divides instruction execution into two synchronous stages separated by an interstage pipeline register:

```
+------------------------------------+          +-------------------------------------------------------------+
|    STAGE 1: INSTRUCTION FETCH      |          |       STAGE 2: DECODE, EXECUTE, MEMORY, & WRITE-BACK        |
|                                    |          |                                                             |
|   +----+      +----------------+   |  IF/ID   |   +---------+     +---------------+     +-----+     +---+   |
|   | PC | ---> | Instruction    | --|--------> |   | Decoder | --> | Register File | --> | ALU | --> | D |   |
|   +----+      | Memory (4 KB)  |   | Register |   +---------+     | (32x32-bit)   |     +-----+     | M |   |
|     ^         +----------------+   |          |        |          +---------------+        |        | E |   |
|     |                              |          |        v                 |                 v        | M |   |
|   [Target PC / Redirect Mux] <-----|----------|-- [Hazard & Branch Unit] <------+          [WB Mux] <-- |   |
+------------------------------------+          +-------------------------------------------------------------+
```

### Stage 1: Instruction Fetch (IF)
- 32-bit Program Counter (`program_counter.sv`) with synchronous reset to `0x00000000`.
- 4 KB word-aligned Instruction Memory (`instruction_memory.sv`) initialized via hex programs.
- Low-latency PC redirection and flush control on branches/jumps.

### Stage 2: Decode, Execute, Memory, and Write-Back (EX)
- Instruction field decoding (`decoder.sv`) and full immediate sign-extension (`immediate_generator.sv`).
- 32x32-bit general-purpose Register File (`register_file.sv`) with hardwired $x_0 = 0$ invariance and internal write-through forwarding to eliminate RAW bubbles.
- 32-bit Arithmetic Logic Unit (`alu.sv`) executing ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU, and COPY_B.
- 4 KB Data Memory (`data_memory.sv`) supporting LW and SW with misaligned and out-of-bounds exception detection.
- Hazard Detection & Control Unit (`hazard_unit.sv`) managing conditional branch evaluations, branch target arithmetic, pipeline flushing, and clean EBREAK halts.

---

## 3. Technology Stack

- **RTL & Testbench Design:** IEEE 1800-2017 SystemVerilog.
- **Verification & Analysis Automation:** Python 3.13, Pandas, NumPy, Matplotlib.
- **Simulation Compatibility:** Icarus Verilog (`iverilog`), Verilator, ModelSim / QuestaSim.
- **Waveform Inspection:** GTKWave (`.vcd` dump).
- **Synthesis Flows:** Cadence Genus (`synth_genus.tcl`), Yosys Open-Source Synthesis (`synth_yosys.tcl`), Synopsys SDC (`constraints.sdc`).

---

## 4. Project Folder Structure

```
NanoRISC/
├── rtl/                                # Synthesizable SystemVerilog Hardware Modules
│   ├── nanoriscv_c2_pkg.sv             # Architectural constants, opcodes, and types
│   ├── program_counter.sv              # 32-bit Program Counter with redirect support
│   ├── instruction_memory.sv           # 4 KB Instruction Memory (ROM/RAM)
│   ├── pipeline_reg_if_id.sv           # Interstage IF/ID Pipeline Register with flush/stall
│   ├── decoder.sv                      # Combinational instruction field decoder
│   ├── immediate_generator.sv          # RV32I immediate extractor and sign-extender
│   ├── register_file.sv                # 32x32-bit Register File with internal forwarding
│   ├── alu.sv                          # 32-bit Arithmetic Logic Unit
│   ├── data_memory.sv                  # 4 KB Data Memory (LW/SW) with bounds check
│   ├── control_unit.sv                 # Main control and opcode decoder
│   ├── hazard_unit.sv                  # Hazard detection, branch evaluation, and flush
│   └── nanoriscv_c2_top.sv             # Top-level core integration & debug ports
├── testbench/                          # Verification Testbenches and Test Programs
│   ├── tb_alu.sv                       # Self-checking ALU unit testbench
│   ├── tb_nanoriscv_c2.sv              # Full processor core testbench with assertions
│   └── program.hex                     # Demonstration program machine code
├── scripts/                            # Automation, Simulation, and Data Analysis Scripts
│   ├── run_tests.py                    # Master test runner (EDA tools & cycle-accurate model)
│   ├── analyze_traces.py               # Trace dataset analytics & visualization generator
│   └── generate_report.py              # Performance aggregator and report generator
├── data/                               # Execution Trace Datasets
│   ├── dataset.csv                     # 75-record cycle-accurate execution trace
│   └── data_dictionary.csv             # Data dictionary explaining all columns
├── results/                            # Test Logs, Tables, and Visualizations
│   ├── test_log.txt                    # System verification requirement log (17/17 PASS)
│   ├── alu_test_log.txt                # ALU unit test log (30/30 PASS)
│   ├── performance_summary.txt         # Text performance summary
│   ├── execution_report.md             # Markdown execution report
│   ├── summary_tables/                 # Statistical CSV tables
│   │   ├── opcode_distribution.csv
│   │   ├── branch_summary.csv
│   │   ├── register_usage.csv
│   │   └── cycle_summary.csv
│   └── visualizations/                 # High-resolution publication plots (PNG)
│       ├── instruction_distribution_by_opcode.png
│       ├── branch_taken_vs_not_taken.png
│       ├── distribution_of_cycles_taken.png
│       └── register_destination_usage.png
├── synth/                              # Synthesis Scripts, Constraints & STA Reports
│   ├── constraints.sdc                 # Synopsys Design Constraints (100 MHz target)
│   ├── synth_genus.tcl                 # Cadence Genus synthesis script
│   ├── synth_yosys.tcl                 # Yosys open-source synthesis script
│   └── synthesis_report.md             # Synthesis analysis and area/timing estimates
├── docs/                               # Detailed Project Documentation & Reports
│   ├── architecture.md                 # Microarchitecture specification with Mermaid diagrams
│   ├── testing.md                      # Test plan, bug resolution, and verification matrix
│   └── project_report.md               # 8+ page comprehensive academic final report
├── ethical_compliance.md               # ISA sourcing, originality, and dataset declaration
├── requirements.txt                    # Python dependency specifications
└── README.md                           # Master project documentation
```

---

## 5. Prerequisites & Installation

### Python Environment:
Install the required Python data science libraries:
```bash
pip install -r requirements.txt
```

### EDA Simulator (Optional for Native HDL Run):
- **Icarus Verilog (`iverilog`) & `vvp`**
- **Verilator**
- **ModelSim / QuestaSim**
- **GTKWave** (for VCD waveform visualization)

---

## 6. Execution Commands

### A. One-Step Master Workflow
To run the complete automated test suite, trace analytics, and report generation in sequence:
```bash
python scripts/run_tests.py
python scripts/analyze_traces.py
python scripts/generate_report.py
```

### B. Native EDA Simulations (When Installed)
```bash
# 1. Run ALU Unit Testbench:
iverilog -g2012 -o results/tb_alu.vvp rtl/*.sv testbench/tb_alu.sv
vvp results/tb_alu.vvp

# 2. Run Processor Top Testbench:
iverilog -g2012 -o results/tb_nanoriscv_c2.vvp rtl/*.sv testbench/tb_nanoriscv_c2.sv
vvp results/tb_nanoriscv_c2.vvp

# 3. View Waveforms:
gtkwave nanoriscv_c2.vcd
```

---

## 7. Performance & Verification Summary

| Metric | Measured Hardware Result | Verification Status |
| :--- | :--- | :---: |
| **System Checkpoints** | **17 / 17 Verified** | **PASS** |
| **ALU Unit Test Suite** | **30 / 30 Verified** | **PASS** |
| **Retired Instructions** | **75 instructions** | **PASS** |
| **Total Processor Clock Cycles** | **89 cycles** | **PASS** |
| **Measured CPI** | **1.187 cycles / instruction** | **PASS** |
| **Branch Executions** | **11 evaluations (10 Not-Taken, 1 Taken)** | **PASS** |
| **Branch Taken Rate** | **9.1%** | **PASS** |
| **Load / Store Instructions** | **1 Load (LW), 2 Stores (SW)** | **PASS** |
| **Estimated Area (Core Logic)** | **2,900 — 3,600 Gate Equivalents (GE)** | **PASS** |
| **Estimated Fmax (65nm CMOS)** | **150 — 180 MHz** | **PASS** |

---

## 8. Visualizations Generated

All high-resolution figures are exported to `results/visualizations/`:
1. `instruction_distribution_by_opcode.png`: Breakdown of retired instructions across major RV32I formats.
2. `branch_taken_vs_not_taken.png`: Distribution of conditional branch outcomes and flush occurrences.
3. `distribution_of_cycles_taken.png`: Single-cycle vs. 2-cycle multi-cycle instruction latencies.
4. `register_destination_usage.png`: Frequency chart of architectural destination register writes ($x_1$ through $x_{11}$).

---

## 9. Known Limitations

1. **Sub-Word Memory Accesses:** Current implementation supports 32-bit word accesses (LW/SW). Byte and half-word operations (LB, LH, SB, SH) are unmapped and trigger the illegal instruction trap.
2. **Critical Path in Stage 2:** Consolidating RF read, ALU, and D-Mem read into Stage 2 limits $F_{\max}$ relative to a 5-stage pipeline, making it unsuitable for gigahertz server processing but optimal for microcontrollers.
3. **Single Core:** Multi-core snooping and atomic memory extensions (RV32A) are intentionally omitted.
