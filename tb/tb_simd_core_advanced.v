`timescale 1ns/1ps

module tb_simd_core_advanced;

    reg clk;
    reg load_en, execute_en;
    reg [2:0] load_addr, src_a_addr, src_b_addr, dst_addr, opcode;
    reg [63:0] load_data;
    wire [63:0] src_a_data, src_b_data, alu_result;

    reg [63:0] model [0:7];
    integer read_checks, operations, random_operations;
    integer seed, i, rnd, action;
    reg [2:0] ra, rb, rd, op;
    reg [63:0] data;

    simd_core dut (
        .clk(clk),
        .load_en(load_en), .load_addr(load_addr), .load_data(load_data),
        .execute_en(execute_en),
        .src_a_addr(src_a_addr), .src_b_addr(src_b_addr),
        .dst_addr(dst_addr), .opcode(opcode),
        .src_a_data(src_a_data), .src_b_data(src_b_data),
        .alu_result(alu_result)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Independent lane-by-lane reference calculation.
    function automatic [63:0] reference_vector;
        input [63:0] a, b;
        input [2:0] operation;
        reg [15:0] x, y, z;
        integer lane;
        begin
            reference_vector = 64'b0;
            for (lane = 0; lane < 4; lane = lane + 1) begin
                x = a[lane*16 +: 16];
                y = b[lane*16 +: 16];
                case (operation)
                    3'b000: z = x + y;
                    3'b001: z = x - y;
                    3'b010: z = x & y;
                    3'b011: z = x | y;
                    3'b100: z = (x < y) ? 16'd1 : 16'd0;
                    default: z = 16'd0;
                endcase
                reference_vector[lane*16 +: 16] = z;
            end
        end
    endfunction

    task automatic check_register;
        input [2:0] index;
        begin
            @(negedge clk);
            load_en = 1'b0;
            execute_en = 1'b0;
            src_a_addr = index;
            src_b_addr = index;
            #1;
            if (src_a_data !== model[index] ||
                src_b_data !== model[index]) begin
                $display("FAIL: register V%0d", index);
                $display("Expected=%h, readA=%h, readB=%h",
                         model[index], src_a_data, src_b_data);
                $fatal(1, "Register readback mismatch");
            end
            read_checks = read_checks + 1;
        end
    endtask

    task automatic check_all_registers;
        integer index;
        begin
            for (index = 0; index < 8; index = index + 1)
                check_register(index[2:0]);
        end
    endtask

    task automatic load_register;
        input [2:0] index;
        input [63:0] value;
        begin
            @(negedge clk);
            load_en = 1'b1;
            execute_en = 1'b0;
            load_addr = index;
            load_data = value;
            src_a_addr = index;
            src_b_addr = index;
            @(posedge clk);
            #1;  // Wait for nonblocking register-file write.
            model[index] = value;
            if (src_a_data !== value || src_b_data !== value)
                $fatal(1, "FAIL: load V%0d", index);
            load_en = 1'b0;
            operations = operations + 1;
        end
    endtask

    task automatic execute_valid;
        input [2:0] operation, address_a, address_b, address_dst;
        reg [63:0] expected;
        begin
            @(negedge clk);
            load_en = 1'b0;
            execute_en = 1'b1;
            opcode = operation;
            src_a_addr = address_a;
            src_b_addr = address_b;
            dst_addr = address_dst;
            expected = reference_vector(model[address_a], model[address_b], operation);
            #1;
            if (src_a_data !== model[address_a] ||
                src_b_data !== model[address_b] ||
                alu_result !== expected) begin
                $display("FAIL: opcode=%b A=V%0d B=V%0d DST=V%0d",
                         operation, address_a, address_b, address_dst);
                $display("Expected result=%h, actual=%h", expected, alu_result);
                $fatal(1, "Execution mismatch");
            end
            @(posedge clk);
            #1;
            model[address_dst] = expected;
            execute_en = 1'b0;
            operations = operations + 1;
            check_register(address_dst);
        end
    endtask

    task automatic execute_invalid;
        input [2:0] invalid_opcode, address_dst;
        begin
            @(negedge clk);
            load_en = 1'b0;
            execute_en = 1'b1;
            opcode = invalid_opcode;
            src_a_addr = 3'd0;
            src_b_addr = 3'd1;
            dst_addr = address_dst;
            #1;
            if (dut.opcode_valid !== 1'b0 || dut.reg_we !== 1'b0)
                $fatal(1, "FAIL: invalid opcode %b permits write", invalid_opcode);
            @(posedge clk);
            #1;
            execute_en = 1'b0;
            operations = operations + 1;
            check_register(address_dst);
        end
    endtask

    task automatic idle_cycle;
        begin
            @(negedge clk);
            load_en = 1'b0;
            execute_en = 1'b0;
            opcode = 3'b000;
            dst_addr = 3'd7;
            @(posedge clk);
            #1;
            operations = operations + 1;
        end
    endtask

    task automatic simultaneous_load_execute;
        reg [63:0] value;
        begin
            value = 64'hABCD_1234_FF00_00EF;
            @(negedge clk);
            load_en = 1'b1;
            execute_en = 1'b1;
            opcode = 3'b000;
            src_a_addr = 3'd0;
            src_b_addr = 3'd1;
            load_addr = 3'd3;
            dst_addr = 3'd7;
            load_data = value;
            #1;
            if (dut.reg_we !== 1'b1 ||
                dut.select_load !== 1'b1 ||
                dut.reg_write_addr !== 3'd3)
                $fatal(1, "FAIL: external load did not get priority");
            @(posedge clk);
            #1;
            model[3] = value;
            load_en = 1'b0;
            execute_en = 1'b0;
            operations = operations + 1;
            check_register(3'd3);
            check_register(3'd7);
        end
    endtask

    // Two executions on successive rising edges, with no idle edge between.
    // The second instruction reads the first instruction's destination.
    task automatic back_to_back_dependency;
        reg [63:0] first_result, second_result;
        begin
            @(negedge clk);
            load_en = 1'b0;
            execute_en = 1'b1;
            src_a_addr = 3'd0;
            src_b_addr = 3'd1;
            dst_addr = 3'd5;
            opcode = 3'b000;
            first_result = reference_vector(model[0], model[1], 3'b000);
            #1;
            if (alu_result !== first_result)
                $fatal(1, "FAIL: first back-to-back result");
            @(posedge clk);
            #1;
            model[5] = first_result;

            @(negedge clk);
            // execute_en stays high: this is the immediately following cycle.
            src_a_addr = 3'd5;
            src_b_addr = 3'd2;
            dst_addr = 3'd6;
            opcode = 3'b001;
            second_result = reference_vector(model[5], model[2], 3'b001);
            #1;
            if (src_a_data !== model[5] || alu_result !== second_result)
                $fatal(1, "FAIL: read-after-write dependency");
            @(posedge clk);
            #1;
            model[6] = second_result;
            execute_en = 1'b0;
            operations = operations + 2;
            check_register(3'd5);
            check_register(3'd6);
        end
    endtask

    initial begin
        load_en = 0;
        execute_en = 0;
        load_addr = 0;
        load_data = 0;
        src_a_addr = 0;
        src_b_addr = 0;
        dst_addr = 0;
        opcode = 0;
        read_checks = 0;
        operations = 0;
        random_operations = 0;
        seed = 32'h13579BDF;

        if ($test$plusargs("dump")) begin
            $dumpfile("simd_core_advanced.vcd");
            $dumpvars(0, tb_simd_core_advanced);
        end

        $display("====================================");
        $display(" ADVANCED INTEGRATED SIMD CORE TEST");
        $display("====================================");

        // Initialize ALL registers; the actual RTL has no reset.
        for (i = 0; i < 8; i = i + 1)
            load_register(i[2:0],
                64'h0101_0202_0303_0404 + i * 64'h0001_0001_0001_0001);
        check_all_registers();
        $display("PASS: loading and reading all eight registers");

        // Every supported operation, with varied source and destination addresses.
        for (i = 0; i < 8; i = i + 1)
            execute_valid(i % 5, i % 8, (i+3) % 8, (i+5) % 8);
        $display("PASS: five opcodes and register write-back");

        back_to_back_dependency();
        $display("PASS: consecutive execution and read-after-write");

        // Invalid opcodes must NOT change a destination register.
        execute_invalid(3'b101, 3'd2);
        execute_invalid(3'b110, 3'd4);
        execute_invalid(3'b111, 3'd6);
        $display("PASS: all three invalid opcodes blocked");

        simultaneous_load_execute();
        $display("PASS: external loading takes priority");

        idle_cycle();
        check_all_registers();
        $display("PASS: idle preserves all register values");

        // Deterministic mixed-transaction regression against the scoreboard.
        for (i = 0; i < 256; i = i + 1) begin
            rnd = $random(seed);
            action = rnd & 3;
            rnd = $random(seed); ra = rnd[2:0];
            rnd = $random(seed); rb = rnd[2:0];
            rnd = $random(seed); rd = rnd[2:0];
            rnd = $random(seed); op = (rnd & 32'h7FFFFFFF) % 5;

            case (action)
                0: begin
                    data = {$random(seed), $random(seed)};
                    load_register(rd, data);
                end
                1: execute_valid(op, ra, rb, rd);
                2: begin
                    rnd = $random(seed);
                    op = 3'd5 + ((rnd & 32'h7FFFFFFF) % 3);
                    execute_invalid(op, rd);
                end
                3: idle_cycle();
            endcase
            random_operations = random_operations + 1;
            if ((i % 32) == 31)
                check_all_registers();
        end
        check_all_registers();
        $display("PASS: %0d mixed randomized transactions", random_operations);

        $display("------------------------------------");
        $display("Operations applied: %0d", operations);
        $display("Register readback checks: %0d", read_checks);
        $display("ALL ADVANCED INTEGRATED CORE TESTS PASSED");
        $display("====================================");
        $finish;
    end

endmodule
