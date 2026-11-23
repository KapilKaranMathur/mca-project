`timescale 1ns/1ps

module tb_scalar_core;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg load_en = 1'b0;
    reg [4:0] load_addr = 5'd0;
    reg [15:0] load_data = 16'd0;
    reg execute_en = 1'b0;
    reg [4:0] src_a_addr = 5'd0;
    reg [4:0] src_b_addr = 5'd0;
    reg [4:0] dst_addr = 5'd0;
    reg [2:0] opcode = 3'd0;

    wire [15:0] src_a_data, src_b_data, alu_result;
    integer i;
    integer checks = 0;

    scalar_core dut (
        .clk(clk),
        .load_en(load_en), .load_addr(load_addr), .load_data(load_data),
        .execute_en(execute_en),
        .src_a_addr(src_a_addr), .src_b_addr(src_b_addr),
        .dst_addr(dst_addr), .opcode(opcode),
        .src_a_data(src_a_data), .src_b_data(src_b_data),
        .alu_result(alu_result)
    );

    // Read back through the public asynchronous read port, not by peeking
    // into internal DUT register arrays.
    task automatic load_and_check;
        input [4:0] addr;
        input [15:0] value;
        begin
            @(negedge clk);
            load_en = 1'b1;
            execute_en = 1'b0;
            load_addr = addr;
            load_data = value;
            @(posedge clk);
            #1;
            load_en = 1'b0;
            src_a_addr = addr;
            #1;
            if (src_a_data !== value)
                $fatal(1, "LOAD FAIL R%0d: got %h, expected %h", addr, src_a_data, value);
            checks = checks + 1;
        end
    endtask

    task automatic execute_and_check;
        input [4:0] a_index;
        input [4:0] b_index;
        input [4:0] dest_index;
        input [2:0] operation;
        input [15:0] expected;
        begin
            @(negedge clk);
            load_en = 1'b0;
            execute_en = 1'b1;
            src_a_addr = a_index;
            src_b_addr = b_index;
            dst_addr = dest_index;
            opcode = operation;
            #1;
            if (alu_result !== expected)
                $fatal(1, "ALU FAIL op=%b: got %h, expected %h", operation, alu_result, expected);
            checks = checks + 1;
            @(posedge clk);
            #1;
            execute_en = 1'b0;
            src_a_addr = dest_index;
            #1;
            if (src_a_data !== expected)
                $fatal(1, "WRITEBACK FAIL R%0d: got %h, expected %h", dest_index, src_a_data, expected);
            checks = checks + 1;
        end
    endtask

    initial begin
        $dumpfile("scalar_core.vcd");
        $dumpvars(0, tb_scalar_core);

        // Address all 32 registers and verify each load.
        for (i = 0; i < 32; i = i + 1)
            load_and_check(i, i * 7 + 3);
        $display("PASS: all 32 scalar registers load and read correctly");

        // Replace selected registers with known operands.
        load_and_check(5'd0, 16'd10);
        load_and_check(5'd1, 16'd3);
        load_and_check(5'd3, 16'hFFFF);
        load_and_check(5'd4, 16'd1);
        load_and_check(5'd5, 16'h0F0F);
        load_and_check(5'd6, 16'h3333);

        execute_and_check(0, 1, 2, 3'b000, 16'd13);   // ADD
        execute_and_check(0, 1, 7, 3'b001, 16'd7);    // SUB
        execute_and_check(5, 6, 8, 3'b010, 16'h0303); // AND
        execute_and_check(5, 6, 9, 3'b011, 16'h3F3F); // OR
        execute_and_check(1, 0, 10, 3'b100, 16'd1);   // CMP
        execute_and_check(3, 4, 11, 3'b000, 16'd0);   // ADD wraparound
        execute_and_check(11, 4, 12, 3'b001, 16'hFFFF); // SUB underflow + dependency
        $display("PASS: five operations, wraparound, and write-back");

        // Unsupported opcodes must not overwrite destination R13.
        load_and_check(5'd13, 16'hBEEF);
        for (i = 5; i < 8; i = i + 1) begin
            @(negedge clk);
            execute_en = 1'b1;
            load_en = 1'b0;
            opcode = i;
            dst_addr = 5'd13;
            src_a_addr = 5'd0;
            src_b_addr = 5'd1;
            @(posedge clk);
            #1;
            execute_en = 1'b0;
            src_a_addr = 5'd13;
            #1;
            if (src_a_data !== 16'hBEEF)
                $fatal(1, "Invalid opcode %0d overwrote R13", i);
            checks = checks + 1;
        end
        $display("PASS: invalid opcode write protection");

        // Simultaneous enables: external loading wins.
        @(negedge clk);
        load_en = 1'b1;
        execute_en = 1'b1;
        load_addr = 5'd14;
        load_data = 16'hCAFE;
        dst_addr = 5'd13;
        opcode = 3'b000;
        @(posedge clk);
        #1;
        load_en = 1'b0;
        execute_en = 1'b0;
        src_a_addr = 5'd14;
        #1;
        if (src_a_data !== 16'hCAFE)
            $fatal(1, "Load priority: R14 incorrect");
        checks = checks + 1;
        src_a_addr = 5'd13;
        #1;
        if (src_a_data !== 16'hBEEF)
            $fatal(1, "Load priority: destination R13 was modified");
        checks = checks + 1;
        $display("PASS: external loading priority");

        // No write when the core is idle.
        @(negedge clk);
        load_en = 1'b0;
        execute_en = 1'b0;
        src_a_addr = 5'd14;
        @(posedge clk);
        #1;
        if (src_a_data !== 16'hCAFE)
            $fatal(1, "Idle changed register contents");
        checks = checks + 1;
        $display("PASS: idle register retention");

        $display("====================================");
        $display("ALL SCALAR CORE TESTS PASSED");
        $display("Checks performed: %0d", checks);
        $display("====================================");
        $finish;
    end
endmodule
