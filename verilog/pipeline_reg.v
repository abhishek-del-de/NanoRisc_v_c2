// =============================================================================
// Module: pipeline_reg.v
// Architecture: NanoRISC-V-C2 (IF/ID Pipeline Register)
// Description: Pure standard Verilog-2001 interstage pipeline register.
//              Synchronously registers PC, instruction word, and validity flag.
//              Supports synchronous flush (bubble injection) and stall freezing.
// =============================================================================

`timescale 1ns/1ps

module pipeline_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,
    input  wire [31:0] pc_f,
    input  wire [31:0] pc_plus4_f,
    input  wire [31:0] instr_f,
    output reg  [31:0] pc_d,
    output reg  [31:0] pc_plus4_d,
    output reg  [31:0] instr_d,
    output reg         valid_d
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_d       <= 32'd0;
            pc_plus4_d <= 32'd4;
            instr_d    <= 32'h00000013; // RV32I NOP (addi x0, x0, 0)
            valid_d    <= 1'b0;
        end else if (flush) begin
            // Clear Stage 2 with a bubble (NOP) on branch/jump redirect
            pc_d       <= pc_f;
            pc_plus4_d <= pc_plus4_f;
            instr_d    <= 32'h00000013;
            valid_d    <= 1'b0;
        end else if (!stall) begin
            pc_d       <= pc_f;
            pc_plus4_d <= pc_plus4_f;
            instr_d    <= instr_f;
            valid_d    <= 1'b1;
        end
    end

endmodule

