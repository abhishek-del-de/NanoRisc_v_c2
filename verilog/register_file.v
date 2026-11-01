// =============================================================================
// Module: register_file.v
// Architecture: NanoRISC-V-C2 (Stage 2 Register File)
// Description: Pure standard Verilog-2001 32x32-bit General Purpose Register File.
//              Features hardwired x0 = 0 invariance, dual asynchronous read ports,
//              synchronous write, and internal write-through forwarding bypass.
// =============================================================================

`timescale 1ns/1ps

module register_file (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        wen,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);

    reg [31:0] registers [1:31];

    // Asynchronous Read Port 1 with x0 hardwiring and write-through forwarding
    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 :
                    ((wen && (waddr == raddr1)) ? wdata : registers[raddr1]);

    // Asynchronous Read Port 2 with x0 hardwiring and write-through forwarding
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 :
                    ((wen && (waddr == raddr2)) ? wdata : registers[raddr2]);

    // Synchronous Write Port
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else if (wen && (waddr != 5'd0)) begin
            registers[waddr] <= wdata;
        end
    end

endmodule

