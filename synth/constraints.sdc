# =============================================================================
# Project: NanoRISCV-C2
# File:    synth/constraints.sdc
# Description: Synopsys Design Constraints (SDC) for NanoRISCV-C2 Top Module
# =============================================================================

# Define Target Clock: 100 MHz (Period = 10.0 ns)
create_clock -name clk -period 10.000 [get_ports clk]

# Clock Uncertainty and Jitter (100 ps)
set_clock_uncertainty 0.100 [get_clocks clk]

# Clock Transition / Slew
set_clock_transition 0.080 [get_clocks clk]

# Asynchronous Reset Constraints
set_false_path -from [get_ports rst_n]

# Input Delays (Assuming 20% of clock period budget for external driving logic)
set_input_delay -clock clk -max 2.000 [get_ports rst_n]
set_input_delay -clock clk -min 0.200 [get_ports rst_n]

# Output Delays (Assuming 20% of clock period budget for external capturing logic)
set_output_delay -clock clk -max 2.000 [get_ports debug_*]
set_output_delay -clock clk -min 0.200 [get_ports debug_*]
set_output_delay -clock clk -max 2.000 [get_ports perf_*]
set_output_delay -clock clk -min 0.200 [get_ports perf_*]

# Drive Strength and Load
set_load 0.050 [all_outputs]

