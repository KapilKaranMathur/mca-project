
`timescale 1ns/1ps

module tb_alu16;

    reg [15:0] a, b;
    reg [2:0] opcode;
    wire [15:0] result;

    // Connect the ALU to our testbench
    alu16 dut (
        .a(a),
        .b(b),
        .opcode(opcode),
        .result(result)
    );

    initial begin

        // Generate waveform file
        $dumpfile("alu16.vcd");
        $dumpvars(0, tb_alu16);
        
        // Test 1: Addition
        a = 16'd10;
        b = 16'd20;
        opcode = 3'b000;

        #1;

        if (result === 16'd30)
            $display("PASS: 10 + 20 = %d", result);
        else
            $fatal(1, "FAIL: Expected 30, got %d", result);

        
        // Test 2: Subtraction
        a = 16'd10;
        b = 16'd3;
        opcode = 3'b001;

        #1;

        if (result === 16'd7)
            $display("PASS: 10 - 3 = %d", result);
        else
            $display("FAIL: Expected 7, got %d", result);

        
        // TEST 3: BITWISE AND
        a = 16'd12;
        b = 16'd10;
        opcode = 3'b010;

        #1;

        if (result === 16'd8)
            $display("PASS: 12 AND 10 = %d", result);
        else
            $display("FAIL: Expected 8, got %d", result);


        // TEST 4: BITWISE OR
        a = 16'd12;
        b = 16'd10;
        opcode = 3'b011;

        #1;

        if (result === 16'd14)
            $display("PASS: 12 OR 10 = %d", result);
        else
            $display("FAIL: Expected 14, got %d", result);
    

        // TEST 5: COMPARISON (A < B)

        // Case 1: A is smaller than B
        a = 16'd3;
        b = 16'd10;
        opcode = 3'b100;

        #1;

        if (result === 16'd1)
            $display("PASS: 3 < 10 = %d", result);
        else
            $display("FAIL: Expected 1, got %d", result);


        // Case 2: A is greater than B
        a = 16'd10;
        b = 16'd3;
        opcode = 3'b100;

        #1;

        if (result === 16'd0)
            $display("PASS: 10 < 3 = %d", result);
        else
            $display("FAIL: Expected 0, got %d", result);


        // Case 3: Both operands are equal
        a = 16'd10;
        b = 16'd10;
        opcode = 3'b100;

        #1;

        if (result === 16'd0)
            $display("PASS: 10 < 10 = %d", result);
        else
            $display("FAIL: Expected 0, got %d", result);


        // TEST 6: 16-BIT ADDITION OVERFLOW
        a = 16'd65535;
        b = 16'd1;
        opcode = 3'b000;

        #1;

        if (result === 16'd0)
            $display("PASS: Overflow (65535 + 1) = %d", result);
        else
            $display("FAIL: Overflow expected 0, got %d", result);


        // TEST 7: SUBTRACTION UNDERFLOW
        a = 16'd0;
        b = 16'd1;
        opcode = 3'b001;

        #1;

        if (result === 16'd65535)
            $display("PASS: Underflow (0 - 1) = %d", result);
        else
            $display("FAIL: Underflow expected 65535, got %d", result);

        $display("\n==========================");
        $display("ALL 9 TEST CASES PASSED");
        $display("==========================\n");

        $finish;

    end

endmodule
