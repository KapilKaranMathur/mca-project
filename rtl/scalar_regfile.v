`timescale 1ns/1ps

module scalar_regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [4:0]  read_addr_a,
    input  wire [4:0]  read_addr_b,
    input  wire [4:0]  write_addr,
    input  wire [15:0] write_data,
    output wire [15:0] read_data_a,
    output wire [15:0] read_data_b
);
    // 32 x 16-bit = 512 bits of storage, matching the SIMD regfile capacity.
    reg [15:0] registers [0:31];

    always @(posedge clk) begin
        if (we)
            registers[write_addr] <= write_data;
    end

    assign read_data_a = registers[read_addr_a];
    assign read_data_b = registers[read_addr_b];
endmodule
