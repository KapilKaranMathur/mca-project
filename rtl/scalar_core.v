`timescale 1ns/1ps

module scalar_core (
    input  wire        clk,
    input  wire        load_en,
    input  wire [4:0]  load_addr,
    input  wire [15:0] load_data,
    input  wire        execute_en,
    input  wire [4:0]  src_a_addr,
    input  wire [4:0]  src_b_addr,
    input  wire [4:0]  dst_addr,
    input  wire [2:0]  opcode,
    output wire [15:0] src_a_data,
    output wire [15:0] src_b_data,
    output wire [15:0] alu_result
);
    wire        opcode_valid;
    wire        reg_we;
    wire [4:0]  reg_write_addr;
    wire [15:0] reg_write_data;

    // Same external-loading priority and invalid-opcode policy as SIMD core.
    assign opcode_valid  = (opcode <= 3'b100);
    assign reg_we        = load_en | (execute_en & opcode_valid);
    assign reg_write_addr = load_en ? load_addr : dst_addr;
    assign reg_write_data = load_en ? load_data : alu_result;

    scalar_regfile regfile (
        .clk(clk),
        .we(reg_we),
        .read_addr_a(src_a_addr),
        .read_addr_b(src_b_addr),
        .write_addr(reg_write_addr),
        .write_data(reg_write_data),
        .read_data_a(src_a_data),
        .read_data_b(src_b_data)
    );

    // Reuse the exact 16-bit ALU from Phase 1, not a different implementation.
    alu16 execution_unit (
        .a(src_a_data),
        .b(src_b_data),
        .opcode(opcode),
        .result(alu_result)
    );
endmodule
