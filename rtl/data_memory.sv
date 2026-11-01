// =============================================================================
// Project: NanoRISCV-C2
// File:    data_memory.sv
// Description: Synthesizable Data Memory module for Stage 2 (MEM).
//              Supports Word (LW/SW) operations, bounds checking, and misaligned
//              access exception detection conforming to the RV32I standard.
// =============================================================================

`ifndef DATA_MEMORY_SV
`define DATA_MEMORY_SV

`timescale 1ns/1ps

module data_memory
    import nanoriscv_c2_pkg::*;
#(
    parameter int ADDR_WIDTH = DMEM_ADDR_WIDTH // 10 bits = 1024 words (4 KB)
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        mem_read,          // Read enable (LW)
    input  logic        mem_write,         // Write enable (SW)
    input  logic [31:0] addr,              // Byte address from ALU
    input  logic [31:0] wdata,             // Write data (RS2)
    output logic [31:0] rdata,             // Read data to WB MUX
    output logic        misaligned_access, // High if word access is not 4-byte aligned
    output logic        out_of_bounds      // High if access exceeds allocated address range
);

    localparam int MEM_DEPTH = 1 << ADDR_WIDTH;
    localparam int MAX_BYTE_ADDR = MEM_DEPTH * 4;

    // Storage array: 1024 32-bit words
    logic [31:0] mem [0:MEM_DEPTH-1];

    // Word indexing: bits [ADDR_WIDTH+1:2]
    wire [ADDR_WIDTH-1:0] word_addr = addr[ADDR_WIDTH+1:2];

    // Alignment and bounds validation
    assign misaligned_access = (mem_read || mem_write) && (addr[1:0] != 2'b00);
    assign out_of_bounds     = (mem_read || mem_write) && (addr >= MAX_BYTE_ADDR);

    wire valid_access = (mem_read || mem_write) && !misaligned_access && !out_of_bounds;

    // Combinational read port: allows single-cycle Load execution in Stage 2
    always_comb begin
        if (mem_read && valid_access) begin
            rdata = mem[word_addr];
        end else begin
            rdata = 32'd0;
        end
    end

    // Synchronous write port with bounds and alignment protection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < MEM_DEPTH; i++) begin
                mem[i] <= 32'd0;
            end
        end else if (mem_write && valid_access) begin
            mem[word_addr] <= wdata;
        end
    end

endmodule

`endif // DATA_MEMORY_SV

