`timescale 1ns/1ps
`default_nettype none

// top4.v : Lab4 Stage1 Top-Level CPU
//  HEX0–3 show R1 value；LEDR[0] flash；LEDR[8:1] show PC low level

module top4 (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3,
    output wire [9:0]  LEDR
);
    wire rst_n = KEY[0];
    wire rst_sync = ~rst_n;  // regfile active-high reset

    // --- slow clock (~6 Hz) ---
    reg [23:0] div;
    always @(posedge CLOCK_50) div <= div + 1;
    wire slow_clk = div[22];

    // --- PC ---
    wire [15:0] pc, pc_next;
    wire pc_en;
    pc_unit U_PC (.clk(slow_clk), .rst_n(rst_n), .pc_en(pc_en),
                  .pc_next(pc_next), .pc(pc));

    // --- Instruction Memory ---
    wire [15:0] instr_word;
    bram16 #(.ADDR_WIDTH(9)) U_BRAM (
        .clk(slow_clk),
        .en_a(1'b1), .we_a(1'b0), .addr_a(pc[8:0]),
        .din_a(16'h0000), .dout_a(instr_word),
        .en_b(1'b0), .we_b(1'b0), .addr_b(9'd0),
        .din_b(16'h0000), .dout_b()
    );

    // --- Register File ---
    wire [3:0] rdest_addr, rsrc_addr;
    wire [15:0] rdest_val, rsrc_val, alu_out;
    wire reg_we, alu_y_valid;
    regfile U_REG (.clk(slow_clk), .rst(rst_sync),
                   .we(reg_we), .w_addr(rdest_addr), .w_data(alu_out),
                   .ra_addr(rdest_addr), .rb_addr(rsrc_addr),
                   .ra_data(rdest_val), .rb_data(rsrc_val));

    // --- ALU ---
    wire [4:0] alu_op_sel;
    alu16 U_ALU (.a(rdest_val), .b(rsrc_val),
                 .alu_op(alu_op_sel), .shamt(5'd1),
                 .psr_c_in(1'b0), .flags_en(1'b0), .flags_sel(5'd0),
                 .flags_out(), .flags_raw(),
                 .y(alu_out), .y_valid(alu_y_valid));

    // --- FSM ---
    wire [15:0] last_value; wire ok_led;
    fsm U_FSM (.clk(slow_clk), .rst_n(rst_n),
               .instr_word(instr_word),
               .pc(pc), .pc_next(pc_next), .pc_en(pc_en),
               .rdest_addr(rdest_addr), .rsrc_addr(rsrc_addr),
               .reg_we(reg_we), .alu_op_sel(alu_op_sel),
               .alu_out(alu_out), .alu_y_valid(alu_y_valid),
               .last_value(last_value), .ok_led(ok_led));

    // --- Display ---
    sevenseg h0(.bin(last_value[3:0]),  .seg(HEX0));
    sevenseg h1(.bin(last_value[7:4]),  .seg(HEX1));
    sevenseg h2(.bin(last_value[11:8]), .seg(HEX2));
    sevenseg h3(.bin(last_value[15:12]),.seg(HEX3));

    assign LEDR[0]   = ok_led;
    assign LEDR[8:1] = pc[7:0];
    assign LEDR[9]   = 1'b0;
endmodule

`default_nettype wire
