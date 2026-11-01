# =============================================================================
# Project: NanoRISCV-C2
# File:    synth/synth_yosys.tcl
# Description: Open-Source Yosys Synthesis Script for NanoRISCV-C2 Core
# =============================================================================

# Read SystemVerilog RTL files
yosys read_verilog -sv ../rtl/nanoriscv_c2_pkg.sv
yosys read_verilog -sv ../rtl/program_counter.sv
yosys read_verilog -sv ../rtl/instruction_memory.sv
yosys read_verilog -sv ../rtl/pipeline_reg_if_id.sv
yosys read_verilog -sv ../rtl/decoder.sv
yosys read_verilog -sv ../rtl/immediate_generator.sv
yosys read_verilog -sv ../rtl/register_file.sv
yosys read_verilog -sv ../rtl/alu.sv
yosys read_verilog -sv ../rtl/data_memory.sv
yosys read_verilog -sv ../rtl/control_unit.sv
yosys read_verilog -sv ../rtl/hazard_unit.sv
yosys read_verilog -sv ../rtl/nanoriscv_c2_top.sv

# Hierarchy elaboration
yosys hierarchy -top nanoriscv_c2_top

# Check for latch inference or design errors
yosys check

# High-level synthesis optimization
yosys proc
yosys opt
yosys fsm
yosys opt
yosys memory
yosys opt

# Generic logic synthesis
yosys synth -top nanoriscv_c2_top

# Technology mapping to generic gates
yosys dfflibmap -liberty ./lib/cmos_cells.lib
yosys abc -liberty ./lib/cmos_cells.lib

# Print area and cell count statistics
yosys stat

# Write synthesized gate-level netlist
yosys write_verilog ./nanoriscv_c2_synth_yosys.v

