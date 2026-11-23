`timescale 1ns/1ps
// Same input generator and clocked output observation as scalar_timing_top.
module simd_timing_top (
    input wire clk,
    input wire rst,
    input wire run,
    output wire status
);
    wire [15:0] ctrl;
    wire [63:0] data;
    wire [63:0] read_a, read_b, result;
    reg [63:0] captured_result;

    fpga_timing_stimulus stimulus (
        .clk(clk), .rst(rst), .run(run), .ctrl(ctrl), .data(data)
    );

    simd_core core (
        .clk(clk),
        .load_en(run && !ctrl[0]),
        .load_addr(ctrl[7:5]),
        .load_data(data),
        .execute_en(run && ctrl[0]),
        .src_a_addr(ctrl[10:8]),
        .src_b_addr(ctrl[13:11]),
        .dst_addr(ctrl[6:4]),
        .opcode(ctrl[3:1]),
        .src_a_data(read_a),
        .src_b_data(read_b),
        .alu_result(result)
    );

    always @(posedge clk) begin
        if (rst) captured_result <= 64'b0;
        else if (run) captured_result <= result;
    end
    assign status = ^captured_result;
endmodule
