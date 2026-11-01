// =============================================================================
// Testbench: pipeline_reg_tb.v
// Description: Dedicated testbench for pipeline_reg.v.
//              Verifies normal registration, stall freezing, and flush clearing.
//              Generates pipeline_reg.vcd for GTKWave waveform inspection.
// =============================================================================

`timescale 1ns/1ps

module pipeline_reg_tb;

    reg         clk;
    reg         rst_n;
    reg         stall;
    reg         flush;
    reg  [31:0] pc_f;
    reg  [31:0] pc_plus4_f;
    reg  [31:0] instr_f;
    wire [31:0] pc_d;
    wire [31:0] pc_plus4_d;
    wire [31:0] instr_d;
    wire        valid_d;

    pipeline_reg uut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .flush(flush),
        .pc_f(pc_f),
        .pc_plus4_f(pc_plus4_f),
        .instr_f(instr_f),
        .pc_d(pc_d),
        .pc_plus4_d(pc_plus4_d),
        .instr_d(instr_d),
        .valid_d(valid_d)
    );

    always #5 clk = ~clk;

    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("pipeline_reg.vcd");
        $dumpvars(0, pipeline_reg_tb);

        $display("=================================================");
        $display(" Running Testbench: pipeline_reg_tb");
        $display("=================================================");

        // Reset
        clk = 0;
        rst_n = 0;
        stall = 0;
        flush = 0;
        pc_f = 0;
        pc_plus4_f = 4;
        instr_f = 32'h00a00093;
        #15;
        rst_n = 1;

        // Normal stepping
        @(posedge clk); #1;
        $display("Step 1: pc_d = 0x%08h, instr_d = 0x%08h, valid = %0b", pc_d, instr_d, valid_d);
        if (valid_d !== 1'b1 || instr_d !== 32'h00a00093) $stop;

        // Next instruction
        pc_f = 4; pc_plus4_f = 8; instr_f = 32'h00500213;
        @(posedge clk); #1;
        $display("Step 2: pc_d = 0x%08h, instr_d = 0x%08h, valid = %0b", pc_d, instr_d, valid_d);

        // Test Stall
        stall = 1;
        pc_f = 8; pc_plus4_f = 12; instr_f = 32'h004181b3;
        @(posedge clk); #1;
        $display("Step 3 (Stall): pc_d = 0x%08h, instr_d = 0x%08h (Held)", pc_d, instr_d);
        if (instr_d !== 32'h00500213) $stop;

        // Test Flush (Bubble Insertion)
        stall = 0;
        flush = 1;
        @(posedge clk); #1;
        $display("Step 4 (Flush): instr_d = 0x%08h, valid = %0b (Bubble)", instr_d, valid_d);
        if (valid_d !== 1'b0 || instr_d !== 32'h00000013) $stop;

        #10;
        $display("=================================================");
        $display(" pipeline_reg_tb: ALL CHECKS PASSED");
        $display("=================================================");
        $finish;
    end

endmodule

