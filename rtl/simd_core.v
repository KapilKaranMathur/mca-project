
`timescale 1ns/1ps

module simd_core (

    // Clock input
    input wire clk,

    // External loading interface
    input wire load_en,
    input wire [2:0] load_addr,
    input wire [63:0] load_data,

    // Execution interface
    input wire execute_en,
    input wire [2:0] src_a_addr,
    input wire [2:0] src_b_addr,
    input wire [2:0] dst_addr,
    input wire [2:0] opcode,

    // Datapath outputs
    output wire [63:0] src_a_data,
    output wire [63:0] src_b_data,
    output wire [63:0] alu_result
);

    // Internal register file signals
    wire reg_we;
    wire [2:0] reg_write_addr;
    wire [63:0] reg_write_data;

    // Vector control signals
    wire select_load;
    wire opcode_valid;

    // ========================================
    // 1. VECTOR CONTROL UNIT
    // ========================================

    vector_control control_unit (
        .load_en(load_en),
        .execute_en(execute_en),
        .opcode(opcode),

        .load_addr(load_addr),
        .dst_addr(dst_addr),

        .reg_we(reg_we),
        .reg_write_addr(reg_write_addr),
        .select_load(select_load),
        .opcode_valid(opcode_valid)
    );

    // ========================================
    // 2. WRITE-DATA MULTIPLEXER
    // ========================================

    // External loading has priority.
    // Otherwise, select the SIMD execution result.

    assign reg_write_data = select_load ?
                            load_data : alu_result;

    // ========================================
    // 3. VECTOR REGISTER FILE
    // ========================================

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

    // ========================================
    // 4. FOUR-LANE SIMD EXECUTION UNIT
    // ========================================

    simd4 execution_unit (
        .a_vec(src_a_data),
        .b_vec(src_b_data),
        .opcode(opcode),
        .result_vec(alu_result)
    );

endmodule
