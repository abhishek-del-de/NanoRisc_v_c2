// =============================================================================
// Module: program_counter.v
// Architecture: NanoRISC-V-C2 (Stage 1 Fetch)
// Description: Pure standard Verilog-2001 32-bit Program Counter with
//              synchronous stall and branch/jump redirection support.
// =============================================================================

`timescale 1ns/1ps

module program_counter #(
    parameter [31:0] RESET_ADDR = 32'h00000000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        pc_src,      // 0: Sequential PC+4, 1: Redirect target_pc
    input  wire [31:0] target_pc,   // Target address from Stage 2 (Branch/Jump)
    output reg  [31:0] pc,
    output wire [31:0] pc_plus4
);

    assign pc_plus4 = pc + 32'd4;

    wire [31:0] next_pc = pc_src ? target_pc : pc_plus4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= RESET_ADDR;
        end else if (!stall) begin
            pc <= next_pc;
        end
    end

endmodule

