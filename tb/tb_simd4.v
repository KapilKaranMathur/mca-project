
`timescale 1ns/1ps

module tb_simd4;

    reg [63:0] a_vec;
    reg [63:0] b_vec;
    reg [2:0] opcode;

    wire [63:0] result_vec;

    // Instantiate the four-lane SIMD unit
    simd4 dut (
        .a_vec(a_vec),
        .b_vec(b_vec),
        .opcode(opcode),
        .result_vec(result_vec)
    );

    initial begin

        $dumpfile("simd4.vcd");
        $dumpvars(0, tb_simd4);

        // TEST 1: Vector Addition
        a_vec = {16'd40, 16'd30, 16'd20, 16'd10};
        b_vec = {16'd4, 16'd3, 16'd2, 16'd1};

        opcode = 3'b000;

        #1;

        // Check all four lanes
        if (result_vec === {16'd44, 16'd33, 16'd22, 16'd11})
            $display("PASS: SIMD Vector Addition");
        else
            $fatal(1, "FAIL: SIMD Vector Addition");

        // TEST 2: Vector Subtraction
        opcode = 3'b001;

        #1;

        if (result_vec === {16'd36, 16'd27, 16'd18, 16'd9})
            $display("PASS: SIMD Vector Subtraction");
        else
            $fatal(1, "FAIL: SIMD Vector Subtraction");

        
        // TEST 3: Vector AND
        a_vec = {16'd12, 16'd10, 16'd6, 16'd15};
        b_vec = {16'd10, 16'd12, 16'd3, 16'd5};
        opcode = 3'b010;

        #1;

        if (result_vec === {16'd8, 16'd8, 16'd2, 16'd5})
            $display("PASS: SIMD Vector AND");
        else
            $fatal(1, "FAIL: SIMD Vector AND");


        // TEST 4: Vector OR
        opcode = 3'b011;

        #1;

        if (result_vec === {16'd14, 16'd14, 16'd7, 16'd15})
            $display("PASS: SIMD Vector OR");
        else
            $fatal(1, "FAIL: SIMD Vector OR");


        // TEST 5: Vector Comparison
        a_vec = {16'd2, 16'd5, 16'd10, 16'd3};
        b_vec = {16'd8, 16'd5, 16'd3, 16'd10};
        opcode = 3'b100;

        #1;

        if (result_vec === {16'd1, 16'd0, 16'd0, 16'd1})
            $display("PASS: SIMD Vector Comparison");
        else
            $fatal(1, "FAIL: SIMD Vector Comparison");

        $finish;

    end

endmodule
