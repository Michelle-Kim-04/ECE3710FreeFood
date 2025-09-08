`timescale 1ns/1ps
`default_nettype none

module top (
    input  wire [9:0] SW,        // 10 bottom
    input  wire [1:0] KEY,       // 2 key
    input  wire       CLOCK_50,  // 50 MHz 
    output wire [9:0] LEDR,      // low 10 case
    output wire [6:0] HEX0,      // y[3:0]
    output wire [6:0] HEX1,      // y[7:4]
    output wire [6:0] HEX2,      // y[11:8]
    output wire [6:0] HEX3       // y[15:12]
);

    // =============================
    // Setup Inputs
    // =============================
    wire [15:0] a, b;
    wire [4:0]  alu_op;

    // a = SW3..0 (4 input，scale 0–15)
    assign a = {12'b0, SW[3:0]};

    // b = SW7..4 (4 input，scale 0–15)
    assign b = {12'b0, SW[7:4]};

    // alu_op = SW9..8 (2 choose)
    // 00 -> ADD, 01 -> SUB, 10 -> AND, 11 -> OR
    assign alu_op = (SW[9:8] == 2'b00) ? 5'd0   : // ADD
                    (SW[9:8] == 2'b01) ? 5'd8   : // SUB
                    (SW[9:8] == 2'b10) ? 5'd14  : // AND
                    (SW[9:8] == 2'b11) ? 5'd16  : // OR
                    5'd0;

    // =============================
    // ALU output
    // =============================
    wire [15:0] y;
    wire        y_valid;
    wire [4:0]  flags_out;
    wire [4:0]  flags_raw;

    alu16 uut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .shamt(5'd1),        
        .psr_c_in(1'b0),
        .flags_en(1'b1),
        .flags_sel(5'b11111),
        .flags_out(flags_out),
        .flags_raw(flags_raw),
        .y(y),
        .y_valid(y_valid)
    );

    // =============================
    // Output of ALU
    // =============================
    assign LEDR = y[9:0];  

    hex7seg h0(.bin(y[3:0]),   .seg(HEX0));
    hex7seg h1(.bin(y[7:4]),   .seg(HEX1));
    hex7seg h2(.bin(y[11:8]),  .seg(HEX2));
    hex7seg h3(.bin(y[15:12]), .seg(HEX3));

endmodule


// =============================
// 7 Segment module
// =============================
module hex7seg (
    input  wire [3:0] bin,
    output reg  [6:0] seg
);
    always @(*) begin
        case (bin)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b1111111;
        endcase
    end
endmodule

`default_nettype wire

