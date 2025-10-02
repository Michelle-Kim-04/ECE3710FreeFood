`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// top3.v : Lab3 Top-Level (with slow clock divider for human-visible updates)
// - KEY0 : reset_n (active-low)
// - BRAM + FSM run on a slowed clock
// - HEX0..3 show last_value; LEDR[0] = ok_led; LEDR[8:1] = dout_b[7:0]
// ============================================================================
module top3 (
    input  wire        CLOCK_50,      // 50 MHz
    input  wire [3:0]  KEY,           // KEY[0] = reset_n (active-low)
    output wire [6:0]  HEX0,
    output wire [6:0]  HEX1,
    output wire [6:0]  HEX2,
    output wire [6:0]  HEX3,
    output wire [9:0]  LEDR
);
    wire rst_n = KEY[0];

    // Slow clock divider (~6 Hz @ div[22])
    reg [23:0] div;
    always @(posedge CLOCK_50) div <= div + 24'd1;
    wire slow_clk = div[22];   // change to [23] for ~3 Hz, [21] for ~12 Hz

    // BRAM/FSM wiring
    wire        en_a, we_a, en_b, we_b;
    wire [8:0]  addr_a, addr_b;   // 9-bit for 512-depth
    wire [15:0] din_a,  din_b;
    wire [15:0] dout_a, dout_b;

    wire [15:0] last_value;
    wire        ok_led;

    // FSM on slow clock
    fsm U_FSM (
        .clk        (slow_clk),
        .rst_n      (rst_n),
        // Port A
        .en_a(en_a), .we_a(we_a), .addr_a(addr_a), .din_a(din_a), .dout_a(dout_a),
        // Port B
        .en_b(en_b), .we_b(we_b), .addr_b(addr_b), .din_b(din_b), .dout_b(dout_b),
        // Status
        .last_value (last_value),
        .ok_led     (ok_led)
    );

    // 16-bit x 512 true dual-port BRAM
    bram16 #(.ADDR_WIDTH(9)) U_BRAM (
        .clk    (slow_clk),
        // Port A
        .en_a(en_a), .we_a(we_a), .addr_a(addr_a), .din_a(din_a), .dout_a(dout_a),
        // Port B
        .en_b(en_b), .we_b(we_b), .addr_b(addr_b), .din_b(din_b), .dout_b(dout_b)
    );

    // Display last_value on 7-seg
    sevenseg h0 (.bin(last_value[3:0]),    .seg(HEX0));
    sevenseg h1 (.bin(last_value[7:4]),    .seg(HEX1));
    sevenseg h2 (.bin(last_value[11:8]),   .seg(HEX2));
    sevenseg h3 (.bin(last_value[15:12]),  .seg(HEX3));

    // LEDs: show pass flag and mirror DOUT low-byte
    assign LEDR[0]   = ok_led;         // lights when readback == expected
    assign LEDR[8:1] = dout_b[7:0];    // mirror DOUT to LEDs (per handout spirit)
    assign LEDR[9]   = 1'b0;

endmodule

`default_nettype wire
