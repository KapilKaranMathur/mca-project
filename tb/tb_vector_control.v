`timescale 1ns/1ps


module tb_vector_control;

reg load_en;
reg execute_en;
reg [2:0] opcode;
reg [2:0] load_addr;
reg [2:0] dst_addr;

wire reg_we;
wire [2:0] reg_write_addr;
wire select_load;
wire opcode_valid;

integer mode, op, la, da;
integer tests_passed;

reg expected_we;
reg expected_valid;
reg [2:0] expected_addr;

// Device under test
vector_control dut (
.load_en(load_en),
.execute_en(execute_en),
.opcode(opcode),
.load_addr(load_addr),
.dst_addr(dst_addr),
.reg_we(reg_we),
.reg_write_addr(reg_write_addr),
.select_load(select_load),
.opcode_valid(opcode_valid)
);

initial begin

$dumpfile("vector_control.vcd");
$dumpvars(0, tb_vector_control);

tests_passed = 0;

// Test all control combinations
for (mode = 0; mode < 4; mode = mode + 1) begin
for (op = 0; op < 8; op = op + 1) begin
for (la = 0; la < 8; la = la + 1) begin
for (da = 0; da < 8; da = da + 1) begin

load_en = mode[1];
                        execute_en = mode[0];
                        opcode = op[2:0];
                        load_addr = la[2:0];
                        dst_addr = da[2:0];

                        expected_valid = (op < 5);

// Reference control behavior
                        if (load_en) begin
                            expected_we = 1'b1;
                            expected_addr = load_addr;
                        end
                        else begin
                            expected_we = execute_en &&
                                          expected_valid;
                            expected_addr = dst_addr;
                        end

                        #1;

if (
                            reg_we !== expected_we ||
                            reg_write_addr !== expected_addr ||
                            select_load !== load_en ||
                            opcode_valid !== expected_valid
                        ) begin

                            $display("FAIL: Control mismatch");

$display(
                                "load=%b execute=%b opcode=%b",
                                load_en, execute_en, opcode
                            );

$display(
                                "load_addr=%d dst_addr=%d",
                                load_addr, dst_addr
                            );

                            $fatal(1, "Vector control test failed");

                        end

                        tests_passed = tests_passed + 1;

end
                end
            end
        end

$display("");
        $display("====================================");
        $display(" VECTOR CONTROL VERIFICATION");
        $display("====================================");
        $display("PASS: Opcode validation");
        $display("PASS: Write-enable logic");
        $display("PASS: Register address selection");
        $display("PASS: External loading priority");
        $display("PASS: Invalid opcode protection");
        $display("PASS: Data MUX control");
        $display("------------------------------------");
        $display("Total combinations tested: %0d",
                 tests_passed);
        $display("ALL VECTOR CONTROL TESTS PASSED");
        $display("====================================");

        $finish;

    end

endmodule
