`timescale 1ns/1ps

// Small on-chip input generator for FPGA place-and-route experiments.
// This is NOT part of the scalar or SIMD datapath under evaluation.
module fpga_stimulus (
    input  wire        clk,
    input  wire        rst,
    input  wire        run,
    output reg  [7:0]  count,
    output reg  [63:0] word
);
    always @(posedge clk) begin
        if (rst) begin
            count <= 8'd0;
            word  <= 64'hD3A5_9C7E_1024_B6F1;
        end else if (run) begin
            count <= count + 8'd1;
            word <= {word[62:0],
                     word[63] ^ word[62] ^ word[60] ^ word[59]};
        end
    end
endmodule
