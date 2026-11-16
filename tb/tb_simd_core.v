
`timescale 1ns/1ps

module tb_simd_core;

    // Clock
    reg clk = 0;

    // Control signals
    reg load_en;
    reg execute_en;

    // External loading
    reg [2:0] load_addr;
    reg [63:0] load_data;

    // Instruction addresses
    reg [2:0] src_a_addr;
    reg [2:0] src_b_addr;
    reg [2:0] dst_addr;

    // Operation selection
    reg [2:0] opcode;

    // Outputs from SIMD core
    wire [63:0] src_a_data;
    wire [63:0] src_b_data;
    wire [63:0] alu_result;

    // Expected vectors
    localparam [63:0] V0 =
        {16'd40, 16'd30, 16'd20, 16'd10};

    localparam [63:0] V1 =
        {16'd4, 16'd3, 16'd2, 16'd1};

    localparam [63:0] EXPECTED =
        {16'd44, 16'd33, 16'd22, 16'd11};

    // Generate clock: 10 ns period
    always #5 clk = ~clk;

    // Instantiate SIMD Core
    simd_core dut (
        .clk(clk),
        .load_en(load_en),
        .execute_en(execute_en),
        .load_addr(load_addr),
        .load_data(load_data),
        .src_a_addr(src_a_addr),
        .src_b_addr(src_b_addr),
        .dst_addr(dst_addr),
        .opcode(opcode),
        .src_a_data(src_a_data),
        .src_b_data(src_b_data),
        .alu_result(alu_result)
    );

    initial begin

        // Waveform generation
        $dumpfile("simd_core.vcd");
        $dumpvars(0, tb_simd_core);

        // Initialize control signals
        load_en = 0;
        execute_en = 0;

        load_addr = 0;
        load_data = 0;

        src_a_addr = 0;
        src_b_addr = 1;
        dst_addr = 2;

        opcode = 3'b000; // ADD

        // ==================================
        // TEST 1: Load Vector V0
        // ==================================

        @(negedge clk);

        load_en = 1;
        load_addr = 3'd0;
        load_data = V0;

        @(posedge clk);
        #1;

        if (src_a_data === V0)
            $display("PASS: V0 loaded correctly");
        else
            $fatal(1, "FAIL: V0 loading failed");


        // ==================================
        // TEST 2: Load Vector V1
        // ==================================

        @(negedge clk);

        load_addr = 3'd1;
        load_data = V1;

        @(posedge clk);
        #1;

        if (src_b_data === V1)
            $display("PASS: V1 loaded correctly");
        else
            $fatal(1, "FAIL: V1 loading failed");


        // ==================================
        // TEST 3: Execute SIMD ADD
        // ==================================

        @(negedge clk);

        load_en = 0;
        execute_en = 1;

        src_a_addr = 3'd0;
        src_b_addr = 3'd1;
        dst_addr = 3'd2;

        opcode = 3'b000;

        #1;

        if (alu_result === EXPECTED)
            $display("PASS: SIMD ADD calculated correctly");
        else
            $fatal(1, "FAIL: SIMD ADD calculation");


        // ==================================
        // TEST 4: Write Result into V2
        // ==================================

        @(posedge clk);
        #1;

        // Disable execution after write-back
        execute_en = 0;

        // Read V2 using source port A
        src_a_addr = 3'd2;

        #1;

        if (src_a_data === EXPECTED)
            $display("PASS: V2 write-back correct");
        else
            $fatal(1, "FAIL: V2 write-back incorrect");

        
        // ==================================
        // TEST 5: Execute V3 = V0 - V1
        // ==================================

        @(negedge clk);

        // Select source registers
        src_a_addr = 3'd0;
        src_b_addr = 3'd1;

        // Select destination register
        dst_addr = 3'd3;

        // SUB instruction
        opcode = 3'b001;

        load_en = 0;
        execute_en = 1;

        #1;

        // Verify ALU calculation
        if (alu_result === {16'd36, 16'd27, 16'd18, 16'd9})
            $display("PASS: SIMD SUB calculated correctly");
        else
            $fatal(1, "FAIL: SIMD SUB calculation");


        // Write result into V3
        @(posedge clk);
        #1;

        execute_en = 0;

        // Read V3 through source port A
        src_a_addr = 3'd3;
        #1;

        if (src_a_data === {16'd36, 16'd27, 16'd18, 16'd9})
            $display("PASS: V3 write-back correct");
        else
            $fatal(1, "FAIL: V3 write-back incorrect");


        // ==================================
        // TEST 6: Execute V4 = V0 AND V1
        // ==================================

        @(negedge clk);

        src_a_addr = 3'd0;
        src_b_addr = 3'd1;
        dst_addr = 3'd4;

        opcode = 3'b010;  // AND

        load_en = 0;
        execute_en = 1;

        #1;

        // Verify calculated result
        if (alu_result === {16'd0, 16'd2, 16'd0, 16'd0})
            $display("PASS: SIMD AND calculated correctly");
        else
            $fatal(1, "FAIL: SIMD AND calculation");

        // Write result into V4
        @(posedge clk);
        #1;

        execute_en = 0;
        src_a_addr = 3'd4;

        #1;

        if (src_a_data === {16'd0, 16'd2, 16'd0, 16'd0})
            $display("PASS: V4 write-back correct");
        else
            $fatal(1, "FAIL: V4 write-back incorrect");


        // ==================================
        // TEST 7: Execute V5 = V0 OR V1
        // ==================================

        @(negedge clk);

        src_a_addr = 3'd0;
        src_b_addr = 3'd1;
        dst_addr = 3'd5;

        opcode = 3'b011;  // OR

        load_en = 0;
        execute_en = 1;

        #1;

        // Verify calculated result
        if (alu_result === {16'd44, 16'd31, 16'd22, 16'd11})
            $display("PASS: SIMD OR calculated correctly");
        else
            $fatal(1, "FAIL: SIMD OR calculation");

        // Write result into V5
        @(posedge clk);
        #1;

        execute_en = 0;
        src_a_addr = 3'd5;

        #1;

        if (src_a_data === {16'd44, 16'd31, 16'd22, 16'd11})
            $display("PASS: V5 write-back correct");
        else
            $fatal(1, "FAIL: V5 write-back incorrect");

        
        // ==================================
        // TEST 8: Load new vector into V6
        // ==================================

        @(negedge clk);

        load_en = 1;
        execute_en = 0;

        load_addr = 3'd6;
        load_data = {16'd35, 16'd30, 16'd25, 16'd5};

        @(posedge clk);
        #1;

        src_a_addr = 3'd6;
        #1;

        if (src_a_data === {16'd35, 16'd30, 16'd25, 16'd5})
            $display("PASS: V6 loaded correctly");
        else
            $fatal(1, "FAIL: V6 loading");


        // ==================================
        // TEST 9: Execute V7 = V6 < V0
        // ==================================

        @(negedge clk);

        load_en = 0;
        execute_en = 1;

        src_a_addr = 3'd6;
        src_b_addr = 3'd0;
        dst_addr = 3'd7;

        opcode = 3'b100;  // CMP

        #1;

        // Expected: [1, 0, 0, 1]
        if (alu_result === {16'd1, 16'd0, 16'd0, 16'd1})
            $display("PASS: SIMD CMP calculated correctly");
        else
            $fatal(1, "FAIL: SIMD CMP calculation");


        // ==================================
        // TEST 10: Verify V7 write-back
        // ==================================

        @(posedge clk);
        #1;

        execute_en = 0;

        src_a_addr = 3'd7;
        #1;

        if (src_a_data === {16'd1, 16'd0, 16'd0, 16'd1})
            $display("PASS: V7 write-back correct");
        else
            $fatal(1, "FAIL: V7 write-back incorrect");


        // ==================================
        // FINAL RESULT
        // ==================================

        $display("");
        $display("==============================");
        $display("ALL SIMD CORE TESTS PASSED");
        $display("==============================");

        $finish;

    end

endmodule
