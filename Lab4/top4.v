`timescale 1ns/1ps
`default_nettype none
// ============================================================================
// top4.v : Lab4 Stage-2 Top-Level CPU
// ----------------------------------------------------------------------------
// • Uses dual-port BRAM for unified instruction/data memory
// • HEX0–3 display current executing instruction
// • LEDR[0] = Register write enable indicator
// • LEDR[9] = Heartbeat, LEDR[8:1] = PC low bits
// ============================================================================

module top4 (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    output wire [6:0]  HEX0, HEX1, HEX2, HEX3,
    output wire [9:0]  LEDR
);
    // ------------------------------------------------------------------------
    // Reset and Clock Divider
    // ------------------------------------------------------------------------
    wire rst_n = KEY[0];
    wire rst_sync = ~rst_n;

    // Slow clock (~6 Hz for visible behavior)
    reg [23:0] div;
    always @(posedge CLOCK_50) div <= div + 1;
    wire slow_clk = div[22];

    // ------------------------------------------------------------------------
    // Program Counter
    // ------------------------------------------------------------------------
    wire [15:0] pc, pc_next;
    wire pc_en;

    pc_unit U_PC (
        .clk(slow_clk),
        .rst_n(rst_n),
        .pc_en(pc_en),
        .pc_next(pc_next),
        .pc(pc)
    );

    // ------------------------------------------------------------------------
    // Dual-Port BRAM (Instruction + Data)
    // ------------------------------------------------------------------------
    wire [15:0] imem_dout, dmem_dout, dmem_din;
    wire [8:0]  imem_addr, dmem_addr;
    wire        dmem_en, dmem_we;

    bram16 #(.ADDR_WIDTH(9)) U_BRAM (
        .clk(slow_clk),
        // Port A: instruction memory
        .en_a(1'b1), .we_a(1'b0),
        .addr_a(imem_addr),
        .din_a(16'h0000),
        .dout_a(imem_dout),
        // Port B: data memory
        .en_b(dmem_en), .we_b(dmem_we),
        .addr_b(dmem_addr),
        .din_b(dmem_din),
        .dout_b(dmem_dout)
    );

    // ------------------------------------------------------------------------
    // Register File
    // ------------------------------------------------------------------------
    wire rf_we;
    wire [3:0] rf_waddr, rf_ra_addr, rf_rb_addr;
    wire [15:0] rf_wdata, rf_ra_data, rf_rb_data;

    regfile U_REG (
        .clk(slow_clk),
        .rst(rst_sync),
        .we(rf_we),
        .w_addr(rf_waddr), .w_data(rf_wdata),
        .ra_addr(rf_ra_addr), .rb_addr(rf_rb_addr),
        .ra_data(rf_ra_data), .rb_data(rf_rb_data)
    );

    // ------------------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------------------
    wire [4:0] alu_op, alu_shamt, alu_flags_sel;
    wire alu_flags_en, alu_cin;
    wire [15:0] alu_out;

    alu16 U_ALU (
        .a(rf_ra_data),
        .b(rf_rb_data),
        .alu_op(alu_op),
        .shamt(alu_shamt),
        .psr_c_in(alu_cin),
        .flags_en(alu_flags_en),
        .flags_sel(alu_flags_sel),
        .flags_out(),
        .flags_raw(),
        .y(alu_out),
        .y_valid()
    );

    // ------------------------------------------------------------------------
    // FSM Controller
    // ------------------------------------------------------------------------
    wire [15:0] instr_word;

    fsm U_FSM (
        .clk(slow_clk),
        .rst_n(rst_n),

        // PC
        .pc_in(pc), .pc_en(pc_en), .pc_next(pc_next),

        // Instruction memory
        .imem_dout(imem_dout),
        .imem_en(), .imem_addr(imem_addr),

        // Data memory
        .dmem_en(dmem_en), .dmem_we(dmem_we),
        .dmem_addr(dmem_addr), .dmem_din(dmem_din), .dmem_dout(dmem_dout),

        // Register file
        .rf_we(rf_we), .rf_waddr(rf_waddr), .rf_wdata(rf_wdata),
        .rf_ra_addr(rf_ra_addr), .rf_ra_data(rf_ra_data),
        .rf_rb_addr(rf_rb_addr), .rf_rb_data(rf_rb_data),

        // ALU
        .alu_op(alu_op), .alu_shamt(alu_shamt),
        .alu_flags_en(alu_flags_en), .alu_flags_sel(alu_flags_sel),
        .alu_cin(alu_cin), .alu_out(alu_out),

        // Debug output
        .ir_out(instr_word)
    );

    // ------------------------------------------------------------------------
    // Display and LEDs
    // ------------------------------------------------------------------------
    // HEX shows currently executing instruction
    sevenseg h0(.bin(instr_word[3:0]),   .seg(HEX0));
    sevenseg h1(.bin(instr_word[7:4]),   .seg(HEX1));
    sevenseg h2(.bin(instr_word[11:8]),  .seg(HEX2));
    sevenseg h3(.bin(instr_word[15:12]), .seg(HEX3));

    assign LEDR[8:1] = pc[7:0];  // PC low bits
    assign LEDR[9]   = div[23];  // heartbeat
    assign LEDR[0]   = rf_we;    // write-back indicator
endmodule

`default_nettype wire
