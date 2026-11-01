// =============================================================================
// Testbench: data_memory_tb.v
// Description: Dedicated testbench for data_memory.v.
//              Verifies Word Write, Word Read, Alignment Error, and Bounds.
//              Generates data_memory.vcd for GTKWave waveform inspection.
// =============================================================================

`timescale 1ns/1ps

module data_memory_tb;

    reg         clk;
    reg         rst_n;
    reg         mem_read;
    reg         mem_write;
    reg  [31:0] addr;
    reg  [31:0] wdata;
    wire [31:0] rdata;
    wire        error;

    data_memory #(
        .MEM_DEPTH(1024)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata),
        .error(error)
    );

    always #5 clk = ~clk;

    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("data_memory.vcd");
        $dumpvars(0, data_memory_tb);

        $display("=================================================");
        $display(" Running Testbench: data_memory_tb");
        $display("=================================================");

        // Reset
        clk = 0;
        rst_n = 0;
        mem_read = 0;
        mem_write = 0;
        addr = 0;
        wdata = 0;
        #15;
        rst_n = 1;

        // Step 1: Write Word to byte address 256 (0x100)
        @(negedge clk);
        mem_write = 1;
        addr = 32'd256;
        wdata = 32'hAABBCCDD;

        // Step 2: Write Word to byte address 260 (0x104)
        @(negedge clk);
        addr = 32'd260;
        wdata = 32'h12345678;

        @(negedge clk);
        mem_write = 0;

        // Step 3: Read back address 256
        mem_read = 1;
        addr = 32'd256; #5;
        $display("Read @256: rdata = 0x%08h, error = %0b (Expected: 0xAABBCCDD)", rdata, error);
        if (rdata !== 32'hAABBCCDD || error !== 1'b0) $stop;

        // Step 4: Read back address 260
        addr = 32'd260; #5;
        $display("Read @260: rdata = 0x%08h, error = %0b (Expected: 0x12345678)", rdata, error);
        if (rdata !== 32'h12345678 || error !== 1'b0) $stop;

        // Step 5: Test Misaligned Access (e.g. addr = 257)
        addr = 32'd257; #5;
        $display("Misaligned read @257: error = %0b (Expected: 1)", error);
        if (error !== 1'b1) $stop;

        // Step 6: Test Out-of-Bounds Access (e.g. addr = 8192)
        addr = 32'd8192; #5;
        $display("Out-of-bounds read @8192: error = %0b (Expected: 1)", error);
        if (error !== 1'b1) $stop;

        mem_read = 0;
        #10;
        $display("=================================================");
        $display(" data_memory_tb: ALL CHECKS PASSED");
        $display("=================================================");
        $finish;
    end

endmodule

