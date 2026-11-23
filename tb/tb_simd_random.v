
`timescale 1ns/1ps

module tb_simd_random;

    // Number of randomized vector tests
    localparam NUM_TESTS = 10000;

    // DUT inputs and output
    reg [63:0] a_vec;
    reg [63:0] b_vec;
    reg [2:0] opcode;

    wire [63:0] result_vec;

    // Test statistics
    integer random_tests;
    integer directed_tests;
    integer lane_checks;

    integer opcode_count [0:4];

    integer i;
    integer lane;
    integer seed;

    reg [63:0] test_a;
    reg [63:0] test_b;

    // ========================================
    // DEVICE UNDER TEST
    // ========================================

    simd4 dut (
        .a_vec(a_vec),
        .b_vec(b_vec),
        .opcode(opcode),
        .result_vec(result_vec)
    );

    // ========================================
    // REFERENCE MODEL FOR ONE LANE
    // ========================================

    function automatic [15:0] reference_alu;

        input [15:0] a;
        input [15:0] b;
        input [2:0] op;

        reg [31:0] temp;

        begin

            case (op)

                3'b000: begin
                    temp = {16'b0, a} + {16'b0, b};
                    reference_alu = temp[15:0];
                end

                3'b001: begin
                    temp = {16'b0, a} - {16'b0, b};
                    reference_alu = temp[15:0];
                end

                3'b010:
                    reference_alu = a & b;

                3'b011:
                    reference_alu = a | b;

                3'b100:
                    reference_alu =
                        (a < b) ? 16'd1 : 16'd0;

                default:
                    reference_alu = 16'd0;

            endcase

        end

    endfunction

    // ========================================
    // SELF-CHECKING VECTOR TEST TASK
    // ========================================

    task automatic check_vector;

        input [63:0] input_a;
        input [63:0] input_b;
        input [2:0] operation;

        integer j;

        reg [15:0] expected;
        reg [15:0] actual;

        begin

            a_vec = input_a;
            b_vec = input_b;
            opcode = operation;

            // Allow combinational logic to settle
            #1;

            // Verify every lane independently
            for (j = 0; j < 4; j = j + 1) begin

                expected = reference_alu(
                    input_a[j*16 +: 16],
                    input_b[j*16 +: 16],
                    operation
                );

                actual = result_vec[j*16 +: 16];

                if (actual !== expected) begin

                    $display("");
                    $display("SIMD TEST FAILED");
                    $display("Opcode: %b", operation);
                    $display("Lane: %0d", j);
                    $display("Vector A: %h", input_a);
                    $display("Vector B: %h", input_b);

                    $display(
                        "Operand A: %0d",
                        input_a[j*16 +: 16]
                    );

                    $display(
                        "Operand B: %0d",
                        input_b[j*16 +: 16]
                    );

                    $display("Expected: %0d", expected);
                    $display("Actual:   %0d", actual);

                    $fatal(1, "SIMD lane mismatch");

                end

                lane_checks = lane_checks + 1;

            end

        end

    endtask

    // ========================================
    // MAIN TEST SEQUENCE
    // ========================================

    initial begin

        random_tests = 0;
        directed_tests = 0;
        lane_checks = 0;

        // Fixed seed for repeatable testing
        seed = 12345;

        for (i = 0; i < 5; i = i + 1)
            opcode_count[i] = 0;

        // Optional waveform generation
        if ($test$plusargs("dump")) begin
            $dumpfile("simd_random.vcd");
            $dumpvars(0, tb_simd_random);
        end

        $display("");
        $display("====================================");
        $display(" ADVANCED SIMD VERIFICATION");
        $display("====================================");

        // ====================================
        // TEST 1: OVERFLOW IN EVERY LANE
        // ====================================

        for (lane = 0; lane < 4; lane = lane + 1) begin

            test_a = {
                16'd40, 16'd30, 16'd20, 16'd10
            };

            test_b = {
                16'd4, 16'd3, 16'd2, 16'd1
            };

            test_a[lane*16 +: 16] = 16'hFFFF;
            test_b[lane*16 +: 16] = 16'd1;

            check_vector(test_a, test_b, 3'b000);

            directed_tests = directed_tests + 1;

        end

        $display("PASS: Overflow in all four lanes");

        // ====================================
        // TEST 2: UNDERFLOW IN EVERY LANE
        // ====================================

        for (lane = 0; lane < 4; lane = lane + 1) begin

            test_a = {
                16'd40, 16'd30, 16'd20, 16'd10
            };

            test_b = {
                16'd4, 16'd3, 16'd2, 16'd1
            };

            test_a[lane*16 +: 16] = 16'd0;
            test_b[lane*16 +: 16] = 16'd1;

            check_vector(test_a, test_b, 3'b001);

            directed_tests = directed_tests + 1;

        end

        $display("PASS: Underflow in all four lanes");
        $display("PASS: Independent lane operation");

        // ====================================
        // TEST 3: UNSIGNED COMPARISON
        // ====================================

        check_vector(
            {16'd65535, 16'd32768, 16'd32767, 16'd0},
            {16'd0, 16'd32767, 16'd32768, 16'd1},
            3'b100
        );

        directed_tests = directed_tests + 1;

        check_vector(
            {16'd65535, 16'd32768, 16'd1, 16'd0},
            {16'd65535, 16'd65535, 16'd0, 16'd0},
            3'b100
        );

        directed_tests = directed_tests + 1;

        $display("PASS: Unsigned comparison boundaries");
        $display("PASS: Equal operand comparison");

        // ====================================
        // TEST 4: BITWISE BOUNDARY CONDITIONS
        // ====================================

        check_vector(
            {16'hFFFF, 16'h0000, 16'hAAAA, 16'h5555},
            {16'h0000, 16'hFFFF, 16'h5555, 16'h5555},
            3'b010
        );

        directed_tests = directed_tests + 1;

        check_vector(
            {16'hFFFF, 16'h0000, 16'hAAAA, 16'h5555},
            {16'h0000, 16'hFFFF, 16'h5555, 16'h5555},
            3'b011
        );

        directed_tests = directed_tests + 1;

        $display("PASS: Bitwise AND boundaries");
        $display("PASS: Bitwise OR boundaries");

        // ====================================
        // TEST 5: RANDOMIZED VECTOR OPERATIONS
        // ====================================

        $display("");
        $display("Starting randomized verification...");

        for (i = 0; i < NUM_TESTS; i = i + 1) begin

            // Generate four random 16-bit lanes
            for (lane = 0; lane < 4; lane = lane + 1) begin

                test_a[lane*16 +: 16] = $random(seed);

                test_b[lane*16 +: 16] = $random(seed);

            end

            // Rotate through all five supported operations
            check_vector(test_a, test_b, i % 5);

            opcode_count[i % 5] =
                opcode_count[i % 5] + 1;

            random_tests = random_tests + 1;

            if ((i + 1) % 1000 == 0)
                $display(
                    "PASS: %0d / %0d randomized tests",
                    i + 1, NUM_TESTS
                );

        end

        // ====================================
        // FINAL VERIFICATION REPORT
        // ====================================

        $display("");
        $display("====================================");
        $display(" FINAL VERIFICATION REPORT");
        $display("====================================");

        $display("Randomized ADD: %0d", opcode_count[0]);
        $display("Randomized SUB: %0d", opcode_count[1]);
        $display("Randomized AND: %0d", opcode_count[2]);
        $display("Randomized OR:  %0d", opcode_count[3]);
        $display("Randomized CMP: %0d", opcode_count[4]);

        $display("------------------------------------");

        $display("Directed vector tests: %0d",
                 directed_tests);

        $display("Randomized vector tests: %0d",
                 random_tests);

        $display("Total vector tests: %0d",
                 directed_tests + random_tests);

        $display("Total lane checks: %0d",
                 lane_checks);

        $display("------------------------------------");
        $display("ALL ADVANCED SIMD TESTS PASSED");
        $display("====================================");

        $finish;

    end

endmodule
