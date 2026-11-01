// =============================================================================
// Testbench: program_counter_tb.v
// Description: Dedicated self-checking testbench for program_counter.v.
//              Generates program_counter.vcd for GTKWave waveform inspection.
// =============================================================================

`timescale 1ns/1ps

module program_counter_tb;

    reg         clk;
    reg         rst_n;
    reg         stall;
    reg         pc_src;
    reg  [31:0] target_pc;
    wire [31:0] pc;
    wire [31:0] pc_plus4;

    // Instantiate Unit Under Test
    program_counter #(
        .RESET_ADDR(32'h00000000)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall),
        .pc_src(pc_src),
        .target_pc(target_pc),
        .pc(pc),
        .pc_plus4(pc_plus4)
    );

    // Clock generator: 100 MHz (10ns period)
    always #5 clk = ~clk;

    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("program_counter.vcd");
        $dumpvars(0, program_counter_tb);

        $display("=================================================");
        $display(" Running Testbench: program_counter_tb");
        $display("=================================================");

        // Step 1: Assert Reset
        clk = 0;
        rst_n = 0;
        stall = 0;
        pc_src = 0;
        target_pc = 32'h00000000;
        #15;

        if (pc !== 32'h00000000) begin
            $display("[FAIL] Reset test failed! Expected PC=0, got %h", pc);
            $stop;
        end else begin
            $display("[PASS] Reset verified: PC = 0x%08h", pc);
        end

        // Step 2: Release Reset, test sequential stepping
        @(negedge clk);
        rst_n = 1;

        @(posedge clk); #1;
        $display("Cycle 1: PC = 0x%08h (Expected: 0x00000004)", pc);
        @(posedge clk); #1;
        $display("Cycle 2: PC = 0x%08h (Expected: 0x00000008)", pc);

        // Step 3: Test Pipeline Stall
        stall = 1;
        @(posedge clk); #1;
        $display("Cycle 3 (Stall Active): PC = 0x%08h (Should remain 0x00000008)", pc);
        if (pc !== 32'h00000008) begin
            $display("[FAIL] Stall test failed!");
            $stop;
        end

        // Step 4: De-assert stall, test Branch Redirection
        stall = 0;
        pc_src = 1;
        target_pc = 32'h00000040;
        @(posedge clk); #1;
        $display("Cycle 4 (Branch Redirect): PC = 0x%08h (Expected: 0x00000040)", pc);
        if (pc !== 32'h00000040) begin
            $display("[FAIL] Branch redirection test failed!");
            $stop;
        end

        // Step 5: Resume sequential execution from target
        pc_src = 0;
        @(posedge clk); #1;
        $display("Cycle 5 (Resume Sequential): PC = 0x%08h (Expected: 0x00000044)", pc);

        #20;
        $display("=================================================");
        $display(" program_counter_tb: ALL CHECKS PASSED");
        $display("=================================================");
        $finish;
    end

endmodule

