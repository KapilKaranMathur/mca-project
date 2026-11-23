`timescale 1ns/1ps
// Clocked stimulus and clocked output capture keep processor paths observable.
module scalar_timing_top (
    input wire clk,
    input wire rst,
    input wire run,
    output wire status
);
    wire [15:0] ctrl;
    wire [63:0] data;
    wire [15:0] read_a, read_b, result;
    reg [15:0] captured_result;

    fpga_timing_stimulus stimulus (
        .clk(clk), .rst(rst), .run(run), .ctrl(ctrl), .data(data)
    );

    scalar_core core (
        .clk(clk),
        .load_en(run && !ctrl[0]),
        .load_addr(ctrl[9:5]),
        .load_data(data[15:0]),
        .execute_en(run && ctrl[0]),
        .src_a_addr(ctrl[14:10]),
        .src_b_addr(ctrl[13:9]),
        .dst_addr(ctrl[8:4]),
        .opcode(ctrl[3:1]),
        .src_a_data(read_a),
        .src_b_data(read_b),
        .alu_result(result)
    );

    always @(posedge clk) begin
        if (rst) captured_result <= 16'b0;
        else if (run) captured_result <= result;
    end
    assign status = ^captured_result;
endmodule
