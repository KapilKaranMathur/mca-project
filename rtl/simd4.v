
`timescale 1ns/1ps

module simd4 (
    input  wire [63:0] a_vec,
    input  wire [63:0] b_vec,
    input  wire [2:0]  opcode,
    output wire [63:0] result_vec
);

    // Lane 0: Bits 0 to 15
    alu16 lane0 (
        .a(a_vec[15:0]),
        .b(b_vec[15:0]),
        .opcode(opcode),
        .result(result_vec[15:0])
    );

    // Lane 1: Bits 16 to 31
    alu16 lane1 (
        .a(a_vec[31:16]),
        .b(b_vec[31:16]),
        .opcode(opcode),
        .result(result_vec[31:16])
    );

    // Lane 2: Bits 32 to 47
    alu16 lane2 (
        .a(a_vec[47:32]),
        .b(b_vec[47:32]),
        .opcode(opcode),
        .result(result_vec[47:32])
    );

    // Lane 3: Bits 48 to 63
    alu16 lane3 (
        .a(a_vec[63:48]),
        .b(b_vec[63:48]),
        .opcode(opcode),
        .result(result_vec[63:48])
    );

endmodule
