// =============================================================================
// Module: nanoriscv_c2_top.v
// Architecture: NanoRISC-V-C2 (Top-Level Processor Core)
// Description: Pure standard Verilog-2001 Top-Level Wrapper integrating:
//              - Stage 1 (Fetch): PC, Instruction Memory, Sequential Adder
//              - Interstage Register: IF/ID Pipeline Register with Flush/Stall
//              - Stage 2 (Decode/Execute/Memory/Write-Back):
//                Control Unit, Register File, ALU, Data Memory, and Hazard Unit.
// =============================================================================

`timescale 1ns/1ps

module nanoriscv_c2_top #(
    parameter MEM_DEPTH = 1024,
    parameter INIT_FILE = "testbench/program.hex"
)(
    input  wire        clk,
    input  wire        rst_n,

    // Debug and Verification Interface
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instr,
    output wire        debug_valid,
    output wire        debug_reg_write,
    output wire [4:0]  debug_rd,
    output wire [31:0] debug_wdata,
    output wire        debug_halt,
    output wire        debug_illegal_instr
);

    // =========================================================================
    // STAGE 1 (FETCH) SIGNALS
    // =========================================================================
    wire [31:0] pc_f;
    wire [31:0] pc_plus4_f;
    wire [31:0] instr_f;
    wire        pc_src;
    wire [31:0] target_pc;

    // =========================================================================
    // INTERSTAGE PIPELINE REGISTER SIGNALS
    // =========================================================================
    wire [31:0] pc_d;
    wire [31:0] pc_plus4_d;
    wire [31:0] instr_d;
    wire        valid_d;
    wire        flush_d;
    wire        stall_core;

    // =========================================================================
    // STAGE 2 (DECODE / EXECUTE / MEM / WB) SIGNALS
    // =========================================================================
    wire [4:0]  rd_d   = instr_d[11:7];
    wire [4:0]  rs1_d  = instr_d[19:15];
    wire [4:0]  rs2_d  = instr_d[24:20];
    wire [6:0]  opcode = instr_d[6:0];

    wire [3:0]  alu_op;
    wire [1:0]  alu_src_a_sel;
    wire        alu_src_b_sel;
    wire        reg_write_ctrl;
    wire        mem_read_ctrl;
    wire        mem_write_ctrl;
    wire [1:0]  wb_src_sel;
    wire [31:0] imm_out;
    wire        branch_taken;
    wire        halt_ctrl;
    wire        illegal_instr_ctrl;

    wire [31:0] rdata1;
    wire [31:0] rdata2;
    wire [31:0] alu_result;
    wire        alu_zero;
    wire        alu_cmp;
    wire [31:0] dmem_rdata;
    wire        dmem_error;

    // Write-back data selection
    reg  [31:0] wb_data;
    always @(*) begin
        case (wb_src_sel)
            2'b00: wb_data = alu_result;
            2'b01: wb_data = dmem_rdata;
            2'b10: wb_data = pc_plus4_d;
            2'b11: wb_data = imm_out;
            default: wb_data = alu_result;
        endcase
    end

    // Register write gating (only write if Stage 2 is valid and rd != x0)
    wire rf_wen = valid_d && reg_write_ctrl && (rd_d != 5'd0);

    // ALU Operand A Multiplexer
    reg [31:0] operand_a;
    always @(*) begin
        case (alu_src_a_sel)
            2'b00: operand_a = rdata1;
            2'b01: operand_a = pc_d;
            2'b10: operand_a = 32'd0;
            default: operand_a = rdata1;
        endcase
    end

    // ALU Operand B Multiplexer
    wire [31:0] operand_b = alu_src_b_sel ? imm_out : rdata2;

    // Memory write gating (only write if Stage 2 is valid)
    wire dmem_wen = valid_d && mem_write_ctrl;
    wire dmem_ren = valid_d && mem_read_ctrl;

    // Target PC calculation for Branch, JAL, and JALR
    wire is_jalr = (opcode == 7'b1100111);
    wire [31:0] target_jalr = (rdata1 + imm_out) & 32'hFFFFFFFE; // RV32I: LSB cleared to 0
    wire [31:0] target_branch_or_jal = pc_d + imm_out;
    assign target_pc = is_jalr ? target_jalr : target_branch_or_jal;

    // Freeze pipeline upon halt
    assign stall_core = halt_ctrl;

    // =========================================================================
    // MODULE INSTANTIATIONS
    // =========================================================================

    // 1. Program Counter
    program_counter #(
        .RESET_ADDR(32'h00000000)
    ) u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_core),
        .pc_src(pc_src),
        .target_pc(target_pc),
        .pc(pc_f),
        .pc_plus4(pc_plus4_f)
    );

    // 2. Instruction Memory
    instruction_memory #(
        .MEM_DEPTH(MEM_DEPTH),
        .INIT_FILE(INIT_FILE)
    ) u_imem (
        .addr(pc_f),
        .instr(instr_f)
    );

    // 3. IF/ID Pipeline Register
    pipeline_reg u_if_id (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall_core),
        .flush(flush_d),
        .pc_f(pc_f),
        .pc_plus4_f(pc_plus4_f),
        .instr_f(instr_f),
        .pc_d(pc_d),
        .pc_plus4_d(pc_plus4_d),
        .instr_d(instr_d),
        .valid_d(valid_d)
    );

    // 4. Register File
    register_file u_rf (
        .clk(clk),
        .rst_n(rst_n),
        .wen(rf_wen),
        .waddr(rd_d),
        .wdata(wb_data),
        .raddr1(rs1_d),
        .raddr2(rs2_d),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    // 5. Control Unit
    control_unit u_ctrl (
        .instr(instr_d),
        .valid_d(valid_d),
        .alu_zero(alu_zero),
        .alu_cmp(alu_cmp),
        .alu_op(alu_op),
        .alu_src_a(alu_src_a_sel),
        .alu_src_b(alu_src_b_sel),
        .reg_write(reg_write_ctrl),
        .mem_read(mem_read_ctrl),
        .mem_write(mem_write_ctrl),
        .wb_src(wb_src_sel),
        .imm_out(imm_out),
        .branch_taken(branch_taken),
        .pc_src(pc_src),
        .flush(flush_d),
        .halt(halt_ctrl),
        .illegal_instr(illegal_instr_ctrl)
    );

    // 6. Arithmetic Logic Unit (ALU)
    alu u_alu (
        .alu_op(alu_op),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(alu_result),
        .zero(alu_zero),
        .cmp_result(alu_cmp)
    );

    // 7. Data Memory
    data_memory #(
        .MEM_DEPTH(MEM_DEPTH)
    ) u_dmem (
        .clk(clk),
        .rst_n(rst_n),
        .mem_read(dmem_ren),
        .mem_write(dmem_wen),
        .addr(alu_result),
        .wdata(rdata2),
        .rdata(dmem_rdata),
        .error(dmem_error)
    );

    // =========================================================================
    // DEBUG OUTPUTS
    // =========================================================================
    assign debug_pc            = pc_d;
    assign debug_instr         = instr_d;
    assign debug_valid         = valid_d;
    assign debug_reg_write     = rf_wen;
    assign debug_rd            = rd_d;
    assign debug_wdata         = wb_data;
    assign debug_halt          = halt_ctrl;
    assign debug_illegal_instr = illegal_instr_ctrl;

endmodule

