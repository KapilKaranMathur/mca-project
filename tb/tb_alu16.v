
`timescale 1ns/1ps

module tb_alu16;

    reg [15:0] a, b;
    reg [2:0] opcode;
    wire [15:0] result;

    alu16 dut (
        .a(a),
        .b(b),
        .opcode(opcode),
        .result(result)
    );

    initial begin

        $dumpfile("alu16.vcd");
        $dumpvars(0, tb_alu16);

        // TEST 1: Addition
        a = 16'd10;
        b = 16'd20;
        opcode = 3'b000;
        #1;

        if (result === 16'd30)
            $display("PASS: 10 + 20 = %d", result);
        else
            $fatal(1, "FAIL: Addition");

        // TEST 2: Subtraction
        a = 16'd10;
        b = 16'd3;
        opcode = 3'b001;
        #1;

        if (result === 16'd7)
            $display("PASS: 10 - 3 = %d", result);
        else
            $fatal(1, "FAIL: Subtraction");

        // TEST 3: Bitwise AND
        a = 16'd12;
        b = 16'd10;
        opcode = 3'b010;
        #1;

        if (result === 16'd8)
            $display("PASS: 12 AND 10 = %d", result);
        else
            $fatal(1, "FAIL: AND");

        // TEST 4: Bitwise OR
        a = 16'd12;
        b = 16'd10;
        opcode = 3'b011;
        #1;

        if (result === 16'd14)
            $display("PASS: 12 OR 10 = %d", result);
        else
            $fatal(1, "FAIL: OR");

        // TEST 5: Comparison - True
        a = 16'd3;
        b = 16'd10;
        opcode = 3'b100;
        #1;

        if (result === 16'd1)
            $display("PASS: 3 < 10 = %d", result);
        else
            $fatal(1, "FAIL: Comparison true");

        // TEST 6: Comparison - False
        a = 16'd10;
        b = 16'd3;
        opcode = 3'b100;
        #1;

        if (result === 16'd0)
            $display("PASS: 10 < 3 = %d", result);
        else
            $fatal(1, "FAIL: Comparison false");

        // TEST 7: Comparison - Equal
        a = 16'd10;
        b = 16'd10;
        opcode = 3'b100;
        #1;

        if (result === 16'd0)
            $display("PASS: 10 < 10 = %d", result);
        else
            $fatal(1, "FAIL: Comparison equal");

        // TEST 8: Overflow
        a = 16'd65535;
        b = 16'd1;
        opcode = 3'b000;
        #1;

        if (result === 16'd0)
            $display("PASS: Overflow (65535 + 1) = %d", result);
        else
            $fatal(1, "FAIL: Overflow");

        // TEST 9: Underflow
        a = 16'd0;
        b = 16'd1;
        opcode = 3'b001;
        #1;

        if (result === 16'd65535)
            $display("PASS: Underflow (0 - 1) = %d", result);
        else
            $fatal(1, "FAIL: Underflow");

        $display("");
        $display("==========================");
        $display("ALL 9 TEST CASES PASSED");
        $display("==========================");

        $finish;

    end

endmodule
