`timescale 1ns/1ps

// Minimal-pin FPGA timing wrapper. Top-level has only 4 I/O bits.
// The existing scalar_core RTL is unchanged.
module scalar_fpga_top (
    input  wire clk,
    input  wire rst,
    input  wire run,
    output wire status
);
    wire [7:0]  count;
    wire [63:0] word;
    wire [15:0] read_a, read_b, result;
    wire load_en    = run && !rst && !count[0];
    wire execute_en = run && !rst &&  count[0];

    fpga_stimulus stimulus (
        .clk(clk), .rst(rst), .run(run),
        .count(count), .word(word)
    );

    scalar_core core (
        .clk(clk),
        .load_en(load_en),
        .load_addr(count[6:2]),
        .load_data(word[15:0]),
        .execute_en(execute_en),
        .src_a_addr(count[7:3]),
        .src_b_addr(count[6:2]),
        .dst_addr(count[6:2]),
        .opcode(count[3:1]),
        .src_a_data(read_a),
        .src_b_data(read_b),
        .alu_result(result)
    );

    // Keeps all three datapath outputs observable for synthesis.
    // It is a diagnostic parity pin, not a functional result bus.
    assign status = ^{read_a, read_b, result};
endmodule
