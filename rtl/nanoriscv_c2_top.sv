// =============================================================================
// Project: NanoRISCV-C2
// File:    nanoriscv_c2_top.sv
// Description: Top-level module of the 2-Stage RV32I RISC-V Processor Core.
//              Integrates Stage 1 (Instruction Fetch) and Stage 2 (Decode,
//              Execute, Memory Access, and Write-Back) along with the Hazard
//              Detection Unit and Architectural Performance Counters.
// =============================================================================

`ifndef NANORISCV_C2_TOP_SV
`define NANORISCV_C2_TOP_SV

`timescale 1ns/1ps

module nanoriscv_c2_top
    import nanoriscv_c2_pkg::*;
#(
    parameter int    IMEM_ADDR_WIDTH = 10,
    parameter int    DMEM_ADDR_WIDTH = 10,
    parameter string IMEM_INIT_FILE  = ""
)(
    input  logic        clk,
    input  logic        rst_n,

    // Debug and Observation Interface
    output logic [31:0] debug_pc,
    output logic [31:0] debug_instr,
    output logic        debug_valid,
    output logic        debug_reg_write,
    output logic [4:0]  debug_rd,
    output logic [31:0] debug_wdata,
    output logic        debug_halt,
    output logic        debug_trap,
    output logic        debug_illegal_instr,
    output logic        debug_misaligned,
    output logic        debug_out_of_bounds,

    // Performance Counters
    output logic [31:0] perf_cycle_count,
    output logic [31:0] perf_inst_ret_count,
    output logic [31:0] perf_branch_count,
    output logic [31:0] perf_branch_taken_count,
    output logic [31:0] perf_load_count,
    output logic [31:0] perf_store_count
);

    // =========================================================================
    // STAGE 1: INSTRUCTION FETCH (IF) SIGNALS
    // =========================================================================
    logic [31:0] pc_f;
    logic [31:0] pc_plus4_f;
    logic [31:0] instr_f;
    logic        pc_stall;
    logic        pc_src;
    logic [31:0] target_pc;

    // =========================================================================
    // STAGE 1/2 PIPELINE REGISTERS
    // =========================================================================
    logic [31:0] pc_d;
    logic [31:0] pc_plus4_d;
    logic [31:0] instr_d;
    logic        valid_d;
    logic        stall_d;
    logic        flush_d;

    // =========================================================================
    // STAGE 2: DECODE, EXECUTE, MEMORY, WRITE-BACK (EX) SIGNALS
    // =========================================================================
    // Decoder signals
    logic [6:0]  opcode_d;
    logic [4:0]  rd_d;
    logic [2:0]  funct3_d;
    logic [4:0]  rs1_d;
    logic [4:0]  rs2_d;
    logic [6:0]  funct7_d;

    // Immediate generation
    logic [31:0] imm_i_d;
    logic [31:0] imm_s_d;
    logic [31:0] imm_b_d;
    logic [31:0] imm_u_d;
    logic [31:0] imm_j_d;
    logic [31:0] imm_out_d;

    // Control signals
    alu_op_t     alu_op_d;
    logic [1:0]  alu_src_a_d;
    logic        alu_src_b_d;
    logic        reg_write_ctrl;
    logic        mem_read_ctrl;
    logic        mem_write_ctrl;
    wb_src_t     wb_src_d;
    logic        is_branch_d;
    logic        is_jal_d;
    logic        is_jalr_d;
    logic        is_fence_d;
    logic        is_ecall_d;
    logic        is_ebreak_d;
    logic        illegal_instr_d;

    // Register file signals
    logic [31:0] rdata1_d;
    logic [31:0] rdata2_d;
    logic [31:0] wb_data_d;
    logic        rf_wen;

    // ALU signals
    logic [31:0] alu_operand_a;
    logic [31:0] alu_operand_b;
    logic [31:0] alu_result_d;
    logic        alu_zero_d;
    logic        alu_cmp_result_d;

    // Data memory signals
    logic [31:0] dmem_rdata;
    logic        dmem_misaligned;
    logic        dmem_out_of_bounds;
    logic        dmem_read_en;
    logic        dmem_write_en;

    // Hazard and status signals
    logic        branch_taken_d;
    logic        core_halt;
    logic        core_trap;

    // =========================================================================
    // STAGE 1: INSTRUCTION FETCH INSTANTIATION
    // =========================================================================
    program_counter u_pc (
        .clk        (clk),
        .rst_n      (rst_n),
        .stall      (pc_stall),
        .pc_src     (pc_src),
        .target_pc  (target_pc),
        .pc         (pc_f),
        .pc_plus4   (pc_plus4_f)
    );

    instruction_memory #(
        .ADDR_WIDTH (IMEM_ADDR_WIDTH),
        .INIT_FILE  (IMEM_INIT_FILE)
    ) u_imem (
        .addr       (pc_f),
        .instr      (instr_f)
    );

    // =========================================================================
    // IF / ID PIPELINE REGISTER
    // =========================================================================
    pipeline_reg_if_id u_if_id_reg (
        .clk        (clk),
        .rst_n      (rst_n),
        .stall      (stall_d),
        .flush      (flush_d),
        .pc_f       (pc_f),
        .pc_plus4_f (pc_plus4_f),
        .instr_f    (instr_f),
        .pc_d       (pc_d),
        .pc_plus4_d (pc_plus4_d),
        .instr_d    (instr_d),
        .valid_d    (valid_d)
    );

    // =========================================================================
    // STAGE 2: DECODE
    // =========================================================================
    decoder u_decoder (
        .instr      (instr_d),
        .opcode     (opcode_d),
        .rd         (rd_d),
        .funct3     (funct3_d),
        .rs1        (rs1_d),
        .rs2        (rs2_d),
        .funct7     (funct7_d),
        .is_r_type  (),
        .is_i_type  (),
        .is_s_type  (),
        .is_b_type  (),
        .is_u_type  (),
        .is_j_type  ()
    );

    immediate_generator u_imm_gen (
        .instr      (instr_d),
        .imm_i      (imm_i_d),
        .imm_s      (imm_s_d),
        .imm_b      (imm_b_d),
        .imm_u      (imm_u_d),
        .imm_j      (imm_j_d),
        .imm_out    (imm_out_d)
    );

    control_unit u_control (
        .opcode        (opcode_d),
        .funct3        (funct3_d),
        .funct7        (funct7_d),
        .instr         (instr_d),
        .alu_op        (alu_op_d),
        .alu_src_a     (alu_src_a_d),
        .alu_src_b     (alu_src_b_d),
        .reg_write     (reg_write_ctrl),
        .mem_read      (mem_read_ctrl),
        .mem_write     (mem_write_ctrl),
        .wb_src        (wb_src_d),
        .is_branch     (is_branch_d),
        .is_jal        (is_jal_d),
        .is_jalr       (is_jalr_d),
        .is_fence      (is_fence_d),
        .is_ecall      (is_ecall_d),
        .is_ebreak     (is_ebreak_d),
        .illegal_instr (illegal_instr_d)
    );

    // Register file write gating: only write if instruction is valid and rd != x0
    assign rf_wen = valid_d && reg_write_ctrl && (rd_d != 5'd0);

    register_file u_regfile (
        .clk        (clk),
        .rst_n      (rst_n),
        .wen        (rf_wen),
        .waddr      (rd_d),
        .wdata      (wb_data_d),
        .raddr1     (rs1_d),
        .raddr2     (rs2_d),
        .rdata1     (rdata1_d),
        .rdata2     (rdata2_d)
    );

    // =========================================================================
    // STAGE 2: EXECUTE (ALU & Operand MUXes)
    // =========================================================================
    always_comb begin
        case (alu_src_a_d)
            ALU_SRC_A_RS1:  alu_operand_a = rdata1_d;
            ALU_SRC_A_PC:   alu_operand_a = pc_d;
            ALU_SRC_A_ZERO: alu_operand_a = 32'd0;
            default:        alu_operand_a = rdata1_d;
        endcase
    end

    assign alu_operand_b = alu_src_b_d ? imm_out_d : rdata2_d;

    alu u_alu (
        .alu_op     (alu_op_d),
        .operand_a  (alu_operand_a),
        .operand_b  (alu_operand_b),
        .result     (alu_result_d),
        .zero       (alu_zero_d),
        .cmp_result (alu_cmp_result_d)
    );

    // =========================================================================
    // STAGE 2: MEMORY ACCESS
    // =========================================================================
    assign dmem_read_en  = valid_d && mem_read_ctrl;
    assign dmem_write_en = valid_d && mem_write_ctrl;

    data_memory #(
        .ADDR_WIDTH (DMEM_ADDR_WIDTH)
    ) u_dmem (
        .clk               (clk),
        .rst_n             (rst_n),
        .mem_read          (dmem_read_en),
        .mem_write         (dmem_write_en),
        .addr              (alu_result_d),
        .wdata             (rdata2_d),
        .rdata             (dmem_rdata),
        .misaligned_access (dmem_misaligned),
        .out_of_bounds     (dmem_out_of_bounds)
    );

    // =========================================================================
    // STAGE 2: WRITE-BACK MULTIPLEXER
    // =========================================================================
    always_comb begin
        case (wb_src_d)
            WB_SRC_ALU: wb_data_d = alu_result_d;
            WB_SRC_MEM: wb_data_d = dmem_rdata;
            WB_SRC_PC4: wb_data_d = pc_plus4_d;
            WB_SRC_IMM: wb_data_d = imm_u_d;
            default:    wb_data_d = alu_result_d;
        endcase
    end

    // =========================================================================
    // HAZARD DETECTION & CONTROL UNIT
    // =========================================================================
    hazard_unit u_hazard (
        .valid_d       (valid_d),
        .is_branch     (is_branch_d),
        .is_jal        (is_jal_d),
        .is_jalr       (is_jalr_d),
        .is_ebreak     (is_ebreak_d),
        .is_ecall      (is_ecall_d),
        .illegal_instr (illegal_instr_d),
        .funct3        (funct3_d),
        .zero          (alu_zero_d),
        .cmp_result    (alu_cmp_result_d),
        .pc_d          (pc_d),
        .imm_b         (imm_b_d),
        .imm_j         (imm_j_d),
        .imm_i         (imm_i_d),
        .rdata1        (rdata1_d),
        .branch_taken  (branch_taken_d),
        .pc_src        (pc_src),
        .target_pc     (target_pc),
        .flush_d       (flush_d),
        .stall_f       (pc_stall),
        .stall_d       (stall_d),
        .halt          (core_halt),
        .trap          (core_trap)
    );

    // =========================================================================
    // PERFORMANCE COUNTERS & METRICS LOGIC
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            perf_cycle_count        <= 32'd0;
            perf_inst_ret_count     <= 32'd0;
            perf_branch_count       <= 32'd0;
            perf_branch_taken_count <= 32'd0;
            perf_load_count         <= 32'd0;
            perf_store_count        <= 32'd0;
        end else if (!core_halt) begin
            perf_cycle_count <= perf_cycle_count + 32'd1;

            if (valid_d) begin
                perf_inst_ret_count <= perf_inst_ret_count + 32'd1;

                if (is_branch_d) begin
                    perf_branch_count <= perf_branch_count + 32'd1;
                    if (branch_taken_d) begin
                        perf_branch_taken_count <= perf_branch_taken_count + 32'd1;
                    end
                end

                if (mem_read_ctrl) begin
                    perf_load_count <= perf_load_count + 32'd1;
                end

                if (mem_write_ctrl) begin
                    perf_store_count <= perf_store_count + 32'd1;
                end
            end
        end
    end

    // =========================================================================
    // DEBUG OUTPUT ASSIGNMENTS
    // =========================================================================
    assign debug_pc            = pc_d;
    assign debug_instr         = instr_d;
    assign debug_valid         = valid_d;
    assign debug_reg_write     = rf_wen;
    assign debug_rd            = rd_d;
    assign debug_wdata         = wb_data_d;
    assign debug_halt          = core_halt;
    assign debug_trap          = core_trap;
    assign debug_illegal_instr = illegal_instr_d;
    assign debug_misaligned    = dmem_misaligned;
    assign debug_out_of_bounds = dmem_out_of_bounds;

endmodule

`endif // NANORISCV_C2_TOP_SV

