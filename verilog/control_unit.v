// =============================================================================
// Module: control_unit.v
// Architecture: NanoRISC-V-C2 (Stage 2 Decode & Control)
// Description: Pure standard Verilog-2001 main decoder, immediate generator,
//              branch evaluator, and pipeline control unit.
// =============================================================================

`timescale 1ns/1ps

module control_unit (
    input  wire [31:0] instr,
    input  wire        valid_d,
    input  wire        alu_zero,
    input  wire        alu_cmp,
    output reg  [3:0]  alu_op,
    output reg  [1:0]  alu_src_a,      // 00: RS1, 01: PC, 10: ZERO
    output reg         alu_src_b,      // 0: RS2, 1: Imm
    output reg         reg_write,
    output reg         mem_read,
    output reg         mem_write,
    output reg  [1:0]  wb_src,         // 00: ALU, 01: MEM, 10: PC+4, 11: Imm
    output reg  [31:0] imm_out,
    output reg         branch_taken,
    output wire        pc_src,
    output wire        flush,
    output wire        halt,
    output reg         illegal_instr
);

    wire [6:0] opcode = instr[6:0];
    wire [2:0] funct3 = instr[14:12];
    wire [6:0] funct7 = instr[31:25];

    // Immediate Formats
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    reg is_branch;
    reg is_jal;
    reg is_jalr;
    reg is_ebreak;

    always @(*) begin
        // Defaults
        alu_op        = 4'b0000; // ADD
        alu_src_a     = 2'b00;   // RS1
        alu_src_b     = 1'b0;    // RS2
        reg_write     = 1'b0;
        mem_read      = 1'b0;
        mem_write     = 1'b0;
        wb_src        = 2'b00;   // ALU
        imm_out       = imm_i;
        is_branch     = 1'b0;
        is_jal        = 1'b0;
        is_jalr       = 1'b0;
        is_ebreak     = 1'b0;
        illegal_instr = 1'b0;

        case (opcode)
            // R-Type: Register-Register ALU Operations
            7'b0110011: begin
                reg_write = 1'b1;
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                wb_src    = 2'b00;
                case (funct3)
                    3'b000: alu_op = (funct7 == 7'b0100000) ? 4'b0001 : 4'b0000; // SUB : ADD
                    3'b001: alu_op = 4'b0101; // SLL
                    3'b010: alu_op = 4'b1000; // SLT
                    3'b011: alu_op = 4'b1001; // SLTU
                    3'b100: alu_op = 4'b0100; // XOR
                    3'b101: alu_op = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // SRA : SRL
                    3'b110: alu_op = 4'b0011; // OR
                    3'b111: alu_op = 4'b0010; // AND
                    default: illegal_instr = 1'b1;
                endcase
            end

            // I-Type: Immediate ALU Operations
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src_a = 2'b00;
                alu_src_b = 1'b1;
                wb_src    = 2'b00;
                imm_out   = imm_i;
                case (funct3)
                    3'b000: alu_op = 4'b0000; // ADDI
                    3'b001: alu_op = 4'b0101; // SLLI
                    3'b010: alu_op = 4'b1000; // SLTI
                    3'b011: alu_op = 4'b1001; // SLTIU
                    3'b100: alu_op = 4'b0100; // XORI
                    3'b101: alu_op = (funct7 == 7'b0100000) ? 4'b0111 : 4'b0110; // SRAI : SRLI
                    3'b110: alu_op = 4'b0011; // ORI
                    3'b111: alu_op = 4'b0010; // ANDI
                    default: illegal_instr = 1'b1;
                endcase
            end

            // Load: LW
            7'b0000011: begin
                if (funct3 == 3'b010) begin
                    reg_write = 1'b1;
                    mem_read  = 1'b1;
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1;
                    alu_op    = 4'b0000; // Effective byte address = RS1 + imm
                    wb_src    = 2'b01;   // Data Memory
                    imm_out   = imm_i;
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            // Store: SW
            7'b0100011: begin
                if (funct3 == 3'b010) begin
                    mem_write = 1'b1;
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1;
                    alu_op    = 4'b0000; // Effective byte address = RS1 + imm
                    imm_out   = imm_s;
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            // Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU
            7'b1100011: begin
                is_branch = 1'b1;
                alu_src_a = 2'b00;
                alu_src_b = 1'b0;
                imm_out   = imm_b;
                case (funct3)
                    3'b000, 3'b001: alu_op = 4'b0001; // BEQ, BNE -> SUB (Zero checked)
                    3'b100, 3'b101: alu_op = 4'b1000; // BLT, BGE -> SLT (Signed cmp checked)
                    3'b110, 3'b111: alu_op = 4'b1001; // BLTU, BGEU -> SLTU (Unsigned cmp checked)
                    default: illegal_instr = 1'b1;
                endcase
            end

            // JAL: Jump and Link
            7'b1101111: begin
                is_jal    = 1'b1;
                reg_write = 1'b1;
                wb_src    = 2'b10; // PC + 4
                imm_out   = imm_j;
            end

            // JALR: Jump and Link Register
            7'b1100111: begin
                if (funct3 == 3'b000) begin
                    is_jalr   = 1'b1;
                    reg_write = 1'b1;
                    wb_src    = 2'b10; // PC + 4
                    alu_src_a = 2'b00;
                    alu_src_b = 1'b1;
                    alu_op    = 4'b0000; // Target = (RS1 + imm) & ~1
                    imm_out   = imm_i;
                end else begin
                    illegal_instr = 1'b1;
                end
            end

            // LUI: Load Upper Immediate
            7'b0110111: begin
                reg_write = 1'b1;
                wb_src    = 2'b11; // Upper Immediate
                imm_out   = imm_u;
            end

            // AUIPC: Add Upper Immediate to PC
            7'b0010111: begin
                reg_write = 1'b1;
                alu_src_a = 2'b01; // PC
                alu_src_b = 1'b1; // Imm
                alu_op    = 4'b0000; // PC + imm_u
                wb_src    = 2'b00;
                imm_out   = imm_u;
            end

            // System: EBREAK, ECALL, FENCE
            7'b1110011: begin
                if (instr[31:20] == 12'h001) begin
                    is_ebreak = 1'b1;
                end
            end

            7'b0001111: begin
                // FENCE: NOP in single-core
            end

            default: begin
                illegal_instr = 1'b1;
            end
        endcase

        // If illegal, gate off write enables
        if (illegal_instr) begin
            reg_write = 1'b0;
            mem_read  = 1'b0;
            mem_write = 1'b0;
        end
    end

    // Branch condition evaluation
    always @(*) begin
        branch_taken = 1'b0;
        if (valid_d && is_branch) begin
            case (funct3)
                3'b000: branch_taken = alu_zero;   // BEQ
                3'b001: branch_taken = !alu_zero;  // BNE
                3'b100: branch_taken = alu_cmp;    // BLT
                3'b101: branch_taken = !alu_cmp;   // BGE
                3'b110: branch_taken = alu_cmp;    // BLTU
                3'b111: branch_taken = !alu_cmp;   // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end

    wire redirect = valid_d && (branch_taken || is_jal || is_jalr);
    assign pc_src = redirect;
    assign flush  = redirect;
    assign halt   = valid_d && is_ebreak;

endmodule

