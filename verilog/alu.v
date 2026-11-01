// =============================================================================
// Module: alu.v
// Architecture: NanoRISC-V-C2 (Stage 2 Execution)
// Description: Pure standard Verilog-2001 32-bit Arithmetic Logic Unit (ALU).
//              Supports all RV32I arithmetic, logic, shift, and comparison ops.
// =============================================================================

`timescale 1ns/1ps

module alu (
    input  wire [3:0]  alu_op,
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    output reg  [31:0] result,
    output wire        zero,
    output wire        cmp_result
);

    wire [4:0] shamt = operand_b[4:0];

    wire signed [31:0] signed_a = operand_a;
    wire signed [31:0] signed_b = operand_b;

    wire signed_less_than   = (signed_a < signed_b);
    wire unsigned_less_than = (operand_a < operand_b);

    always @(*) begin
        case (alu_op)
            4'b0000: result = operand_a + operand_b;                   // ADD
            4'b0001: result = operand_a - operand_b;                   // SUB
            4'b0010: result = operand_a & operand_b;                   // AND
            4'b0011: result = operand_a | operand_b;                   // OR
            4'b0100: result = operand_a ^ operand_b;                   // XOR
            4'b0101: result = operand_a << shamt;                      // SLL
            4'b0110: result = operand_a >> shamt;                      // SRL
            4'b0111: result = $signed(signed_a >>> shamt);             // SRA
            4'b1000: result = signed_less_than ? 32'd1 : 32'd0;        // SLT
            4'b1001: result = unsigned_less_than ? 32'd1 : 32'd0;      // SLTU
            4'b1010: result = operand_b;                               // COPY_B (for LUI)
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
    assign cmp_result = (alu_op == 4'b1001) ? unsigned_less_than : signed_less_than;

endmodule

