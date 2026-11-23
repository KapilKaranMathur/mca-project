
`timescale 1ns/1ps

module vector_control (

    // Control inputs
    input wire load_en,
    input wire execute_en,

    // Operation selection
    input wire [2:0] opcode,

    // Register addresses
    input wire [2:0] load_addr,
    input wire [2:0] dst_addr,

    // Control outputs
    output wire reg_we,
    output wire [2:0] reg_write_addr,
    output wire select_load,
    output wire opcode_valid
);

    // Check whether the opcode is supported
    assign opcode_valid = (opcode <= 3'b100);

    // Enable writing during loading or valid execution
    assign reg_we = load_en |
                    (execute_en & opcode_valid);

    // External loading gets priority
    assign reg_write_addr = load_en ?
                            load_addr : dst_addr;

    // Control the write-data multiplexer
    assign select_load = load_en;

endmodule
