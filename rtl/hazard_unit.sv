// =============================================================================
// Project: NanoRISCV-C2
// File:    hazard_unit.sv
// Description: Hazard detection, branch resolution, target calculation,
//              and pipeline control unit for the 2-stage NanoRISCV-C2 core.
// =============================================================================

`ifndef HAZARD_UNIT_SV
`define HAZARD_UNIT_SV

`timescale 1ns/1ps

module hazard_unit
    import nanoriscv_c2_pkg::*;
(
    input  logic        valid_d,           // Validity flag of Stage 2 instruction
    input  logic        is_branch,         // Stage 2 instruction is a branch
    input  logic        is_jal,            // Stage 2 instruction is JAL
    input  logic        is_jalr,           // Stage 2 instruction is JALR
    input  logic        is_ebreak,         // EBREAK trigger
    input  logic        is_ecall,          // ECALL trigger
    input  logic        illegal_instr,     // Illegal instruction trap
    input  logic [2:0]  funct3,            // Branch condition type
    input  logic        zero,              // ALU zero flag (rdata1 == rdata2)
    input  logic        cmp_result,        // ALU comparison flag (SLT / SLTU)
    input  logic [31:0] pc_d,              // Stage 2 PC
    input  logic [31:0] imm_b,             // Branch offset
    input  logic [31:0] imm_j,             // JAL offset
    input  logic [31:0] imm_i,             // JALR offset
    input  logic [31:0] rdata1,            // RS1 value for JALR base address
    output logic        branch_taken,      // High if branch condition is met
    output logic        pc_src,            // 0: Sequential PC+4, 1: Redirect
    output logic [31:0] target_pc,         // Calculated branch or jump target
    output logic        flush_d,           // Flush Stage 1 pipeline register
    output logic        stall_f,           // Stall Stage 1 PC fetch
    output logic        stall_d,           // Stall Stage 2 pipeline register
    output logic        halt,              // Core execution halted (EBREAK/ECALL)
    output logic        trap               // Hardware trap asserted
);

    // Evaluate branch condition
    always_comb begin
        branch_taken = 1'b0;
        if (valid_d && is_branch) begin
            case (funct3)
                FUNCT3_BEQ:  branch_taken = zero;
                FUNCT3_BNE:  branch_taken = !zero;
                FUNCT3_BLT:  branch_taken = cmp_result;
                FUNCT3_BGE:  branch_taken = !cmp_result;
                FUNCT3_BLTU: branch_taken = cmp_result;
                FUNCT3_BGEU: branch_taken = !cmp_result;
                default:     branch_taken = 1'b0;
            endcase
        end
    end

    // Compute redirect target address
    always_comb begin
        target_pc = 32'd0;
        if (is_branch) begin
            target_pc = pc_d + imm_b;
        end else if (is_jal) begin
            target_pc = pc_d + imm_j;
        end else if (is_jalr) begin
            // RV32I specification: target is (rs1 + imm) with bit 0 set to 0
            target_pc = (rdata1 + imm_i) & 32'hFFFFFFFE;
        end
    end

    // Control transfer detection (taken branch or jump)
    wire redirect = valid_d && (branch_taken || is_jal || is_jalr);

    // PC redirection and pipeline flush logic
    assign pc_src  = redirect;
    assign flush_d = redirect; // Discard sequential instruction in Stage 1

    // Halt and trap logic
    assign halt = valid_d && (is_ebreak || is_ecall || illegal_instr);
    assign trap = valid_d && (illegal_instr || is_ecall);

    // When halted, freeze the entire processor pipeline
    assign stall_f = halt;
    assign stall_d = halt;

endmodule

`endif // HAZARD_UNIT_SV

