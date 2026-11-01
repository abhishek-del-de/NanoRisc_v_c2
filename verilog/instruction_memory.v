// =============================================================================
// Module: instruction_memory.v
// Architecture: NanoRISC-V-C2 (Stage 1 Fetch)
// Description: Pure standard Verilog-2001 4 KB Instruction Memory (ROM/RAM).
//              Word-aligned addressing with optional hex file initialization.
// =============================================================================

`timescale 1ns/1ps

module instruction_memory #(
    parameter MEM_DEPTH = 1024,
    parameter INIT_FILE = ""
)(
    input  wire [31:0] addr,
    output wire [31:0] instr
);

    reg [31:0] mem [0:MEM_DEPTH-1];

    // Word-aligned addressing: bits [11:2]
    wire [9:0] word_addr = addr[11:2];

    // Out-of-bounds safety check
    wire in_bounds = (addr < (MEM_DEPTH * 4));

    // Asynchronous combinational read
    assign instr = in_bounds ? mem[word_addr] : 32'h00000013; // Return NOP if out-of-bounds

    integer i;
    initial begin
        // Initialize all words to RV32I NOP (addi x0, x0, 0 = 32'h00000013)
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            mem[i] = 32'h00000013;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

endmodule

