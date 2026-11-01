// =============================================================================
// Testbench: nanoriscv_c2_top_tb.v
// Description: Dedicated self-checking top-level testbench for NanoRISC-V-C2.
//              Loads machine code from program.hex, runs the processor core,
//              verifies register states and memory, and generates waveforms.
//              Generates nanoriscv_c2_top.vcd for GTKWave waveform inspection.
// =============================================================================

`timescale 1ns/1ps

module nanoriscv_c2_top_tb;

    reg         clk;
    reg         rst_n;

    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire        debug_valid;
    wire        debug_reg_write;
    wire [4:0]  debug_rd;
    wire [31:0] debug_wdata;
    wire        debug_halt;
    wire        debug_illegal_instr;

    integer cycle_count;

    // Instantiate Top-Level Core
    nanoriscv_c2_top #(
        .MEM_DEPTH(1024),
        .INIT_FILE("testbench/program.hex")
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .debug_pc(debug_pc),
        .debug_instr(debug_instr),
        .debug_valid(debug_valid),
        .debug_reg_write(debug_reg_write),
        .debug_rd(debug_rd),
        .debug_wdata(debug_wdata),
        .debug_halt(debug_halt),
        .debug_illegal_instr(debug_illegal_instr)
    );

    // 100 MHz Clock Generator (10ns period)
    always #5 clk = ~clk;

    // Track clock cycles
    always @(posedge clk) begin
        if (rst_n && !debug_halt) begin
            cycle_count = cycle_count + 1;
        end
    end

    // Log retired instructions
    always @(posedge clk) begin
        if (rst_n && debug_valid) begin
            $display("T=%0t | PC=0x%08h | Instr=0x%08h | rd=x%0d | wdata=0x%08h (%0d)",
                     $time, debug_pc, debug_instr, debug_rd, debug_wdata, debug_wdata);
        end
    end

    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("nanoriscv_c2_top.vcd");
        $dumpvars(0, nanoriscv_c2_top_tb);

        $display("=================================================================");
        $display(" Running Testbench: nanoriscv_c2_top_tb (NanoRISC-V-C2 Core)");
        $display("=================================================================");

        clk = 0;
        rst_n = 0;
        cycle_count = 0;
        #20;

        @(negedge clk);
        rst_n = 1;
        $display("[INFO] Reset released. Processor running...");

        // Wait for EBREAK halt or timeout
        fork
            begin
                wait (debug_halt == 1'b1);
                $display("[INFO] Core asserted HALT at PC=0x%08h after %0d cycles.", debug_pc, cycle_count);
            end
            begin
                #10000; // 1000 cycles timeout
                $display("[ERROR] Simulation TIMEOUT occurred!");
                $stop;
            end
        join_any

        #20; // Settle state

        $display("\n=================================================================");
        $display(" ARCHITECTURAL STATE VERIFICATION");
        $display("=================================================================");

        // Verify registers
        if (uut.u_rf.registers[1] !== 32'h00000048) begin
            $display("[FAIL] x1 return address mismatch! Expected 0x48, got 0x%08h", uut.u_rf.registers[1]); $stop;
        end else $display("[PASS] Reg x1 (Return PC)        = 0x%08h", uut.u_rf.registers[1]);

        if (uut.u_rf.registers[2] !== 32'd10) begin
            $display("[FAIL] x2 loop count mismatch! Expected 10, got %0d", uut.u_rf.registers[2]); $stop;
        end else $display("[PASS] Reg x2 (Loop counter i)   = %0d", uut.u_rf.registers[2]);

        if (uut.u_rf.registers[3] !== 32'd50) begin
            $display("[FAIL] x3 sum mismatch! Expected 50, got %0d", uut.u_rf.registers[3]); $stop;
        end else $display("[PASS] Reg x3 (Accumulated Sum)  = %0d", uut.u_rf.registers[3]);

        if (uut.u_rf.registers[8] !== 32'd50) begin
            $display("[FAIL] x8 loaded value mismatch! Expected 50, got %0d", uut.u_rf.registers[8]); $stop;
        end else $display("[PASS] Reg x8 (Loaded from Mem)  = %0d", uut.u_rf.registers[8]);

        if (uut.u_rf.registers[9] !== 32'd45) begin
            $display("[FAIL] x9 diff mismatch! Expected 45, got %0d", uut.u_rf.registers[9]); $stop;
        end else $display("[PASS] Reg x9 (Subtracted: 50-5) = %0d", uut.u_rf.registers[9]);

        if (uut.u_rf.registers[10] !== 32'd180) begin
            $display("[FAIL] x10 shift mismatch! Expected 180, got %0d", uut.u_rf.registers[10]); $stop;
        end else $display("[PASS] Reg x10 (Scaled: 45<<2)   = %0d", uut.u_rf.registers[10]);

        if (uut.u_rf.registers[11] !== 32'd42) begin
            $display("[FAIL] x11 status mismatch! Expected 42, got %0d", uut.u_rf.registers[11]); $stop;
        end else $display("[PASS] Reg x11 (Subroutine Code) = %0d", uut.u_rf.registers[11]);

        // Verify Data Memory
        if (uut.u_dmem.mem[64] !== 32'd50) begin // 256 / 4 = 64
            $display("[FAIL] Data Memory[256] mismatch! Expected 50, got %0d", uut.u_dmem.mem[64]); $stop;
        end else $display("[PASS] Data Memory[256]          = %0d", uut.u_dmem.mem[64]);

        if (uut.u_dmem.mem[65] !== 32'd180) begin // 260 / 4 = 65
            $display("[FAIL] Data Memory[260] mismatch! Expected 180, got %0d", uut.u_dmem.mem[65]); $stop;
        end else $display("[PASS] Data Memory[260]          = %0d", uut.u_dmem.mem[65]);

        // Invariance
        if (uut.u_rf.rdata1 !== 32'd0) begin
            $display("[FAIL] x0 immutability check failed!"); $stop;
        end else $display("[PASS] Reg x0 (Hardwired Zero)   = 0x%08h", uut.u_rf.rdata1);

        $display("=================================================================");
        $display(" nanoriscv_c2_top_tb: ALL CHECKS PASSED SUCCESSFULLY");
        $display(" VCD Waveform dumped to: nanoriscv_c2_top.vcd");
        $display("=================================================================");
        $finish;
    end

endmodule

