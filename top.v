`timescale 1ns/1ps
`default_nettype none

module top (
    input  wire [9:0] SW,        // SW9..7: opcode, SW6: sign bit, SW5..0: input magnitude
    input  wire [1:0] KEY,       // Keys (unused)
    input  wire       CLOCK_50,  // 50 MHz clock (unused)
    output wire [9:0] LEDR,      // LEDR[4:0] = flags {C,F,Z,L,N}
    output wire [6:0] HEX0,      // y[3:0]
    output wire [6:0] HEX1,      // y[7:4]
    output wire [6:0] HEX2,      // y[11:8]
    output wire [6:0] HEX3       // y[15:12]
);

    // =============================
    // Input mapping
    // =============================
    wire [15:0] a, b;
    wire [4:0]  alu_op;

    // Input A: SW6..0 interpreted as signed number (-64 ~ +63)
    assign a = {{9{SW[6]}}, SW[6:0]};

    // Input B: constant 16
    assign b = 16'd16;

    // ALU opcode = SW9..7 (3-bit → 8 functions)
    assign alu_op = (SW[9:7] == 3'b000) ? 5'd0   : // ADD
                    (SW[9:7] == 3'b001) ? 5'd8   : // SUB
                    (SW[9:7] == 3'b010) ? 5'd14  : // AND
                    (SW[9:7] == 3'b011) ? 5'd16  : // OR
                    (SW[9:7] == 3'b100) ? 5'd18  : // XOR
                    (SW[9:7] == 3'b101) ? 5'd20  : // NOT
                    (SW[9:7] == 3'b110) ? 5'd21  : // LSH
                    (SW[9:7] == 3'b111) ? 5'd23  : // RSH
                    5'd0;

    // =============================
    // ALU instance
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
    // Outputs
    // =============================

    // Flags on LEDR[4:0]
    assign LEDR[4:0] = flags_raw;

    // LEDR[9:5] unused
    assign LEDR[9:5] = 5'b0;

    // Display y on HEX0..HEX3
    hex7seg h0(.bin(y[3:0]),   .seg(HEX0));
    hex7seg h1(.bin(y[7:4]),   .seg(HEX1));
    hex7seg h2(.bin(y[11:8]),  .seg(HEX2));
    hex7seg h3(.bin(y[15:12]), .seg(HEX3));

endmodule


// =============================
// Seven-segment decoder
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
