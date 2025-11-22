`timescale 1ns/1ps
`default_nettype none

module fsm_tb;

    // Clock and reset
    reg clk;
    reg rst_n;

    // Program Counter
    reg  [15:0] pc_in;
    wire        pc_en;
    wire [15:0] pc_next;

    // Instruction Memory
    reg  [15:0] imem_dout;
    wire        imem_en;
    wire [8:0]  imem_addr;

    // Data Memory
    wire        dmem_en;
    wire        dmem_we;
    wire [8:0]  dmem_addr;
    wire [15:0] dmem_din;
    reg  [15:0] dmem_dout;

    // Register File
    wire        rf_we;
    wire [3:0]  rf_waddr;
    wire [15:0] rf_wdata;
    wire [3:0]  rf_ra_addr;
    reg  [15:0] rf_ra_data;
    wire [3:0]  rf_rb_addr;
    reg  [15:0] rf_rb_data;

    // ALU
    wire [4:0]  alu_op;
    wire [4:0]  alu_shamt;
    wire        alu_flags_en;
    wire [4:0]  alu_flags_sel;
    wire        alu_cin;
    reg  [15:0] alu_out;

    // Debug
    wire [15:0] ir_out;

    // Instantiate DUT
    fsm dut (
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
        .ir_out(ir_out)
    );

    // Clock generation
    always #5 clk = ~clk;

    // Simple ALU model
    always @(*) begin
        case (alu_op)
            5'd0: alu_out = rf_ra_data + rf_rb_data; // ADD
            5'd8: alu_out = rf_rb_data - rf_ra_data; // SUB
            default: alu_out = 16'h0000;             // NOP
        endcase
    end

    // Stimulus
    initial begin

        clk   = 0;
        rst_n = 0;
        pc_in = 0;
        imem_dout = 0;
        dmem_dout = 16'hAAAA;
        rf_ra_data = 16'h0003;
        rf_rb_data = 16'h0005;

        #12 rst_n = 1;

        // --- MOVI R1, #5 ---
        imem_dout = 16'b0101_0001_0000_0101; // opcode=0101, rdest=1, imm=5
        #40;

        // --- ADD R2, R1+R0 ---
        imem_dout = 16'b0000_0010_0101_0001; // opcode=0000, rdest=2, subfunc=0101 (ADD), rsrc=1
        #40;

        // --- SUB R3, R2-R1 ---
        imem_dout = 16'b0000_0011_1001_0010; // opcode=0000, rdest=3, subfunc=1001 (SUB), rsrc=2
        #40;

        // --- LOAD R4, R1 ---
        imem_dout = 16'b0100_0100_0000_0001; // opcode=0100, rdest=4, subfunc=0000 (LOAD), rsrc=1
        #40;

        // --- STORE R1, R4 ---
        imem_dout = 16'b0100_0001_0100_0100; // opcode=0100, rsrc=1, rdest=4, subfunc=0100 (STORE)
        #40;

        // --- NOP ---
        imem_dout = 16'hFFFF; // default case
        #40;

        $finish;
    end

endmodule

`default_nettype wire
