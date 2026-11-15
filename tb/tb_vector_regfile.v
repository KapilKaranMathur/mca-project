
`timescale 1ns/1ps

module tb_vector_regfile;

    // Clock and write-enable signals
    reg clk = 0;
    reg we;

    // Register addresses
    reg [2:0] read_addr_a;
    reg [2:0] read_addr_b;
    reg [2:0] write_addr;

    // Input data
    reg [63:0] write_data;

    // Output data
    wire [63:0] read_data_a;
    wire [63:0] read_data_b;

    // Clock generation: 10 ns period
    always #5 clk = ~clk;

    // Design Under Test
    vector_regfile dut (
        .clk(clk),
        .we(we),
        .read_addr_a(read_addr_a),
        .read_addr_b(read_addr_b),
        .write_addr(write_addr),
        .write_data(write_data),
        .read_data_a(read_data_a),
        .read_data_b(read_data_b)
    );

    initial begin

        // Generate waveform
        $dumpfile("vector_regfile.vcd");
        $dumpvars(0, tb_vector_regfile);

        // TEST 1: Write V0
        we = 1;
        write_addr = 3'd0;
        write_data = {16'd40, 16'd30, 16'd20, 16'd10};

        read_addr_a = 3'd0;
        read_addr_b = 3'd1;

        @(posedge clk);
        #1;

        if (read_data_a === {16'd40, 16'd30, 16'd20, 16'd10})
            $display("PASS: V0 written successfully");
        else
            $fatal(1, "FAIL: V0 write failed");


        // TEST 2: Write V1
        we = 1;
        write_addr = 3'd1;
        write_data = {16'd4, 16'd3, 16'd2, 16'd1};

        @(posedge clk);
        #1;

        if (read_data_b === {16'd4, 16'd3, 16'd2, 16'd1})
            $display("PASS: V1 written successfully");
        else
            $fatal(1, "FAIL: V1 write failed");


        // TEST 3: Check V0 retains its data
        we = 0;

        if (read_data_a === {16'd40, 16'd30, 16'd20, 16'd10})
            $display("PASS: V0 data retained");
        else
            $fatal(1, "FAIL: V0 data changed");


        // TEST 4: Asynchronous reads
        read_addr_a = 3'd1;
        read_addr_b = 3'd0;

        #1;

        if (
            read_data_a === {16'd4, 16'd3, 16'd2, 16'd1} &&
            read_data_b === {16'd40, 16'd30, 16'd20, 16'd10}
        )
            $display("PASS: Asynchronous reads");
        else
            $fatal(1, "FAIL: Asynchronous reads");


        // TEST 5: Write disabled
        write_addr = 3'd0;
        write_data = 64'hFFFFFFFFFFFFFFFF;
        we = 0;

        @(posedge clk);
        #1;

        if (read_data_b === {16'd40, 16'd30, 16'd20, 16'd10})
            $display("PASS: Write disabled correctly");
        else
            $fatal(1, "FAIL: WE signal not working");


        $display("==============================");
        $display("ALL REGISTER FILE TESTS PASSED");
        $display("==============================");

        $finish;

    end

endmodule
