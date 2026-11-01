// =============================================================================
// Project: NanoRISCV-C2
// File:    register_file.sv
// Description: Synthesizable 32x32-bit Register File for RV32I.
//              Features:
//              - Two asynchronous read ports (combinational lookup)
//              - One synchronous write port
//              - Hardwired x0 zero-invariance (reads return 0, writes discarded)
//              - Internal write-through forwarding (bypasses write data to read
//                ports during simultaneous write and read to the same register)
// =============================================================================

`ifndef REGISTER_FILE_SV
`define REGISTER_FILE_SV

`timescale 1ns/1ps

module register_file
    import nanoriscv_c2_pkg::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        wen,         // Write enable
    input  logic [4:0]  waddr,       // Destination register (rd)
    input  logic [31:0] wdata,       // Write data
    input  logic [4:0]  raddr1,      // Source register 1 (rs1)
    input  logic [4:0]  raddr2,      // Source register 2 (rs2)
    output logic [31:0] rdata1,      // Read data 1
    output logic [31:0] rdata2       // Read data 2
);

    // 32 architectural registers
    logic [31:0] registers [1:31];

    // Asynchronous read port 1 with x0 hardwiring and write-through forwarding
    always_comb begin
        if (raddr1 == 5'd0) begin
            rdata1 = 32'd0;
        end else if (wen && (waddr == raddr1)) begin
            rdata1 = wdata; // Internal bypass forwarding
        end else begin
            rdata1 = registers[raddr1];
        end
    end

    // Asynchronous read port 2 with x0 hardwiring and write-through forwarding
    always_comb begin
        if (raddr2 == 5'd0) begin
            rdata2 = 32'd0;
        end else if (wen && (waddr == raddr2)) begin
            rdata2 = wdata; // Internal bypass forwarding
        end else begin
            rdata2 = registers[raddr2];
        end
    end

    // Synchronous write port
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 1; i < 32; i++) begin
                registers[i] <= 32'd0;
            end
        end else if (wen && (waddr != 5'd0)) begin
            registers[waddr] <= wdata;
        end
    end

endmodule

`endif // REGISTER_FILE_SV

