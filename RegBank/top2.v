`timescale 1ns/1ps
`default_nettype none

// =======================================
// Top-level module for FPGA demo
// Fibonacci generator using FSM + regfile + ALU
// =======================================
module top2 (
    input  wire        CLOCK_50,   // FPGA 50 MHz clock
    input  wire [1:0]  KEY,        // KEY0: reset (active low)
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [9:0]  LEDR        // debug flags
);

    // ================================
    // Reset & clock divider
    // ================================
    wire rst_n = KEY[0];   // active low reset
    wire rst   = ~rst_n;

    // Slow clock divider (~6 Hz for visible updates)
    reg [23:0] div;
    always @(posedge CLOCK_50 or posedge rst) begin
        if (rst) div <= 24'd0;
        else     div <= div + 1'b1;
    end
    wire slow_clk = div[23];

    // ================================
    // Control signals from FSM
    // ================================
    wire [3:0] ra_addr, rb_addr, w_addr;
    wire       we;
    wire [4:0] alu_op;
    wire       use_const;

    // ================================
    // Datapath wiring
    // ================================
    wire [15:0] ra_data, rb_data, alu_y;
    wire [4:0]  flags;

    // Constant "1" for initialization
    wire [15:0] const_one = 16'd1;
    wire [15:0] alu_input_b = (use_const) ? const_one : rb_data;

    // Register file (2-read, 1-write)
    regfile RF (
        .clk(slow_clk), .rst(rst), .we(we),
        .w_addr(w_addr), .w_data(alu_y),
        .ra_addr(ra_addr), .rb_addr(rb_addr),
        .ra_data(ra_data), .rb_data(rb_data)
    );

    // ALU instance
    alu16 ALU (
        .a(ra_data), .b(alu_input_b), .alu_op(alu_op),
        .shamt(5'd1), .psr_c_in(1'b0),
        .flags_en(1'b1), .flags_sel(5'b11111),
        .flags_out(flags), .flags_raw(),
        .y(alu_y), .y_valid()
    );

    // FSM controller (Fibonacci generator)
    fsm_controller FSM (
        .clk(slow_clk),
        .rst(rst),
        .ra_addr(ra_addr),
        .rb_addr(rb_addr),
        .w_addr(w_addr),
        .we(we),
        .alu_op(alu_op),
        .use_const(use_const)
    );

    // ================================
    // Output display
    // ================================
    // FSM keeps R2 updated → rb_data shows it when rb_addr=2
    wire [15:0] fib_value = rb_data;

    hex7seg h0(.bin(fib_value[3:0]),   .seg(HEX0));
    hex7seg h1(.bin(fib_value[7:4]),   .seg(HEX1));
    hex7seg h2(.bin(fib_value[11:8]),  .seg(HEX2));
    hex7seg h3(.bin(fib_value[15:12]), .seg(HEX3));

    // Debug: flags on LEDR[4:0]
    assign LEDR[4:0] = flags;
    assign LEDR[9:5] = 5'b0;

endmodule


// =======================================
// FSM: Fibonacci sequence generator (ADD-only)
// =======================================
module fsm_controller (
    input  wire       clk,
    input  wire       rst,
    output reg  [3:0] ra_addr,
    output reg  [3:0] rb_addr,
    output reg  [3:0] w_addr,
    output reg        we,
    output reg  [4:0] alu_op,
    output reg        use_const   // select constant "1" at init
);

    // State encoding
    parameter S_INIT1  = 3'd0;
    parameter S_INIT2  = 3'd1;
    parameter S_ADD    = 3'd2;
    parameter S_SHIFT1 = 3'd3;
    parameter S_SHIFT2 = 3'd4;

    reg [2:0] state, next_state;

    // Sequential: update state
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= S_INIT1;
        else
            state <= next_state;
    end

    // Combinational: FSM outputs
    always @(*) begin
        // Default values
        ra_addr   = 4'd0;
        rb_addr   = 4'd0;
        w_addr    = 4'd0;
        we        = 1'b0;
        alu_op    = 5'd0;  // ADD
        use_const = 1'b0;
        next_state = state;

        case (state)
            // Step 1: Initialize R1 = 0
            S_INIT1: begin
                ra_addr = 4'd0;
                rb_addr = 4'd0;
                alu_op  = 5'd0;  // ADD
                w_addr  = 4'd1;
                we      = 1'b1;
                next_state = S_INIT2;
            end

            // Step 2: Initialize R2 = 1 (use constant)
            S_INIT2: begin
                ra_addr   = 4'd0;
                rb_addr   = 4'd0; // ignored, replaced by const
                alu_op    = 5'd0; // ADD
                w_addr    = 4'd2;
                we        = 1'b1;
                use_const = 1'b1; // inject constant=1
                next_state = S_ADD;
            end

            // Step 3: Compute R3 = R1 + R2
            S_ADD: begin
                ra_addr = 4'd1;
                rb_addr = 4'd2;
                alu_op  = 5'd0;  // ADD
                w_addr  = 4'd3;
                we      = 1'b1;
                next_state = S_SHIFT1;
            end

            // Step 4: Copy R1 = R2
            S_SHIFT1: begin
                ra_addr = 4'd2;
                rb_addr = 4'd0;  // add zero
                alu_op  = 5'd0;  // ADD
                w_addr  = 4'd1;
                we      = 1'b1;
                next_state = S_SHIFT2;
            end

            // Step 5: Copy R2 = R3
            S_SHIFT2: begin
                ra_addr = 4'd3;
                rb_addr = 4'd0;  // add zero
                alu_op  = 5'd0;  // ADD
                w_addr  = 4'd2;
                we      = 1'b1;
                next_state = S_ADD;
            end
        endcase
    end

endmodule


// =======================================
// Seven-segment decoder
// =======================================
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

