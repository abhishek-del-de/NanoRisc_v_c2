# =============================================================================
# Project: NanoRISCV-C2
# File:    synth/synth_genus.tcl
# Description: Cadence Genus Synthesis Script for NanoRISCV-C2 Top Core
# =============================================================================

# 1. Environment & Search Path Setup
set_db init_lib_search_path {./lib /cad/libraries/typical}
set_db init_hdl_search_path {../rtl}

# Set Target Technology Standard Cell Library (e.g., TSMC 65nm / 45nm typical)
set_db target_library {typical_cells.lib}
set_db link_library   {* typical_cells.lib}

# 2. Read SystemVerilog Source Files
read_hdl -language sv {
    ../rtl/nanoriscv_c2_pkg.sv
    ../rtl/program_counter.sv
    ../rtl/instruction_memory.sv
    ../rtl/pipeline_reg_if_id.sv
    ../rtl/decoder.sv
    ../rtl/immediate_generator.sv
    ../rtl/register_file.sv
    ../rtl/alu.sv
    ../rtl/data_memory.sv
    ../rtl/control_unit.sv
    ../rtl/hazard_unit.sv
    ../rtl/nanoriscv_c2_top.sv
}

# 3. Elaborate Top-Level Module
elaborate nanoriscv_c2_top

# Check design integrity and unresolved references
check_design -unresolved

# 4. Load Timing Constraints (SDC)
read_sdc ./constraints.sdc

# 5. Synthesize to Generic Logic
syn_generic

# 6. Map to Target Technology Standard Cells
syn_map

# 7. Optimize Gate-Level Netlist
syn_opt -effort high

# 8. Generate Reports
mkdir -p ./reports
report_timing > ./reports/timing_genus.rpt
report_area   > ./reports/area_genus.rpt
report_power  > ./reports/power_genus.rpt
report_qor    > ./reports/qor_genus.rpt

# 9. Export Gate-Level Netlist and Constraints
write_hdl > ./nanoriscv_c2_netlist.v
write_sdc > ./nanoriscv_c2_out.sdc

puts "=== Cadence Genus Synthesis Completed Successfully ==="
exit

