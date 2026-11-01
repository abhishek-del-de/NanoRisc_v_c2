// =============================================================================
// Project: NanoRISCV-C2
// File:    instruction_memory.sv
// Description: Synthesizable instruction memory for Stage 1 (IF).
//              Word-aligned addressing, supports optional hex initialization.
// =============================================================================

`ifndef INSTRUCTION_MEMORY_SV
`define INSTRUCTION_MEMORY_SV

`timescale 1ns/1ps

module instruction_memory
    import nanoriscv_c2_pkg::*;
#(
    parameter int    ADDR_WIDTH = IMEM_ADDR_WIDTH, // 10 bits = 1024 words (4 KB)
    parameter string INIT_FILE  = ""
)(
    input  logic [31:0] addr,        // Byte address from PC
    output logic [31:0] instr        // 32-bit instruction word
);

    localparam int MEM_DEPTH = 1 << ADDR_WIDTH;

    // Memory array: 32-bit words
    logic [31:0] mem [0:MEM_DEPTH-1];

    // Word address calculation (bits [ADDR_WIDTH+1:2])
    wire [ADDR_WIDTH-1:0] word_addr = addr[ADDR_WIDTH+1:2];

    // Bounds checking
    wire in_bounds = (addr < (MEM_DEPTH * 4));

    // Combinational read for asynchronous instruction fetch in Stage 1
    assign instr = in_bounds ? mem[word_addr] : NOP_INSTR;

    // Optional initialization from hexadecimal file
    initial begin
        // Initialize all locations to NOP (addi x0, x0, 0 = 32'h00000013)
        for (int i = 0; i < MEM_DEPTH; i++) begin
            mem[i] = NOP_INSTR;
        end
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

endmodule

`endif // INSTRUCTION_MEMORY_SV

