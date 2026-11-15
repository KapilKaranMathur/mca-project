`timescale 1ns/1ps

module alu16 (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [2:0]  opcode,
    output reg  [15:0] result
);

    always @(*) begin
        case (opcode)
            3'b000: result = a + b;
            3'b001: result = a - b;
            3'b010: result = a & b;
            3'b011: result = a | b;
            3'b100: result = (a < b) ? 16'd1 : 16'd0;
            default: result = 16'd0;
        endcase
    end

endmodule
