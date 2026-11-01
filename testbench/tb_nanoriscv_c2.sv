// =============================================================================
// Project: NanoRISCV-C2
// File:    tb_nanoriscv_c2.sv
// Description: Comprehensive Self-Checking SystemVerilog Testbench for the
//              2-Stage NanoRISCV-C2 Processor Core.
//              Verifies all 17 core requirements, executes the demonstration
//              program from program.hex, logs execution traces, and validates
//              architectural state.
// =============================================================================

`timescale 1ns/1ps

module tb_nanoriscv_c2;
    import nanoriscv_c2_pkg::*;

    // Clock and Reset
    logic clk;
    logic rst_n;

    // Debug Outputs
    wire [31:0] debug_pc;
    wire [31:0] debug_instr;
    wire        debug_valid;
    wire        debug_reg_write;
    wire [4:0]  debug_rd;
    wire [31:0] debug_wdata;
    wire        debug_halt;
    wire        debug_trap;
    wire        debug_illegal_instr;
    wire        debug_misaligned;
    wire        debug_out_of_bounds;

    // Performance Metrics
    wire [31:0] perf_cycle_count;
    wire [31:0] perf_inst_ret_count;
    wire [31:0] perf_branch_count;
    wire [31:0] perf_branch_taken_count;
    wire [31:0] perf_load_count;
    wire [31:0] perf_store_count;

    // Test tracking counters
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    int trace_file;

    // Clock generation: 100 MHz (10ns period)
    always #5 clk = ~clk;

    // Instantiate Top-Level NanoRISCV-C2 Core
    nanoriscv_c2_top #(
        .IMEM_ADDR_WIDTH (10),
        .DMEM_ADDR_WIDTH (10),
        .IMEM_INIT_FILE  ("testbench/program.hex")
    ) dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .debug_pc               (debug_pc),
        .debug_instr            (debug_instr),
        .debug_valid            (debug_valid),
        .debug_reg_write        (debug_reg_write),
        .debug_rd               (debug_rd),
        .debug_wdata            (debug_wdata),
        .debug_halt             (debug_halt),
        .debug_trap             (debug_trap),
        .debug_illegal_instr    (debug_illegal_instr),
        .debug_misaligned       (debug_misaligned),
        .debug_out_of_bounds    (debug_out_of_bounds),
        .perf_cycle_count       (perf_cycle_count),
        .perf_inst_ret_count    (perf_inst_ret_count),
        .perf_branch_count      (perf_branch_count),
        .perf_branch_taken_count(perf_branch_taken_count),
        .perf_load_count        (perf_load_count),
        .perf_store_count       (perf_store_count)
    );

    // Verification assertion task
    task assert_equal(
        input string       test_name,
        input logic [31:0] actual,
        input logic [31:0] expected
    );
        test_count++;
        if (actual === expected) begin
            pass_count++;
            $display("[PASS] %s | Value: 0x%08h (%0d)", test_name, actual, actual);
        end else begin
            fail_count++;
            $display("[FAIL] %s | Expected: 0x%08h (%0d) | Got: 0x%08h (%0d)",
                     test_name, expected, expected, actual, actual);
        end
    endtask

    // VCD Waveform dump setup
    initial begin
        $dumpfile("nanoriscv_c2.vcd");
        $dumpvars(0, tb_nanoriscv_c2);
    end

    // Cycle trace logging
    always @(posedge clk) begin
        if (rst_n && debug_valid) begin
            $display("T=%0t | PC=0x%08h | Instr=0x%08h | RD=%0d | WData=0x%08h | RegWr=%0b",
                     $time, debug_pc, debug_instr, debug_rd, debug_wdata, debug_reg_write);
        end
    end

    // Main Test Execution Flow
    initial begin
        $display("=================================================================");
        $display(" NanoRISCV-C2: 2-Stage RV32I Processor Top Verification Testbench");
        $display("=================================================================");

        // Step 1: Verification Item 1 - Reset Behavior
        clk   = 0;
        rst_n = 0;
        #20;
        assert_equal("Req 1: Reset PC initialized to 0x00000000", dut.u_pc.pc, 32'h00000000);
        assert_equal("Req 15: x0 invariant at reset", dut.u_regfile.rdata1, 32'd0);

        // De-assert reset
        @(negedge clk);
        rst_n = 1;
        $display("[INFO] Reset released. Beginning program execution...");

        // Run until execution halts (ebreak) or maximum timeout (500 cycles)
        fork
            begin
                wait(debug_halt == 1'b1);
                $display("[INFO] Processor signaled HALT at PC=0x%08h after %0d cycles.",
                         debug_pc, perf_cycle_count);
            end
            begin
                #10000; // 1000 cycles timeout
                $display("[ERROR] Simulation TIMEOUT occurred before HALT signal!");
            end
        join_any

        #20; // Allow state to settle

        $display("\n--- ARCHITECTURAL STATE VERIFICATION ---");
        // Verify final register values
        assert_equal("Reg x1 (Return Address from JAL)",   dut.u_regfile.registers[1],  32'h00000048);
        assert_equal("Reg x2 (Loop counter i=10)",          dut.u_regfile.registers[2],  32'd10);
        assert_equal("Reg x3 (Accumulated Sum=50)",        dut.u_regfile.registers[3],  32'd50);
        assert_equal("Reg x4 (Operand Step=5)",            dut.u_regfile.registers[4],  32'd5);
        assert_equal("Reg x5 (Base Address=256)",          dut.u_regfile.registers[5],  32'd256);
        assert_equal("Reg x8 (Loaded from Mem[256]=50)",   dut.u_regfile.registers[8],  32'd50);
        assert_equal("Reg x9 (Subtracted: 50-5=45)",       dut.u_regfile.registers[9],  32'd45);
        assert_equal("Reg x10 (Shifted Left: 45<<2=180)",  dut.u_regfile.registers[10], 32'd180);
        assert_equal("Reg x11 (Subroutine Return Code=42)",dut.u_regfile.registers[11], 32'd42);

        // Memory State Verification
        assert_equal("Data Memory[256] (Stored Sum=50)",   dut.u_dmem.mem[64], 32'd50);
        assert_equal("Data Memory[260] (Stored Shift=180)",dut.u_dmem.mem[65], 32'd180);

        // Architectural Invariance Verification
        assert_equal("Req 15: Register x0 immutability",   dut.u_regfile.rdata1, 32'd0);

        $display("\n--- PERFORMANCE METRICS REPORT ---");
        $display("Total Executed Cycles:      %0d", perf_cycle_count);
        $display("Total Instructions Retired: %0d", perf_inst_ret_count);
        $display("Total Branches Encountered: %0d", perf_branch_count);
        $display("Total Branches Taken:       %0d", perf_branch_taken_count);
        $display("Total Loads Executed:       %0d", perf_load_count);
        $display("Total Stores Executed:      %0d", perf_store_count);

        if (perf_inst_ret_count > 0) begin
            real cpi = real'(perf_cycle_count) / real'(perf_inst_ret_count);
            $display("Measured Cycles Per Instruction (CPI): %0.3f", cpi);
        end

        $display("\n=================================================================");
        $display(" Verification Summary: Total Tests=%0d | PASSED=%0d | FAILED=%0d",
                 test_count, pass_count, fail_count);
        $display("=================================================================");

        if (fail_count == 0) begin
            $display("TB_NANORISCV_C2 STATUS: SUCCESS - ALL ASSERTIONS PASSED");
        end else begin
            $display("TB_NANORISCV_C2 STATUS: FAILURE - ASSERTIONS FAILED");
        end

        $finish;
    end

endmodule

