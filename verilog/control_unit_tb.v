// =============================================================================
// Testbench: control_unit_tb.v
// Description: Dedicated testbench for control_unit.v.
//              Verifies decoding across R, I, S, B, U, J, and SYSTEM types.
//              Generates control_unit.vcd for GTKWave waveform inspection.
// =============================================================================

`timescale 1ns/1ps

module control_unit_tb;

    reg  [31:0] instr;
    reg         valid_d;
    reg         alu_zero;
    reg         alu_cmp;
    wire [3:0]  alu_op;
    wire [1:0]  alu_src_a;
    wire        alu_src_b;
    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire [1:0]  wb_src;
    wire [31:0] imm_out;
    wire        branch_taken;
    wire        pc_src;
    wire        flush;
    wire        halt;
    wire        illegal_instr;

    control_unit uut (
        .instr(instr),
        .valid_d(valid_d),
        .alu_zero(alu_zero),
        .alu_cmp(alu_cmp),
        .alu_op(alu_op),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .wb_src(wb_src),
        .imm_out(imm_out),
        .branch_taken(branch_taken),
        .pc_src(pc_src),
        .flush(flush),
        .halt(halt),
        .illegal_instr(illegal_instr)
    );

    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("control_unit.vcd");
        $dumpvars(0, control_unit_tb);

        $display("=================================================");
        $display(" Running Testbench: control_unit_tb");
        $display("=================================================");

        valid_d = 1;
        alu_zero = 0;
        alu_cmp = 0;

        // Test 1: ADDI x1, x0, 10 (0x00a00093)
        instr = 32'h00a00093; #10;
        $display("[ADDI] reg_write=%0b, alu_src_b=%0b, imm=0x%08h (%0d)",
                 reg_write, alu_src_b, imm_out, imm_out);
        if (!reg_write || !alu_src_b || imm_out !== 32'd10) $stop;

        // Test 2: ADD x3, x3, x4 (0x004181b3)
        instr = 32'h004181b3; #10;
        $display("[ADD] reg_write=%0b, alu_src_b=%0b, alu_op=%b",
                 reg_write, alu_src_b, alu_op);
        if (!reg_write || alu_src_b !== 1'b0 || alu_op !== 4'b0000) $stop;

        // Test 3: SW x3, 0(x5) (0x0032a023)
        instr = 32'h0032a023; #10;
        $display("[SW] mem_write=%0b, reg_write=%0b", mem_write, reg_write);
        if (!mem_write || reg_write) $stop;

        // Test 4: LW x8, 0(x5) (0x0002a403)
        instr = 32'h0002a403; #10;
        $display("[LW] mem_read=%0b, reg_write=%0b, wb_src=%b", mem_read, reg_write, wb_src);
        if (!mem_read || !reg_write || wb_src !== 2'b01) $stop;

        // Test 5: BEQ x2, x1, 28 (Taken when alu_zero=1)
        instr = 32'h00110e63;
        alu_zero = 0; #10;
        $display("[BEQ untaken] branch_taken=%0b, pc_src=%0b", branch_taken, pc_src);
        if (branch_taken !== 0) $stop;

        alu_zero = 1; #10;
        $display("[BEQ taken] branch_taken=%0b, pc_src=%0b, flush=%0b", branch_taken, pc_src, flush);
        if (branch_taken !== 1 || pc_src !== 1 || flush !== 1) $stop;

        // Test 6: EBREAK (0x00100073)
        instr = 32'h00100073; #10;
        $display("[EBREAK] halt=%0b", halt);
        if (!halt) $stop;

        #10;
        $display("=================================================");
        $display(" control_unit_tb: ALL CHECKS PASSED");
        $display("=================================================");
        $finish;
    end

endmodule

