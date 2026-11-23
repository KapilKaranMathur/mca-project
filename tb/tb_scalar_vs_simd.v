
`timescale 1ns/1ps

// Phase 3: Scalar vs SIMD Performance Benchmark
// Scalar: 32 x 16-bit registers, one ALU
// SIMD:    8 x 64-bit registers, four ALUs
//
// Both processors use the same 16-bit ALU operations.
//
// Measures:
// 1. Data loading cycles
// 2. Execution cycles
// 3. Total cycles
// 4. Throughput
// 5. Speed-up

module tb_scalar_vs_simd;

    localparam MAX_ELEMENTS = 1024;

    // ============================================
    // CLOCK AND CYCLE COUNTER
    // ============================================

    reg clk = 1'b0;

    always #5 clk = ~clk;

    integer clock_edges = 0;

    always @(posedge clk)
        clock_edges = clock_edges + 1;


    // ============================================
    // SCALAR PROCESSOR SIGNALS
    // ============================================

    reg s_load_en = 1'b0;
    reg [4:0] s_load_addr = 5'd0;
    reg [15:0] s_load_data = 16'd0;

    reg s_execute_en = 1'b0;

    reg [4:0] s_src_a_addr = 5'd0;
    reg [4:0] s_src_b_addr = 5'd0;
    reg [4:0] s_dst_addr = 5'd0;

    reg [2:0] s_opcode = 3'd0;

    wire [15:0] s_src_a_data;
    wire [15:0] s_src_b_data;
    wire [15:0] s_alu_result;


    scalar_core scalar_dut (

        .clk(clk),

        .load_en(s_load_en),
        .load_addr(s_load_addr),
        .load_data(s_load_data),

        .execute_en(s_execute_en),

        .src_a_addr(s_src_a_addr),
        .src_b_addr(s_src_b_addr),
        .dst_addr(s_dst_addr),

        .opcode(s_opcode),

        .src_a_data(s_src_a_data),
        .src_b_data(s_src_b_data),
        .alu_result(s_alu_result)

    );


    // ============================================
    // SIMD PROCESSOR SIGNALS
    // ============================================

    reg v_load_en = 1'b0;
    reg [2:0] v_load_addr = 3'd0;
    reg [63:0] v_load_data = 64'd0;

    reg v_execute_en = 1'b0;

    reg [2:0] v_src_a_addr = 3'd0;
    reg [2:0] v_src_b_addr = 3'd0;
    reg [2:0] v_dst_addr = 3'd0;

    reg [2:0] v_opcode = 3'd0;

    wire [63:0] v_src_a_data;
    wire [63:0] v_src_b_data;
    wire [63:0] v_alu_result;


    simd_core simd_dut (

        .clk(clk),

        .load_en(v_load_en),
        .load_addr(v_load_addr),
        .load_data(v_load_data),

        .execute_en(v_execute_en),

        .src_a_addr(v_src_a_addr),
        .src_b_addr(v_src_b_addr),
        .dst_addr(v_dst_addr),

        .opcode(v_opcode),

        .src_a_data(v_src_a_data),
        .src_b_data(v_src_b_data),
        .alu_result(v_alu_result)

    );


    // ============================================
    // BENCHMARK DATA
    // ============================================

    reg [15:0] input_a [0:MAX_ELEMENTS-1];
    reg [15:0] input_b [0:MAX_ELEMENTS-1];

    reg [15:0] scalar_outputs [0:MAX_ELEMENTS-1];

    integer csv_file;
    integer i;

    integer verified_pairs = 0;


    // ============================================
    // INDEPENDENT REFERENCE ALU
    // ============================================

    function automatic [15:0] reference_alu;

        input [15:0] a;
        input [15:0] b;
        input [2:0] operation;

        begin

            case (operation)

                3'b000:
                    reference_alu = a + b;

                3'b001:
                    reference_alu = a - b;

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


    // ============================================
    // LOAD SCALAR REGISTER
    // ============================================

    task automatic load_scalar;

        input [4:0] addr;
        input [15:0] value;

        begin

            @(negedge clk);

            s_load_en = 1'b1;
            s_execute_en = 1'b0;

            s_load_addr = addr;
            s_load_data = value;

            @(posedge clk);
            #1;

            s_load_en = 1'b0;

        end

    endtask


    // ============================================
    // LOAD SIMD REGISTER
    // ============================================

    task automatic load_simd;

        input [2:0] addr;
        input [63:0] value;

        begin

            @(negedge clk);

            v_load_en = 1'b1;
            v_execute_en = 1'b0;

            v_load_addr = addr;
            v_load_data = value;

            @(posedge clk);
            #1;

            v_load_en = 1'b0;

        end

    endtask


    // ============================================
    // EXECUTE SCALAR OPERATION
    // ============================================

    task automatic execute_scalar;

        input [4:0] addr_a;
        input [4:0] addr_b;
        input [4:0] addr_dst;

        input [2:0] operation;
        input [15:0] expected;

        begin

            @(negedge clk);

            s_load_en = 1'b0;
            s_execute_en = 1'b1;

            s_src_a_addr = addr_a;
            s_src_b_addr = addr_b;
            s_dst_addr = addr_dst;

            s_opcode = operation;

            #1;

            // Verify ALU result before write-back
            if (s_alu_result !== expected)
                $fatal(
                    1,
                    "Scalar ALU mismatch: op=%0d A=%0d B=%0d got=%h expected=%h",
                    operation,
                    addr_a,
                    addr_b,
                    s_alu_result,
                    expected
                );

            @(posedge clk);
            #1;

            // Disable execution after write-back
            s_execute_en = 1'b0;

            // Read destination register
            s_src_a_addr = addr_dst;

            #1;

            if (s_src_a_data !== expected)
                $fatal(
                    1,
                    "Scalar write-back mismatch: R%0d got=%h expected=%h",
                    addr_dst,
                    s_src_a_data,
                    expected
                );

        end

    endtask


    // ============================================
    // EXECUTE SIMD OPERATION
    // ============================================

    task automatic execute_simd;

        input [2:0] addr_a;
        input [2:0] addr_b;
        input [2:0] addr_dst;

        input [2:0] operation;
        input [63:0] expected;

        begin

            @(negedge clk);

            v_load_en = 1'b0;
            v_execute_en = 1'b1;

            v_src_a_addr = addr_a;
            v_src_b_addr = addr_b;
            v_dst_addr = addr_dst;

            v_opcode = operation;

            #1;

            // Verify all four ALU results
            if (v_alu_result !== expected)
                $fatal(
                    1,
                    "SIMD ALU mismatch: op=%0d A=%0d B=%0d got=%h expected=%h",
                    operation,
                    addr_a,
                    addr_b,
                    v_alu_result,
                    expected
                );

            @(posedge clk);
            #1;

            v_execute_en = 1'b0;

            // Read destination register
            v_src_a_addr = addr_dst;

            #1;

            if (v_src_a_data !== expected)
                $fatal(
                    1,
                    "SIMD write-back mismatch: V%0d got=%h expected=%h",
                    addr_dst,
                    v_src_a_data,
                    expected
                );

        end

    endtask


    // ============================================
    // SCALAR VS SIMD WORKLOAD
    // ============================================

    task automatic run_workload;

        input integer elements;
        input [2:0] operation;

        integer base;
        integer j;
        integer lane;

        integer start_edges;

        integer s_load_cycles;
        integer s_execute_cycles;

        integer v_load_cycles;
        integer v_execute_cycles;

        integer s_total;
        integer v_total;

        reg [63:0] word_a;
        reg [63:0] word_b;
        reg [63:0] expected_word;

        reg [23:0] operation_name;

        begin

            case (operation)

                3'd0: operation_name = "ADD";
                3'd1: operation_name = "SUB";
                3'd2: operation_name = "AND";
                3'd3: operation_name = "OR";
                3'd4: operation_name = "CMP";

                default:
                    $fatal(1, "Unsupported benchmark opcode");

            endcase


            // Reset counters for this workload
            s_load_cycles = 0;
            s_execute_cycles = 0;

            v_load_cycles = 0;
            v_execute_cycles = 0;


            // Process data in 16-element batches
            for (
                base = 0;
                base < elements;
                base = base + 16
            ) begin

                // ==================================
                // SCALAR LOADING
                // ==================================

                start_edges = clock_edges;

                for (j = 0; j < 16; j = j + 1) begin

                    load_scalar(
                        j,
                        input_a[base+j]
                    );

                    load_scalar(
                        16+j,
                        input_b[base+j]
                    );

                end

                s_load_cycles =
                    s_load_cycles +
                    (clock_edges - start_edges);


                // ==================================
                // SCALAR EXECUTION
                // ==================================

                start_edges = clock_edges;

                for (j = 0; j < 16; j = j + 1) begin

                    execute_scalar(
                        j,
                        16+j,
                        j,
                        operation,
                        reference_alu(
                            input_a[base+j],
                            input_b[base+j],
                            operation
                        )
                    );

                    scalar_outputs[base+j] =
                        s_src_a_data;

                end

                s_execute_cycles =
                    s_execute_cycles +
                    (clock_edges - start_edges);


                // ==================================
                // SIMD LOADING
                // ==================================

                start_edges = clock_edges;

                for (j = 0; j < 4; j = j + 1) begin

                    word_a = {
                        input_a[base+4*j+3],
                        input_a[base+4*j+2],
                        input_a[base+4*j+1],
                        input_a[base+4*j+0]
                    };

                    word_b = {
                        input_b[base+4*j+3],
                        input_b[base+4*j+2],
                        input_b[base+4*j+1],
                        input_b[base+4*j+0]
                    };

                    load_simd(j, word_a);

                    load_simd(j+4, word_b);

                end

                v_load_cycles =
                    v_load_cycles +
                    (clock_edges - start_edges);


                // ==================================
                // SIMD EXECUTION
                // ==================================

                start_edges = clock_edges;

                for (j = 0; j < 4; j = j + 1) begin

                    expected_word = 64'd0;

                    for (
                        lane = 0;
                        lane < 4;
                        lane = lane + 1
                    ) begin

                        expected_word[lane*16 +: 16] =
                            reference_alu(
                                input_a[base+4*j+lane],
                                input_b[base+4*j+lane],
                                operation
                            );

                    end

                    execute_simd(
                        j,
                        j+4,
                        j,
                        operation,
                        expected_word
                    );


                    // Verify scalar and SIMD results match
                    for (
                        lane = 0;
                        lane < 4;
                        lane = lane + 1
                    ) begin

                        if (
                            v_src_a_data[lane*16 +: 16]
                            !==
                            scalar_outputs[base+4*j+lane]
                        )
                            $fatal(
                                1,
                                "Scalar/SIMD mismatch: op=%0d element=%0d",
                                operation,
                                base+4*j+lane
                            );

                        verified_pairs =
                            verified_pairs + 1;

                    end

                end

                v_execute_cycles =
                    v_execute_cycles +
                    (clock_edges - start_edges);

            end


            // ==================================
            // FINAL CYCLE CALCULATIONS
            // ==================================

            s_total =
                s_load_cycles + s_execute_cycles;

            v_total =
                v_load_cycles + v_execute_cycles;


            if (
                s_execute_cycles == 0 ||
                v_execute_cycles == 0 ||
                v_total == 0
            )
                $fatal(1, "Invalid cycle counter");


            // Verify precise measurement boundaries.
            // This catches accidental idle-cycle counting.

            if (
                s_load_cycles != elements*2 ||
                s_execute_cycles != elements ||
                v_load_cycles != elements/2 ||
                v_execute_cycles != elements/4
            )
                $fatal(
                    1,
                    "Unexpected cycle count for %0d elements: s_load=%0d s_exec=%0d v_load=%0d v_exec=%0d",
                    elements,
                    s_load_cycles,
                    s_execute_cycles,
                    v_load_cycles,
                    v_execute_cycles
                );


            // ==================================
            // TERMINAL RESULTS
            // ==================================

            $display(
                "PASS %-3s %4d elements | execute cycles: scalar=%4d SIMD=%4d | total: scalar=%4d SIMD=%4d",
                operation_name,
                elements,
                s_execute_cycles,
                v_execute_cycles,
                s_total,
                v_total
            );


            // ==================================
            // CSV RESULTS
            // ==================================

            $fdisplay(
                csv_file,
                "%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.4f,%0.4f,%0.4f,%0.4f",

                operation_name,
                elements,

                s_load_cycles,
                s_execute_cycles,
                s_total,

                v_load_cycles,
                v_execute_cycles,
                v_total,

                $itor(elements) /
                    $itor(s_execute_cycles),

                $itor(elements) /
                    $itor(v_execute_cycles),

                $itor(s_execute_cycles) /
                    $itor(v_execute_cycles),

                $itor(s_total) /
                    $itor(v_total)
            );

        end

    endtask


    // ============================================
    // MAIN TEST SEQUENCE
    // ============================================

    initial begin

        // Generate deterministic test data
        for (
            i = 0;
            i < MAX_ELEMENTS;
            i = i + 1
        ) begin

            case (i % 8)

                0: begin
                    input_a[i] = 16'h0000;
                    input_b[i] = 16'hFFFF;
                end

                1: begin
                    input_a[i] = 16'hFFFF;
                    input_b[i] = 16'h0001;
                end

                2: begin
                    input_a[i] = 16'h8000;
                    input_b[i] = 16'h7FFF;
                end

                3: begin
                    input_a[i] = 16'h7FFF;
                    input_b[i] = 16'h8000;
                end

                4: begin
                    input_a[i] = 16'hAAAA;
                    input_b[i] = 16'h5555;
                end

                5: begin
                    input_a[i] = 16'h5555;
                    input_b[i] = 16'hAAAA;
                end

                6: begin
                    input_a[i] = i*73 + 11;
                    input_b[i] = i*151 + 19;
                end

                7: begin
                    input_a[i] = i*317 + 29;
                    input_b[i] = i*107 + 37;
                end

            endcase

        end


        // Optional waveform generation
        if ($test$plusargs("dump")) begin

            $dumpfile("scalar_vs_simd.vcd");
            $dumpvars(0, tb_scalar_vs_simd);

        end


        // Open CSV file
        csv_file = $fopen(
            "results/benchmark_results.csv",
            "w"
        );

        if (csv_file == 0)
            $fatal(
                1,
                "Cannot open results/benchmark_results.csv; run mkdir -p results"
            );


        // CSV header
        $fdisplay(
            csv_file,
            "operation,elements,scalar_load_cycles,scalar_execute_cycles,scalar_total_cycles,simd_load_cycles,simd_execute_cycles,simd_total_cycles,scalar_throughput_elem_per_cycle,simd_throughput_elem_per_cycle,execution_speedup,total_speedup"
        );


        // =====================================
        // FIX: INITIAL CLOCK SYNCHRONIZATION
        // =====================================

        // The first positive edge occurs before
        // the first transaction begins.
        //
        // Synchronizing here prevents that idle
        // edge from being counted as a load cycle.

        @(posedge clk);
        #1;


        // =====================================
        // RUN ALL BENCHMARKS
        // =====================================

        $display(
            "=============================================="
        );

        $display(
            " SCALAR vs SIMD: MEASURED SIMULATION CYCLES"
        );

        $display(
            "=============================================="
        );


        // Five operations
        for (i = 0; i < 5; i = i + 1) begin

            run_workload(16,   i);
            run_workload(64,   i);
            run_workload(256,  i);
            run_workload(1024, i);

        end


        $fclose(csv_file);


        // =====================================
        // FINAL REPORT
        // =====================================

        $display(
            "----------------------------------------------"
        );

        $display(
            "PASS: %0d scalar/SIMD output pairs compared",
            verified_pairs
        );

        $display(
            "CSV saved: results/benchmark_results.csv"
        );

        $display(
            "NOTE: The clock is simulated; FPGA Fmax is not measured."
        );

        $display(
            "ALL SCALAR VS SIMD BENCHMARKS PASSED"
        );

        $display(
            "=============================================="
        );

        $finish;

    end

endmodule
