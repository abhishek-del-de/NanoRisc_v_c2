// =============================================================================
// Project: NanoRISCV-C2
// File:    pipeline_reg_if_id.sv
// Description: Pipeline register separating Stage 1 (IF) and Stage 2 (EX/MEM/WB).
//              Provides synchronous holding, flush (bubble insertion on branch),
//              and stall capabilities for hazard resolution.
// =============================================================================

`ifndef PIPELINE_REG_IF_ID_SV
`define PIPELINE_REG_IF_ID_SV

`timescale 1ns/1ps

module pipeline_reg_if_id
    import nanoriscv_c2_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        stall,        // Freeze pipeline register
    input  logic        flush,        // Insert bubble (invalidate instruction on branch/jump)
    input  logic [31:0] pc_f,         // Fetch stage PC
    input  logic [31:0] pc_plus4_f,   // Fetch stage PC+4
    input  logic [31:0] instr_f,      // Fetched instruction word
    output logic [31:0] pc_d,         // Registered PC for Decode/Execute
    output logic [31:0] pc_plus4_d,   // Registered PC+4 for Decode/Execute
    output logic [31:0] instr_d,      // Registered Instruction for Decode/Execute
    output logic        valid_d       // Valid indicator for Stage 2
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_d       <= BOOT_ADDR;
            pc_plus4_d <= BOOT_ADDR + 32'd4;
            instr_d    <= NOP_INSTR;
            valid_d    <= 1'b0;
        end else if (flush) begin
            // Insert NOP bubble and mark invalid
            pc_d       <= pc_f;
            pc_plus4_d <= pc_plus4_f;
            instr_d    <= NOP_INSTR;
            valid_d    <= 1'b0;
        end else if (!stall) begin
            pc_d       <= pc_f;
            pc_plus4_d <= pc_plus4_f;
            instr_d    <= instr_f;
            valid_d    <= 1'b1;
        end
        // If stall is high, maintain current register values
    end

endmodule

`endif // PIPELINE_REG_IF_ID_SV

