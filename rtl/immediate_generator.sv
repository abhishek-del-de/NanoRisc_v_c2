// =============================================================================
// Project: NanoRISCV-C2
// File:    immediate_generator.sv
// Description: Immediate Generator decoding and sign-extending I, S, B, U,
//              and J format immediates conforming strictly to RV32I specification.
// =============================================================================

`ifndef IMMEDIATE_GENERATOR_SV
`define IMMEDIATE_GENERATOR_SV

`timescale 1ns/1ps

module immediate_generator
    import nanoriscv_c2_pkg::*;
(
    input  logic [31:0] instr,
    output logic [31:0] imm_i,
    output logic [31:0] imm_s,
    output logic [31:0] imm_b,
    output logic [31:0] imm_u,
    output logic [31:0] imm_j,
    output logic [31:0] imm_out // Selected immediate based on opcode
);

    wire [6:0] opcode = instr[6:0];

    // I-type immediate (used for ADDI, SLTI, LW, JALR, etc.)
    assign imm_i = {{20{instr[31]}}, instr[31:20]};

    // S-type immediate (used for SW, SB, SH)
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // B-type immediate (used for BEQ, BNE, BLT, BGE, BLTU, BGEU)
    // Note: bit 0 is implicitly 0
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

    // U-type immediate (used for LUI, AUIPC)
    assign imm_u = {instr[31:12], 12'b0};

    // J-type immediate (used for JAL)
    // Note: bit 0 is implicitly 0
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // Muxing to produce imm_out based on opcode
    always_comb begin
        case (opcode)
            OPCODE_OP_IMM,
            OPCODE_LOAD,
            OPCODE_JALR:     imm_out = imm_i;
            OPCODE_STORE:    imm_out = imm_s;
            OPCODE_BRANCH:   imm_out = imm_b;
            OPCODE_LUI,
            OPCODE_AUIPC:    imm_out = imm_u;
            OPCODE_JAL:      imm_out = imm_j;
            default:         imm_out = imm_i;
        endcase
    end

endmodule

`endif // IMMEDIATE_GENERATOR_SV

