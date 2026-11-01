// =============================================================================
// Testbench: register_file_tb.v
// Description: Dedicated testbench for register_file.v.
//              Verifies reads, writes, x0 immutability, and internal forwarding.
//              Generates register_file.vcd for GTKWave waveform inspection.
// =============================================================================

`timescale 1ns/1ps

module register_file_tb;

    reg         clk;
    reg         rst_n;
    reg         wen;
    reg  [4:0]  waddr;
    reg  [31:0] wdata;
    reg  [4:0]  raddr1;
    reg  [4:0]  raddr2;
    wire [31:0] rdata1;
    wire [31:0] rdata2;

    register_file uut (
        .clk(clk),
        .rst_n(rst_n),
        .wen(wen),
        .waddr(waddr),
        .wdata(wdata),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    always #5 clk = ~clk;

    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("register_file.vcd");
        $dumpvars(0, register_file_tb);

        $display("=================================================");
        $display(" Running Testbench: register_file_tb");
        $display("=================================================");

        // Step 1: Reset
        clk = 0;
        rst_n = 0;
        wen = 0;
        waddr = 0;
        wdata = 0;
        raddr1 = 0;
        raddr2 = 1;
        #15;
        rst_n = 1;

        // Step 2: Write to register x1 and x2
        @(negedge clk);
        wen = 1;
        waddr = 5'd1;
        wdata = 32'hDEADBEEF;

        @(negedge clk);
        waddr = 5'd2;
        wdata = 32'hCAFE1234;

        @(negedge clk);
        wen = 0;

        // Step 3: Read back x1 and x2
        raddr1 = 5'd1;
        raddr2 = 5'd2;
        #5;
        $display("Read x1 = 0x%08h (Expected: 0xDEADBEEF)", rdata1);
        $display("Read x2 = 0x%08h (Expected: 0xCAFE1234)", rdata2);
        if (rdata1 !== 32'hDEADBEEF || rdata2 !== 32'hCAFE1234) begin
            $display("[FAIL] Register read/write mismatch!");
            $stop;
        end

        // Step 4: Test x0 Invariance (attempt write to x0)
        @(negedge clk);
        wen = 1;
        waddr = 5'd0;
        wdata = 32'hFFFFFFFF;

        @(negedge clk);
        wen = 0;
        raddr1 = 5'd0;
        #5;
        $display("Read x0 after write attempt = 0x%08h (Must be 0x00000000)", rdata1);
        if (rdata1 !== 32'd0) begin
            $display("[FAIL] x0 immutability violated!");
            $stop;
        end

        // Step 5: Test Internal Write-Through Forwarding (Read same cycle as Write)
        @(negedge clk);
        wen = 1;
        waddr = 5'd5;
        wdata = 32'h11223344;
        raddr1 = 5'd5; // Read x5 while writing x5 in same cycle
        #1;
        $display("Forwarding check: rdata1 = 0x%08h (Expected: 0x11223344)", rdata1);
        if (rdata1 !== 32'h11223344) begin
            $display("[FAIL] Internal forwarding bypass failed!");
            $stop;
        end

        @(posedge clk);
        #10;
        $display("=================================================");
        $display(" register_file_tb: ALL CHECKS PASSED");
        $display("=================================================");
        $finish;
    end

endmodule

