// =============================================================================
// Testbench: instruction_memory_tb.v
// Description: Dedicated testbench for instruction_memory.v.
//              Generates instruction_memory.vcd for GTKWave waveform inspection.
// =============================================================================

`timescale 1ns/1ps

module instruction_memory_tb;

    reg  [31:0] addr;
    wire [31:0] instr;

    instruction_memory #(
        .MEM_DEPTH(1024),
        .INIT_FILE("")
    ) uut (
        .addr(addr),
        .instr(instr)
    );

    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("instruction_memory.vcd");
        $dumpvars(0, instruction_memory_tb);

        $display("=================================================");
        $display(" Running Testbench: instruction_memory_tb");
        $display("=================================================");

        // Preload memory words for testing
        uut.mem[0] = 32'h00a00093; // addi x1, x0, 10
        uut.mem[1] = 32'h00500213; // addi x4, x0, 5
        uut.mem[2] = 32'h004181b3; // add x3, x3, x4
        uut.mem[3] = 32'h00100073; // ebreak

        // Read PC = 0x00
        addr = 32'h00000000; #10;
        $display("Addr = 0x%08h -> Instr = 0x%08h (Expected: 0x00a00093)", addr, instr);
        if (instr !== 32'h00a00093) $stop;

        // Read PC = 0x04
        addr = 32'h00000004; #10;
        $display("Addr = 0x%08h -> Instr = 0x%08h (Expected: 0x00500213)", addr, instr);
        if (instr !== 32'h00500213) $stop;

        // Read PC = 0x08
        addr = 32'h00000008; #10;
        $display("Addr = 0x%08h -> Instr = 0x%08h (Expected: 0x004181b3)", addr, instr);
        if (instr !== 32'h004181b3) $stop;

        // Read uninitialized location (should return NOP: 0x00000013)
        addr = 32'h00000020; #10;
        $display("Addr = 0x%08h -> Instr = 0x%08h (Expected NOP: 0x00000013)", addr, instr);
        if (instr !== 32'h00000013) $stop;

        $display("=================================================");
        $display(" instruction_memory_tb: ALL CHECKS PASSED");
        $display("=================================================");
        $finish;
    end

endmodule

