`timescale 1ns/1ps
`default_nettype none

module tb_fsm;

    // Testbench-driven signals
    reg        clk;
    reg        rst_n;
    reg [15:0] pc_in;
    reg [15:0] imem_dout;
    reg [15:0] dmem_dout;
    reg [15:0] rf_ra_data;
    reg [15:0] rf_rb_data;
    reg [15:0] alu_out;
    reg [4:0]  alu_flags;

    // FSM outputs
    wire        pc_en;
    wire [15:0] pc_next;
    wire        imem_en;
    wire [8:0]  imem_addr;
    wire        dmem_en;
    wire        dmem_we;
    wire [8:0]  dmem_addr;
    wire [15:0] dmem_din;
    wire        rf_we;
    wire [3:0]  rf_waddr;
    wire [15:0] rf_wdata;
    wire [3:0]  rf_ra_addr;
    wire [3:0]  rf_rb_addr;
    wire [4:0]  alu_op;
    wire [4:0]  alu_shamt;
    wire        alu_flags_en;
    wire [4:0]  alu_flags_sel;
    wire        alu_cin;
    wire [15:0] ir_out;

    // Instantiate FSM
    fsm uut (
        .clk(clk),
        .rst_n(rst_n),
        .pc_in(pc_in),
        .pc_en(pc_en),
        .pc_next(pc_next),
        .imem_dout(imem_dout),
        .imem_en(imem_en),
        .imem_addr(imem_addr),
        .dmem_en(dmem_en),
        .dmem_we(dmem_we),
        .dmem_addr(dmem_addr),
        .dmem_din(dmem_din),
        .dmem_dout(dmem_dout),
        .rf_we(rf_we),
        .rf_waddr(rf_waddr),
        .rf_wdata(rf_wdata),
        .rf_ra_addr(rf_ra_addr),
        .rf_ra_data(rf_ra_data),
        .rf_rb_addr(rf_rb_addr),
        .rf_rb_data(rf_rb_data),
        .alu_op(alu_op),
        .alu_shamt(alu_shamt),
        .alu_flags_en(alu_flags_en),
        .alu_flags_sel(alu_flags_sel),
        .alu_cin(alu_cin),
        .alu_out(alu_out),
        .alu_flags(alu_flags),
        .ir_out(ir_out)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n = 0;
        pc_in = 16'h0000;
        imem_dout = 16'h0000;
        dmem_dout = 16'h0000;
        rf_ra_data = 16'h0000;
        rf_rb_data = 16'h0000;
        alu_out = 16'h0000;
        alu_flags = 5'b00000;

        // Apply reset
        #10 rst_n = 1;

        // Test Register-to-Register ADD
        $display("[INFO] Testing ADD instruction...");
        imem_dout = 16'b0000_0001_0101_0010; // ADD R1, R2
        rf_ra_data = 16'h0003;
        rf_rb_data = 16'h0004;
        #20;
        if (rf_wdata !== 16'h0007) $display("[ERROR] ADD Test Failed");
        else $display("[PASS] ADD Test Passed");

        // Test Load Instruction
        $display("[INFO] Testing LOAD instruction...");
        imem_dout = 16'b0100_0010_0000_0000; // LOAD R2, [R0]
        rf_ra_data = 16'h0001;
        dmem_dout = 16'h00FF;
        #20;
        if (rf_wdata !== 16'h00FF) $display("[ERROR] LOAD Test Failed");
        else $display("[PASS] LOAD Test Passed");

        // Test Store Instruction
        $display("[INFO] Testing STORE instruction...");
        imem_dout = 16'b0100_0010_0100_0000; // STORE R2, [R0]
        rf_ra_data = 16'h0001;
        rf_rb_data = 16'h00AA;
        #20;
        if (dmem_din !== 16'h00AA) $display("[ERROR] STORE Test Failed");
        else $display("[PASS] STORE Test Passed");

        // Test Jump Instruction
        $display("[INFO] Testing JUMP instruction...");
        imem_dout = 16'b0100_0000_1000_0000; // JUMP R0
        rf_ra_data = 16'h0010;
        #20;
        if (pc_next !== 16'h0010) $display("[ERROR] JUMP Test Failed");
        else $display("[PASS] JUMP Test Passed");

        // Test Branch Instruction
        $display("[INFO] Testing BRANCH instruction...");
        imem_dout = 16'b1100_0000_0000_0100; // BEQ R0, +4
        alu_flags = 5'b00100; // Z flag set
        #20;
        if (pc_next !== 16'h0004) $display("[ERROR] BRANCH Test Failed");
        else $display("[PASS] BRANCH Test Passed");

        // End simulation
        $display("[INFO] Simulation complete.");
        $stop;
    end

endmodule

`default_nettype wire