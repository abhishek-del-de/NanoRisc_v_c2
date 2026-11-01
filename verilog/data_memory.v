// =============================================================================
// Module: data_memory.v
// Architecture: NanoRISC-V-C2 (Stage 2 Memory Access)
// Description: Pure standard Verilog-2001 4 KB Data RAM for LW/SW operations.
//              Features address alignment checking and bounds protection.
// =============================================================================

`timescale 1ns/1ps

module data_memory #(
    parameter MEM_DEPTH = 1024
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata,
    output wire        error
);

    reg [31:0] mem [0:MEM_DEPTH-1];

    wire [9:0] word_addr = addr[11:2];

    // Misalignment: address must be 4-byte aligned (bits [1:0] == 00)
    // Bounds check: address must be strictly within allocated 4 KB range
    wire misaligned   = (mem_read || mem_write) && (addr[1:0] != 2'b00);
    wire out_of_range = (mem_read || mem_write) && (addr >= (MEM_DEPTH * 4));
    assign error      = misaligned || out_of_range;

    // Asynchronous combinational read
    assign rdata = (mem_read && !error) ? mem[word_addr] : 32'd0;

    // Synchronous write
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                mem[i] <= 32'd0;
            end
        end else if (mem_write && !error) begin
            mem[word_addr] <= wdata;
        end
    end

endmodule

