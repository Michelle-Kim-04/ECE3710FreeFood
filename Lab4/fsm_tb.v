`timescale 1ns/1ps
`default_nettype none

module fsm_tb;

    // Clock and reset
    reg clk;
    reg rst_n;

    // Inputs to FSM
    reg [15:0] instr_word;
    reg [15:0] pc;
    reg [15:0] alu_out;
    reg        alu_y_valid;

    // Outputs from FSM
    wire [15:0] pc_next;
    wire        pc_en;
    wire [3:0]  rdest_addr;
    wire [3:0]  rsrc_addr;
    wire        reg_we;
    wire [4:0]  alu_op_sel;
    wire [15:0] last_value;
    wire        ok_led;

    // Instantiate FSM
    fsm uut (
        .clk(clk),
        .rst_n(rst_n),
        .instr_word(instr_word),
        .pc(pc),
        .pc_next(pc_next),
        .pc_en(pc_en),
        .rdest_addr(rdest_addr),
        .rsrc_addr(rsrc_addr),
        .reg_we(reg_we),
        .alu_op_sel(alu_op_sel),
        .alu_out(alu_out),
        .alu_y_valid(alu_y_valid),
        .last_value(last_value),
        .ok_led(ok_led)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz clock

    // Test sequence
    initial begin
        // Initialize
        rst_n = 0;
        instr_word = 16'h0000;
        pc = 16'h0000;
        alu_out = 16'hABCD;
        alu_y_valid = 0;

        // Apply reset
        #20;
        rst_n = 1;

        // Provide instruction: ADD r1, r2
        // Format: [15:12 unused][11:8 rdest][7:4 subfunc][3:0 rsrc]
        instr_word = {4'b0000, 4'd1, 4'b0101, 4'd2}; // ADD r1, r2

        // Simulate pipeline stages
        #10; // FETCH
        #10; // DECODE
        alu_y_valid = 1;
        #10; // WRITEBACK

        // Provide another instruction: SUB r3, r4
        instr_word = {4'b0000, 4'd3, 4'b1001, 4'd4}; // SUB r3, r4
        alu_out = 16'h1234;
        alu_y_valid = 0;
        #10; // FETCH
        #10; // DECODE
        alu_y_valid = 1;
        #10; // WRITEBACK

        // Finish simulation
        #20;
        $stop;
    end

endmodule

`default_nettype wire