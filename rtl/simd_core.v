
`timescale 1ns/1ps

module simd_core (
    input wire clk,

    // Control signals
    input wire load_en,
    input wire execute_en,

    // External vector loading
    input wire [2:0] load_addr,
    input wire [63:0] load_data,

    // Instruction register addresses
    input wire [2:0] src_a_addr,
    input wire [2:0] src_b_addr,
    input wire [2:0] dst_addr,

    // SIMD operation
    input wire [2:0] opcode,

    // Outputs for observing the processor
    output wire [63:0] src_a_data,
    output wire [63:0] src_b_data,
    output wire [63:0] alu_result
);

    // Register write control
    wire reg_we;

    wire [2:0] reg_write_addr;
    wire [63:0] reg_write_data;

    assign reg_we = load_en | execute_en;

    // External loading takes priority
    assign reg_write_addr =
        load_en ? load_addr : dst_addr;

    assign reg_write_data =
        load_en ? load_data : alu_result;

    // Vector Register File
    vector_regfile regfile (
        .clk(clk),
        .we(reg_we),

        .read_addr_a(src_a_addr),
        .read_addr_b(src_b_addr),

        .write_addr(reg_write_addr),
        .write_data(reg_write_data),

        .read_data_a(src_a_data),
        .read_data_b(src_b_data)
    );

    // Four-Lane SIMD ALU
    simd4 execution_unit (
        .a_vec(src_a_data),
        .b_vec(src_b_data),
        .opcode(opcode),
        .result_vec(alu_result)
    );

endmodule
