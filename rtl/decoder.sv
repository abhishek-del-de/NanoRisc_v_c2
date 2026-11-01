// =============================================================================
// Project: NanoRISCV-C2
// File:    decoder.sv
// Description: Pure combinational instruction field decoder extracting
//              opcode, register addresses, function codes, and format categories.
// =============================================================================

`ifndef DECODER_SV
`define DECODER_SV

`timescale 1ns/1ps

module decoder
    import nanoriscv_c2_pkg::*;
(
    input  logic [31:0] instr,
    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [6:0]  funct7,
    output logic        is_r_type,
    output logic        is_i_type,
    output logic        is_s_type,
    output logic        is_b_type,
    output logic        is_u_type,
    output logic        is_j_type
);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // Format classification based on RV32I opcode map
    always_comb begin
        is_r_type = (opcode == OPCODE_OP);
        is_i_type = (opcode == OPCODE_OP_IMM) || (opcode == OPCODE_LOAD) ||
                    (opcode == OPCODE_JALR)   || (opcode == OPCODE_SYSTEM) ||
                    (opcode == OPCODE_FENCE);
        is_s_type = (opcode == OPCODE_STORE);
        is_b_type = (opcode == OPCODE_BRANCH);
        is_u_type = (opcode == OPCODE_LUI)    || (opcode == OPCODE_AUIPC);
        is_j_type = (opcode == OPCODE_JAL);
    end

endmodule

`endif // DECODER_SV

