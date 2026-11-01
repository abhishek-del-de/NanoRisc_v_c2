// =============================================================================
// Project: NanoRISCV-C2
// File:    nanoriscv_c2_pkg.sv
// Description: Architectural constants, opcodes, ALU controls, and definitions
//              for the RV32I 2-Stage Pipeline Processor.
// Standards: IEEE 1800 SystemVerilog, RISC-V RV32I Unprivileged ISA v20191213
// =============================================================================

`ifndef NANORISCV_C2_PKG_SV
`define NANORISCV_C2_PKG_SV

package nanoriscv_c2_pkg;

    // -------------------------------------------------------------------------
    // Major RISC-V Opcodes (Base RV32I)
    // -------------------------------------------------------------------------
    localparam [6:0] OPCODE_OP       = 7'b0110011; // R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
    localparam [6:0] OPCODE_OP_IMM   = 7'b0010011; // I-type: ADDI, SLLI, SLTI, SLTIU, XORI, SRLI, SRAI, ORI, ANDI
    localparam [6:0] OPCODE_LOAD     = 7'b0000011; // I-type: LW (also LB, LH, LBU, LHU)
    localparam [6:0] OPCODE_STORE    = 7'b0100011; // S-type: SW (also SB, SH)
    localparam [6:0] OPCODE_BRANCH   = 7'b1100011; // B-type: BEQ, BNE, BLT, BGE, BLTU, BGEU
    localparam [6:0] OPCODE_JAL      = 7'b1101111; // J-type: JAL
    localparam [6:0] OPCODE_JALR     = 7'b1100111; // I-type: JALR
    localparam [6:0] OPCODE_LUI      = 7'b0110111; // U-type: LUI
    localparam [6:0] OPCODE_AUIPC    = 7'b0010111; // U-type: AUIPC
    localparam [6:0] OPCODE_SYSTEM   = 7'b1110011; // I-type: ECALL, EBREAK, CSR
    localparam [6:0] OPCODE_FENCE    = 7'b0001111; // I-type: FENCE

    // -------------------------------------------------------------------------
    // Funct3 Definitions
    // -------------------------------------------------------------------------
    // Arithmetic / Logic
    localparam [2:0] FUNCT3_ADD_SUB  = 3'b000;
    localparam [2:0] FUNCT3_SLL      = 3'b001;
    localparam [2:0] FUNCT3_SLT      = 3'b010;
    localparam [2:0] FUNCT3_SLTU     = 3'b011;
    localparam [2:0] FUNCT3_XOR      = 3'b100;
    localparam [2:0] FUNCT3_SRL_SRA  = 3'b101;
    localparam [2:0] FUNCT3_OR       = 3'b110;
    localparam [2:0] FUNCT3_AND      = 3'b111;

    // Branches
    localparam [2:0] FUNCT3_BEQ      = 3'b000;
    localparam [2:0] FUNCT3_BNE      = 3'b001;
    localparam [2:0] FUNCT3_BLT      = 3'b100;
    localparam [2:0] FUNCT3_BGE      = 3'b101;
    localparam [2:0] FUNCT3_BLTU     = 3'b110;
    localparam [2:0] FUNCT3_BGEU     = 3'b111;

    // Memory (Load / Store)
    localparam [2:0] FUNCT3_LB       = 3'b000;
    localparam [2:0] FUNCT3_LH       = 3'b001;
    localparam [2:0] FUNCT3_LW       = 3'b010;
    localparam [2:0] FUNCT3_LBU      = 3'b100;
    localparam [2:0] FUNCT3_LHU      = 3'b101;
    localparam [2:0] FUNCT3_SB       = 3'b000;
    localparam [2:0] FUNCT3_SH       = 3'b001;
    localparam [2:0] FUNCT3_SW       = 3'b010;

    // System (ECALL, EBREAK)
    localparam [2:0] FUNCT3_SYSTEM   = 3'b000;

    // -------------------------------------------------------------------------
    // Funct7 Definitions
    // -------------------------------------------------------------------------
    localparam [6:0] FUNCT7_STANDARD = 7'b0000000;
    localparam [6:0] FUNCT7_ALT      = 7'b0100000; // SUB, SRA

    // -------------------------------------------------------------------------
    // ALU Operation Control Encodings (4-bit)
    // -------------------------------------------------------------------------
    typedef enum logic [3:0] {
        ALU_ADD    = 4'b0000,
        ALU_SUB    = 4'b0001,
        ALU_AND    = 4'b0010,
        ALU_OR     = 4'b0011,
        ALU_XOR    = 4'b0100,
        ALU_SLL    = 4'b0101,
        ALU_SRL    = 4'b0110,
        ALU_SRA    = 4'b0111,
        ALU_SLT    = 4'b1000,
        ALU_SLTU   = 4'b1001,
        ALU_COPY_B = 4'b1010  // Pass-through B operand (for LUI)
    } alu_op_t;

    // -------------------------------------------------------------------------
    // Multiplexer Selection Encodings
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        ALU_SRC_A_RS1 = 2'b00,
        ALU_SRC_A_PC  = 2'b01,
        ALU_SRC_A_ZERO= 2'b10
    } alu_src_a_t;

    typedef enum logic {
        ALU_SRC_B_RS2 = 1'b0,
        ALU_SRC_B_IMM = 1'b1
    } alu_src_b_t;

    typedef enum logic [1:0] {
        WB_SRC_ALU  = 2'b00,
        WB_SRC_MEM  = 2'b01,
        WB_SRC_PC4  = 2'b10,
        WB_SRC_IMM  = 2'b11
    } wb_src_t;

    // -------------------------------------------------------------------------
    // Architecture Configuration Defaults
    // -------------------------------------------------------------------------
    localparam int XLEN               = 32;
    localparam int REG_ADDR_WIDTH     = 5;
    localparam int NUM_REGS           = 32;
    localparam int IMEM_ADDR_WIDTH    = 10; // 1024 32-bit words (4 KB)
    localparam int DMEM_ADDR_WIDTH    = 10; // 1024 32-bit words (4 KB)
    localparam logic [31:0] BOOT_ADDR = 32'h00000000;
    localparam logic [31:0] NOP_INSTR = 32'h00000013; // addi x0, x0, 0

endpackage : nanoriscv_c2_pkg

`endif // NANORISCV_C2_PKG_SV
