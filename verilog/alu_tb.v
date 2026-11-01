// =============================================================================
// Testbench: alu_tb.v
// Description: Dedicated self-checking testbench for alu.v.
//              Tests all 11 ALU operations including boundary & signedness cases.
//              Generates alu.vcd for GTKWave waveform inspection.
// =============================================================================

`timescale 1ns/1ps

module alu_tb;

    reg  [3:0]  alu_op;
    reg  [31:0] operand_a;
    reg  [31:0] operand_b;
    wire [31:0] result;
    wire        zero;
    wire        cmp_result;

    alu uut (
        .alu_op(alu_op),
        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(result),
        .zero(zero),
        .cmp_result(cmp_result)
    );

    task check(
        input [3:0]  op,
        input [31:0] a,
        input [31:0] b,
        input [31:0] exp_res,
        input        exp_zero,
        input [127:0] test_name
    );
        begin
            alu_op = op;
            operand_a = a;
            operand_b = b;
            #5;
            if (result === exp_res && zero === exp_zero) begin
                $display("[PASS] %0s | Res=0x%08h, Zero=%0b", test_name, result, zero);
            end else begin
                $display("[FAIL] %0s | Expected 0x%08h (z=%0b), Got 0x%08h (z=%0b)",
                         test_name, exp_res, exp_zero, result, zero);
                $stop;
            end
        end
    endtask

    initial begin
        // Waveform Dump for GTKWave
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);

        $display("=================================================");
        $display(" Running Testbench: alu_tb");
        $display("=================================================");

        // ADD Tests
        check(4'b0000, 32'd15, 32'd25, 32'd40, 1'b0, "ADD_Positive");
        check(4'b0000, 32'h7FFFFFFF, 32'd1, 32'h80000000, 1'b0, "ADD_Overflow");
        check(4'b0000, 32'hFFFFFFFF, 32'd1, 32'h00000000, 1'b1, "ADD_Wraparound");

        // SUB Tests
        check(4'b0001, 32'd50, 32'd50, 32'd0, 1'b1, "SUB_Zero");
        check(4'b0001, 32'd100, 32'd30, 32'd70, 1'b0, "SUB_Positive");
        check(4'b0001, 32'd20, 32'd50, -32'd30, 1'b0, "SUB_Negative");

        // Logic Tests
        check(4'b0010, 32'hFF00FF00, 32'hF0F0F0F0, 32'hF000F000, 1'b0, "AND_Mask");
        check(4'b0011, 32'hF0000000, 32'h0000000F, 32'hF000000F, 1'b0, "OR_Combine");
        check(4'b0100, 32'h12345678, 32'h12345678, 32'd0, 1'b1, "XOR_SelfInvert");

        // Shift Tests
        check(4'b0101, 32'd1, 32'd4, 32'd16, 1'b0, "SLL_Shift4");
        check(4'b0110, 32'h80000000, 32'd4, 32'h08000000, 1'b0, "SRL_Shift4");
        check(4'b0111, 32'h80000000, 32'd4, 32'hF8000000, 1'b0, "SRA_SignExtend");

        // Comparisons
        check(4'b1000, -32'd5, 32'd5, 32'd1, 1'b0, "SLT_SignedLess");
        check(4'b1000, 32'd5, -32'd5, 32'd0, 1'b1, "SLT_SignedGreater");
        check(4'b1001, 32'd5, 32'hFFFFFFFF, 32'd1, 1'b0, "SLTU_UnsignedLess");

        // Pass-through
        check(4'b1010, 32'hDEADBEEF, 32'hCAFE1234, 32'hCAFE1234, 1'b0, "COPY_B");

        #10;
        $display("=================================================");
        $display(" alu_tb: ALL CHECKS PASSED");
        $display("=================================================");
        $finish;
    end

endmodule

