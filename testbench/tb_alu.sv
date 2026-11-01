// =============================================================================
// Project: NanoRISCV-C2
// File:    tb_alu.sv
// Description: Self-checking testbench for the 32-bit ALU.
//              Covers all arithmetic, logical, shift, and comparison operations
//              including corner cases, signed/unsigned comparisons, and overflow.
// =============================================================================

`timescale 1ns/1ps

module tb_alu;
    import nanoriscv_c2_pkg::*;

    logic [3:0]  alu_op;
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    wire  [31:0] result;
    wire         zero;
    wire         cmp_result;

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // Instantiate Device Under Test
    alu dut (
        .alu_op     (alu_op),
        .operand_a  (operand_a),
        .operand_b  (operand_b),
        .result     (result),
        .zero       (zero),
        .cmp_result (cmp_result)
    );

    // Task to verify ALU result and zero flag
    task check_alu(
        input string       test_name,
        input logic [3:0]  op,
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [31:0] exp_res,
        input logic        exp_zero
    );
        alu_op    = op;
        operand_a = a;
        operand_b = b;
        #5; // Wait for combinational propagation

        test_count++;
        if (result === exp_res && zero === exp_zero) begin
            pass_count++;
            $display("[PASS] %s | a=0x%08h, b=0x%08h -> res=0x%08h, zero=%0b",
                     test_name, a, b, result, zero);
        end else begin
            fail_count++;
            $display("[FAIL] %s | a=0x%08h, b=0x%08h | Expected: res=0x%08h, zero=%0b | Got: res=0x%08h, zero=%0b",
                     test_name, a, b, exp_res, exp_zero, result, zero);
        end
    endtask

    // Task to verify comparison result flag
    task check_cmp(
        input string       test_name,
        input logic [3:0]  op,
        input logic [31:0] a,
        input logic [31:0] b,
        input logic [31:0] exp_res,
        input logic        exp_cmp
    );
        alu_op    = op;
        operand_a = a;
        operand_b = b;
        #5;

        test_count++;
        if (result === exp_res && cmp_result === exp_cmp) begin
            pass_count++;
            $display("[PASS] %s | a=0x%08h, b=0x%08h -> res=0x%08h, cmp=%0b",
                     test_name, a, b, result, cmp_result);
        end else begin
            fail_count++;
            $display("[FAIL] %s | a=0x%08h, b=0x%08h | Expected: res=0x%08h, cmp=%0b | Got: res=0x%08h, cmp=%0b",
                     test_name, a, b, exp_res, exp_cmp, result, cmp_result);
        end
    endtask

    initial begin
        $display("=================================================================");
        $display(" NanoRISCV-C2: ALU Unit Verification Testbench Running");
        $display("=================================================================");

        // 1. ADD Tests
        check_alu("ADD: Zero Operands",        ALU_ADD, 32'd0, 32'd0, 32'd0, 1'b1);
        check_alu("ADD: Positive Operands",    ALU_ADD, 32'd15, 32'd25, 32'd40, 1'b0);
        check_alu("ADD: Negative + Positive",  ALU_ADD, -32'd10, 32'd10, 32'd0, 1'b1);
        check_alu("ADD: Two Negatives",        ALU_ADD, -32'd5, -32'd15, -32'd20, 1'b0);
        check_alu("ADD: Max Signed Overflow",  ALU_ADD, 32'h7FFFFFFF, 32'd1, 32'h80000000, 1'b0);
        check_alu("ADD: 32-bit Wraparound",    ALU_ADD, 32'hFFFFFFFF, 32'd1, 32'h00000000, 1'b1);

        // 2. SUB Tests
        check_alu("SUB: Same Numbers",         ALU_SUB, 32'd50, 32'd50, 32'd0, 1'b1);
        check_alu("SUB: Positive Result",      ALU_SUB, 32'd100, 32'd30, 32'd70, 1'b0);
        check_alu("SUB: Negative Result",      ALU_SUB, 32'd20, 32'd50, -32'd30, 1'b0);
        check_alu("SUB: Min Signed Underflow", ALU_SUB, 32'h80000000, 32'd1, 32'h7FFFFFFF, 1'b0);

        // 3. Bitwise Logic Tests
        check_alu("AND: Masking",              ALU_AND, 32'hFF00FF00, 32'hF0F0F0F0, 32'hF000F000, 1'b0);
        check_alu("AND: Disjoint",             ALU_AND, 32'hAAAAAAAA, 32'h55555555, 32'h00000000, 1'b1);
        check_alu("OR:  Combining",            ALU_OR,  32'hF0000000, 32'h0000000F, 32'hF000000F, 1'b0);
        check_alu("XOR: Self-Inversion",       ALU_XOR, 32'h12345678, 32'h12345678, 32'd0, 1'b1);
        check_alu("XOR: Toggle Bits",          ALU_XOR, 32'hFFFFFFFF, 32'h0000FFFF, 32'hFFFF0000, 1'b0);

        // 4. Shift Tests (SLL, SRL, SRA)
        check_alu("SLL: Shift 0",              ALU_SLL, 32'h00000001, 32'd0, 32'h00000001, 1'b0);
        check_alu("SLL: Shift 4",              ALU_SLL, 32'h00000001, 32'd4, 32'h00000010, 1'b0);
        check_alu("SLL: Shift 31",             ALU_SLL, 32'h00000001, 32'd31, 32'h80000000, 1'b0);
        check_alu("SLL: Mask shamt > 31",      ALU_SLL, 32'h00000001, 32'd35, 32'h00000008, 1'b0); // 35 % 32 = 3
        check_alu("SRL: Shift 4",              ALU_SRL, 32'h80000000, 32'd4, 32'h08000000, 1'b0);
        check_alu("SRA: Positive Sign Shift",  ALU_SRA, 32'h70000000, 32'd4, 32'h07000000, 1'b0);
        check_alu("SRA: Negative Sign Extension", ALU_SRA, 32'h80000000, 32'd4, 32'hF8000000, 1'b0);
        check_alu("SRA: Shift 31 on Negative", ALU_SRA, 32'h80000000, 32'd31, 32'hFFFFFFFF, 1'b0);

        // 5. Comparisons (SLT, SLTU)
        check_cmp("SLT: Positive < Positive",  ALU_SLT, 32'd10, 32'd20, 32'd1, 1'b1);
        check_cmp("SLT: Negative < Positive",  ALU_SLT, -32'd5, 32'd5, 32'd1, 1'b1);
        check_cmp("SLT: Positive < Negative",  ALU_SLT, 32'd5, -32'd5, 32'd0, 1'b0);
        check_cmp("SLT: Equal Values",         ALU_SLT, 32'd100, 32'd100, 32'd0, 1'b0);
        check_cmp("SLTU: Unsigned Comparison", ALU_SLTU, 32'd5, 32'hFFFFFFFF, 32'd1, 1'b1);
        check_cmp("SLTU: High unsigned < Low", ALU_SLTU, 32'hFFFFFFFF, 32'd5, 32'd0, 1'b0);

        // 6. Copy B (for LUI)
        check_alu("COPY_B: Pass immediate",    ALU_COPY_B, 32'hDEADBEEF, 32'hCAFE1234, 32'hCAFE1234, 1'b0);

        $display("-----------------------------------------------------------------");
        $display(" ALU Test Results: Total=%0d | PASSED=%0d | FAILED=%0d",
                 test_count, pass_count, fail_count);
        $display("=================================================================");

        if (fail_count == 0) begin
            $display("ALU VERIFICATION STATUS: ALL TESTS PASSED SUCCESSFULLY");
        end else begin
            $display("ALU VERIFICATION STATUS: SIMULATION FAILED");
        end

        $finish;
    end

endmodule

