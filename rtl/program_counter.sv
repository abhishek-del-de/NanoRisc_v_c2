// =============================================================================
// Project: NanoRISCV-C2
// File:    program_counter.sv
// Description: Synthesizable 32-bit Program Counter module for Stage 1 (IF).
//              Manages sequential fetching, pipeline stalls, and branch/jump redirects.
// =============================================================================

`ifndef PROGRAM_COUNTER_SV
`define PROGRAM_COUNTER_SV

`timescale 1ns/1ps

module program_counter
    import nanoriscv_c2_pkg::*;
#(
    parameter logic [31:0] RESET_ADDR = BOOT_ADDR
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stall,       // Freeze PC during pipeline stall
    input  logic        pc_src,      // 0: Sequential (PC+4), 1: Redirect (target_pc)
    input  logic [31:0] target_pc,   // Target address from branch or jump (Stage 2)
    output logic [31:0] pc,          // Current fetch PC
    output logic [31:0] pc_plus4     // Next sequential PC
);

    // Sequential PC adder (+4 bytes = 1 instruction word)
    assign pc_plus4 = pc + 32'd4;

    // Next PC selection logic
    logic [31:0] next_pc;
    assign next_pc = pc_src ? target_pc : pc_plus4;

    // Synchronous PC register with active-low asynchronous reset
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_ADDR;
        end else if (!stall) begin
            pc <= next_pc;
        end
    end

endmodule

`endif // PROGRAM_COUNTER_SV

