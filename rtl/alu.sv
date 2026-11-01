// =============================================================================
// Project: NanoRISCV-C2
// File:    alu.sv
// Description: Synthesizable 32-bit Arithmetic Logic Unit (ALU) supporting
//              all RV32I arithmetic, logical, shift, and comparison operations.
// =============================================================================

`ifndef ALU_SV
`define ALU_SV

`timescale 1ns/1ps

module alu
    import nanoriscv_c2_pkg::*;
(
    input  logic [3:0]        alu_op,      // ALU Operation select
    input  logic [31:0]       operand_a,   // Operand A (from RS1 or PC)
    input  logic [31:0]       operand_b,   // Operand B (from RS2 or Imm)
    output logic [31:0]       result,      // ALU Output Result
    output logic              zero,        // High if result == 0
    output logic              cmp_result   // Comparison result (for conditional branches)
);

    // Shift amount is taken from lower 5 bits of operand_b as per RV32I specification
    wire [4:0] shamt = operand_b[4:0];

    // Signed casts for arithmetic shifts and signed comparisons
    wire signed [31:0] signed_a = $signed(operand_a);
    wire signed [31:0] signed_b = $signed(operand_b);

    // Combinational evaluation of comparison conditions
    wire signed_less_than   = (signed_a < signed_b);
    wire unsigned_less_than = (operand_a < operand_b);

    always_comb begin
        case (alu_op)
            ALU_ADD:    result = operand_a + operand_b;
            ALU_SUB:    result = operand_a - operand_b;
            ALU_AND:    result = operand_a & operand_b;
            ALU_OR:     result = operand_a | operand_b;
            ALU_XOR:    result = operand_a ^ operand_b;
            ALU_SLL:    result = operand_a << shamt;
            ALU_SRL:    result = operand_a >> shamt;
            ALU_SRA:    result = $unsigned(signed_a >>> shamt);
            ALU_SLT:    result = signed_less_than ? 32'd1 : 32'd0;
            ALU_SLTU:   result = unsigned_less_than ? 32'd1 : 32'd0;
            ALU_COPY_B: result = operand_b;
            default:    result = 32'd0;
        endcase
    end

    // Zero flag output
    assign zero = (result == 32'd0);

    // Dedicated comparison output flag for branch evaluation
    assign cmp_result = (alu_op == ALU_SLTU) ? unsigned_less_than : signed_less_than;

endmodule

`endif // ALU_SV

