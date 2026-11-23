`timescale 1ns/1ps
// Shared, shallow-depth synchronous stimulus for timing-only experiments.
// A short LFSR avoids the long binary incrementer path in the earlier wrapper.
module fpga_timing_stimulus (
    input wire clk,
    input wire rst,
    input wire run,
    output reg [15:0] ctrl,
    output reg [63:0] data
);
    always @(posedge clk) begin
        if (rst) begin
            ctrl <= 16'hB4D3;
            data <= 64'hD3A59C7E1024B6F1;
        end else if (run) begin
            ctrl <= {ctrl[14:0], ctrl[15] ^ ctrl[13] ^ ctrl[12] ^ ctrl[10]};
            data <= {data[62:0], data[63] ^ data[62] ^ data[60] ^ data[59]};
        end
    end
endmodule
