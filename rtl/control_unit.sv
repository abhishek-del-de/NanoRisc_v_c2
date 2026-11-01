// =============================================================================
// Project: NanoRISCV-C2
// File:    control_unit.sv
// Description: Main control unit for Stage 2 (Decode/Execute/Memory/Writeback).
//              Decodes instructions into ALU control, operand selection, memory
//              access controls, register write controls, branch/jump triggers,
//              and explicit illegal instruction trap detection.
// =============================================================================

`ifndef CONTROL_UNIT_SV
`define CONTROL_UNIT_SV

`timescale 1ns/1ps

module control_unit
    import nanoriscv_c2_pkg::*;
(
    input  logic [6:0]  opcode,
    input  logic [2:0]  funct3,
    input  logic [6:0]  funct7,
    input  logic [31:0] instr,
    output alu_op_t     alu_op,
    output logic [1:0]  alu_src_a,     // 00: RS1, 01: PC, 10: ZERO
    output logic        alu_src_b,     // 0: RS2, 1: Imm
    output logic        reg_write,     // Register file write enable
    output logic        mem_read,      // Data memory read enable (LW)
    output logic        mem_write,     // Data memory write enable (SW)
    output wb_src_t     wb_src,        // Writeback source selector
    output logic        is_branch,     // Conditional branch instruction
    output logic        is_jal,        // Unconditional jump (JAL)
    output logic        is_jalr,       // Indirect jump (JALR)
    output logic        is_fence,      // Memory fence (treated as NOP)
    output logic        is_ecall,      // System environment call
    output logic        is_ebreak,     // Breakpoint trap
    output logic        illegal_instr  // Undefined or unsupported instruction
);

    always_comb begin
        // Default safe control values to prevent latch inference
        alu_op        = ALU_ADD;
        alu_src_a     = ALU_SRC_A_RS1;
        alu_src_b     = ALU_SRC_B_RS2;
        reg_write     = 1'b0;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        wb_src        = WB_SRC_ALU;
        is_branch     = 1'b0;
        is_jal        = 1'b0;
        is_jalr       = 1'b0;
        is_fence      = 1'b0;
        is_ecall      = 1'b0;
        is_ebreak     = 1'b0;
        illegal_instr = 1'b0;

        case (opcode)
            // -----------------------------------------------------------------
            // R-Type: Register-Register ALU Operations
            // -----------------------------------------------------------------
            OPCODE_OP: begin
                reg_write = 1'b1;
                alu_src_a = ALU_SRC_A_RS1;
                alu_src_b = ALU_SRC_B_RS2;
                wb_src    = WB_SRC_ALU;

                case (funct3)
                    FUNCT3_ADD_SUB: begin
                        if (funct7 == FUNCT7_STANDARD)      alu_op = ALU_ADD;
                        else if (funct7 == FUNCT7_ALT)      alu_op = ALU_SUB;
                        else illegal_instr = 1'b1;
                    end
                    FUNCT3_SLL: begin
                        if (funct7 == FUNCT7_STANDARD)      alu_op = ALU_SLL;
                        else illegal_instr = 1'b1;
                    end
                    FUNCT3_SLT: begin
                        if (funct7 == FUNCT7_STANDARD)      alu_op = ALU_SLT;
                        else illegal_instr = 1'b1;
                    end
                    FUNCT3_SLTU: begin
                        if (funct7 == FUNCT7_STANDARD)      alu_op = ALU_SLTU;
                        else illegal_instr = 1'b1;
                    end
                    FUNCT3_XOR: begin
                        if (funct7 == FUNCT7_STANDARD)      alu_op = ALU_XOR;
                        else illegal_instr = 1'b1;
                    end
                    FUNCT3_SRL_SRA: begin
                        if (funct7 == FUNCT7_STANDARD)      alu_op = ALU_SRL;
                        else if (funct7 == FUNCT7_ALT)      alu_op = ALU_SRA;
                        else illegal_instr = 1'b1;
                    end
                    FUNCT3_OR: begin
                        if (funct7 == FUNCT7_STANDARD)      alu_op = ALU_OR;
                        else illegal_instr = 1'b1;
                    end
                    FUNCT3_AND: begin
                        if (funct7 == FUNCT7_STANDARD)      alu_op = ALU_AND;
                        else illegal_instr = 1'b1;
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end

            // -----------------------------------------------------------------
            // I-Type: Immediate ALU Operations
            // -----------------------------------------------------------------
            OPCODE_OP_IMM: begin
                reg_write = 1'b1;
                alu_src_a = ALU_SRC_A_RS1;
                alu_src_b = ALU_SRC_B_IMM;
                wb_src    = WB_SRC_ALU;

                case (funct3)
                    FUNCT3_ADD_SUB: alu_op = ALU_ADD; // ADDI
                    FUNCT3_SLT:     alu_op = ALU_SLT; // SLTI
                    FUNCT3_SLTU:    alu_op = ALU_SLTU; // SLTIU
                    FUNCT3_XOR:     alu_op = ALU_XOR; // XORI
                    FUNCT3_OR:      alu_op = ALU_OR;  // ORI
                    FUNCT3_AND:     alu_op = ALU_AND; // ANDI
                    FUNCT3_SLL: begin
                        // Shift amount imm[4:0], imm[11:5] must be 0
                        if (instr[31:25] == 7'b0000000) alu_op = ALU_SLL; // SLLI
                        else illegal_instr = 1'b1;
                    end
                    FUNCT3_SRL_SRA: begin
                        if (instr[31:25] == 7'b0000000)      alu_op = ALU_SRL; // SRLI
                        else if (instr[31:25] == 7'b0100000) alu_op = ALU_SRA; // SRAI
                        else illegal_instr = 1'b1;
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end

            // -----------------------------------------------------------------
            // Load: LW (Load Word)
            // -----------------------------------------------------------------
            OPCODE_LOAD: begin
                case (funct3)
                    FUNCT3_LW: begin
                        reg_write = 1'b1;
                        mem_read  = 1'b1;
                        alu_src_a = ALU_SRC_A_RS1;
                        alu_src_b = ALU_SRC_B_IMM;
                        alu_op    = ALU_ADD; // Calculate effective byte address
                        wb_src    = WB_SRC_MEM;
                    end
                    default: illegal_instr = 1'b1; // Unimplemented sub-word loads
                endcase
            end

            // -----------------------------------------------------------------
            // Store: SW (Store Word)
            // -----------------------------------------------------------------
            OPCODE_STORE: begin
                case (funct3)
                    FUNCT3_SW: begin
                        mem_write = 1'b1;
                        alu_src_a = ALU_SRC_A_RS1;
                        alu_src_b = ALU_SRC_B_IMM;
                        alu_op    = ALU_ADD; // Calculate effective byte address
                    end
                    default: illegal_instr = 1'b1; // Unimplemented sub-word stores
                endcase
            end

            // -----------------------------------------------------------------
            // Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // -----------------------------------------------------------------
            OPCODE_BRANCH: begin
                is_branch = 1'b1;
                alu_src_a = ALU_SRC_A_RS1;
                alu_src_b = ALU_SRC_B_RS2;

                case (funct3)
                    FUNCT3_BEQ,
                    FUNCT3_BNE:  alu_op = ALU_SUB;  // Zero flag tested
                    FUNCT3_BLT,
                    FUNCT3_BGE:  alu_op = ALU_SLT;  // Signed comparison tested
                    FUNCT3_BLTU,
                    FUNCT3_BGEU: alu_op = ALU_SLTU; // Unsigned comparison tested
                    default:     illegal_instr = 1'b1;
                endcase
            end

            // -----------------------------------------------------------------
            // JAL: Jump and Link
            // -----------------------------------------------------------------
            OPCODE_JAL: begin
                is_jal    = 1'b1;
                reg_write = 1'b1;
                wb_src    = WB_SRC_PC4; // rd <= PC + 4
            end

            // -----------------------------------------------------------------
            // JALR: Jump and Link Register
            // -----------------------------------------------------------------
            OPCODE_JALR: begin
                if (funct3 == 3'b000) begin
                    is_jalr   = 1'b1;
                    reg_write = 1'b1;
                    wb_src    = WB_SRC_PC4; // rd <= PC + 4
                    alu_src_a = ALU_SRC_A_RS1;
                    alu_src_b = ALU_SRC_B_IMM;
                    alu_op    = ALU_ADD;    // Target = (rs1 + imm) & ~1
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            // -----------------------------------------------------------------
            // LUI: Load Upper Immediate
            // -----------------------------------------------------------------
            OPCODE_LUI: begin
                reg_write = 1'b1;
                wb_src    = WB_SRC_IMM; // rd <= imm_u
            end

            // -----------------------------------------------------------------
            // AUIPC: Add Upper Immediate to PC
            // -----------------------------------------------------------------
            OPCODE_AUIPC: begin
                reg_write = 1'b1;
                alu_src_a = ALU_SRC_A_PC;
                alu_src_b = ALU_SRC_B_IMM;
                alu_op    = ALU_ADD;    // rd <= PC + imm_u
                wb_src    = WB_SRC_ALU;
            end

            // -----------------------------------------------------------------
            // System: ECALL, EBREAK
            // -----------------------------------------------------------------
            OPCODE_SYSTEM: begin
                if (funct3 == FUNCT3_SYSTEM) begin
                    if (instr[31:20] == 12'h000) begin
                        is_ecall = 1'b1;
                    end else if (instr[31:20] == 12'h001) begin
                        is_ebreak = 1'b1;
                    end else begin
                        illegal_instr = 1'b1;
                    end
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            // -----------------------------------------------------------------
            // FENCE: Memory fence (NOP in this single-core implementation)
            // -----------------------------------------------------------------
            OPCODE_FENCE: begin
                is_fence = 1'b1;
            end

            // -----------------------------------------------------------------
            // Default: Illegal / Unimplemented Opcode Trap
            // -----------------------------------------------------------------
            default: begin
                illegal_instr = 1'b1;
            end
        endcase

        // If instruction is detected as illegal, suppress state mutations
        if (illegal_instr) begin
            reg_write = 1'b0;
            mem_read  = 1'b0;
            mem_write = 1'b0;
        end
    end

endmodule

`endif // CONTROL_UNIT_SV

