
`timescale 1ns/1ps

module vector_regfile (
    input wire clk,
    input wire we,

    input wire [2:0] read_addr_a,
    input wire [2:0] read_addr_b,
    input wire [2:0] write_addr,

    input wire [63:0] write_data,

    output wire [63:0] read_data_a,
    output wire [63:0] read_data_b
);

    // Eight registers, each 64 bits wide
    reg [63:0] registers [0:7];

    // Synchronous write
    always @(posedge clk) begin
        if (we)
            registers[write_addr] <= write_data;
    end

    // Asynchronous read
    assign read_data_a = registers[read_addr_a];
    assign read_data_b = registers[read_addr_b];

endmodule
