`timescale 1ns/1ps
`default_nettype none
// Test bench

module tb_fsm;

    // Testbench-driven signals
    reg        CLOCK_50;
    reg [3:0]  KEY;
    wire [6:0] HEX0, HEX1, HEX2, HEX3;
    wire [9:0] LEDR;

    // ------------------------------------------------------------------------
    // Reset and Display Mode
    // ------------------------------------------------------------------------
    wire rst_n    = KEY[0];      // KEY0 active-low reset
    wire show_mem = ~KEY[1];     // KEY1 = show memory
    wire rst_sync = ~rst_n;      // regfile has active-high reset

    // ------------------------------------------------------------------------
    // Slow clock (~6 Hz)
    // ------------------------------------------------------------------------
    reg [23:0] div;
    always @(posedge CLOCK_50) div <= div + 1;
    wire slow_clk = div[22];

    // CLOCK_50 generator for simulation
    initial begin
        CLOCK_50 = 1'b0;
    end
    always #10 CLOCK_50 = ~CLOCK_50; // 50 MHz -> period 20ns

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
    // Unified Dual-Port BRAM (Instruction + Data)
    // ------------------------------------------------------------------------
    wire [15:0] imem_dout, dmem_dout, dmem_din;
    wire [8:0]  imem_addr, dmem_addr;
    wire        dmem_en, dmem_we;

    bram16 #(.ADDR_WIDTH(9)) U_BRAM (
        .clk(slow_clk),

        // IMEM (port A)
        .en_a(1'b1),
        .we_a(1'b0),
        .addr_a(imem_addr),
        .din_a(16'h0000),
        .dout_a(imem_dout),

        // DMEM (port B)
        .en_b(dmem_en),
        .we_b(dmem_we),
        .addr_b(dmem_addr),
        .din_b(dmem_din),
        .dout_b(dmem_dout)
    );

    // ------------------------------------------------------------------------
    // Register File
    // ------------------------------------------------------------------------
    wire        rf_we;
    wire [3:0]  rf_waddr, rf_ra_addr, rf_rb_addr;
    wire [15:0] rf_wdata, rf_ra_data, rf_rb_data;

    regfile U_REG (
        .clk(slow_clk),
        .rst(rst_sync),
        .we(rf_we),
        .w_addr(rf_waddr),
        .w_data(rf_wdata),
        .ra_addr(rf_ra_addr),
        .rb_addr(rf_rb_addr),
        .ra_data(rf_ra_data),
        .rb_data(rf_rb_data)
    );

    // ------------------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------------------
    wire [4:0] alu_op, alu_shamt, alu_flags_sel;
    wire       alu_flags_en, alu_cin;
    wire [15:0] alu_out;
    wire [4:0]  alu_flags;

    alu16 U_ALU (
        .a(rf_ra_data),
        .b(rf_rb_data),
        .alu_op(alu_op),
        .shamt(alu_shamt),
        .psr_c_in(alu_cin),

        .flags_en(alu_flags_en),
        .flags_sel(alu_flags_sel),
        .flags_out(alu_flags),
        .flags_raw(),

        .y(alu_out),
        .y_valid()
    );

    // ------------------------------------------------------------------------
    // FSM (Stage-3)
    // ------------------------------------------------------------------------
    wire [15:0] instr_word;

    fsm uut (
        .clk(slow_clk),
        .rst_n(rst_n),

        // PC
        .pc_in(pc),
        .pc_en(pc_en),
        .pc_next(pc_next),

        // IMEM
        .imem_dout(imem_dout),
        .imem_en(),
        .imem_addr(imem_addr),

        // DMEM
        .dmem_en(dmem_en),
        .dmem_we(dmem_we),
        .dmem_addr(dmem_addr),
        .dmem_din(dmem_din),
        .dmem_dout(dmem_dout),

        // Register File
        .rf_we(rf_we),
        .rf_waddr(rf_waddr),
        .rf_wdata(rf_wdata),
        .rf_ra_addr(rf_ra_addr),
        .rf_ra_data(rf_ra_data),
        .rf_rb_addr(rf_rb_addr),
        .rf_rb_data(rf_rb_data),

        // ALU
        .alu_op(alu_op),
        .alu_shamt(alu_shamt),
        .alu_flags_en(alu_flags_en),
        .alu_flags_sel(alu_flags_sel),
        .alu_cin(alu_cin),
        .alu_out(alu_out),
        .alu_flags(alu_flags),

        // Debug
        .ir_out(instr_word)
    );
	 
	// ------------------------------------------------------------------------
    // Test procedure 
    // - preload BRAM data via hierarchical access
    // - load mem -> regfile, perform ALU ops, store/reload, compare, branch
    // ------------------------------------------------------------------------
    initial begin
        // initialize
        KEY = 4'b1111;
        // apply reset (KEY[0] active-low)
        KEY[0] = 1'b0; KEY[1] = 1'b1; // assert reset
        #100;
        KEY[0] = 1'b1; // release reset
        #100;

        $display("--- Starting FSM test sequence ---");

        // Preload some data in data memory (hierarchical access to U_BRAM.mem)
        U_BRAM.mem[9'd100] = 16'd5;   // data A
        U_BRAM.mem[9'd101] = 16'd7;   // data B
        $display("Preloaded Mem[100]=%0d Mem[101]=%0d", U_BRAM.mem[100], U_BRAM.mem[101]);

        // Wait a couple slow clock cycles so everything is stable
        repeat (3) @(posedge slow_clk);

        // 1) Load data from memory into the regfile (simulate a LOAD sequence)
        U_REG.regs[4'd1] = U_BRAM.mem[9'd100];
        U_REG.regs[4'd2] = U_BRAM.mem[9'd101];
        $display("Loaded R1=%0d R2=%0d", U_REG.regs[1], U_REG.regs[2]);
        @(posedge slow_clk);

        // 2) Perform arithmetic: R3 = R1 + R2 (set flags implicitly by computing)
        U_REG.regs[4'd3] = U_REG.regs[4'd1] + U_REG.regs[4'd2];
        $display("Computed R3 = R1 + R2 = %0d", U_REG.regs[3]);
        @(posedge slow_clk);

        // 3) Store the result in memory: Mem[200] = R3
        U_BRAM.mem[9'd200] = U_REG.regs[4'd3];
        $display("Stored Mem[200]=%0d", U_BRAM.mem[200]);
        @(posedge slow_clk);

        // 4) Reload the result from memory into R4
        U_REG.regs[4'd4] = U_BRAM.mem[9'd200];
        $display("Reloaded R4 = %0d", U_REG.regs[4]);
        @(posedge slow_clk);

        // 5) Perform arithmetic to set flags: compare R4 with immediate 12
        integer signed_diff;
        reg z_flag;
        signed_diff = $signed(U_REG.regs[4]) - $signed(16'd12);
        z_flag = (signed_diff == 0);
        $display("Compare R4(%0d) - 12 = %0d  Z=%b", U_REG.regs[4], signed_diff, z_flag);
        @(posedge slow_clk);

        // 6) Use flags to do a branch: if equal (Z==1) then write R4 into Mem[201]
        if (z_flag) begin
            U_BRAM.mem[9'd201] = U_REG.regs[4'd4];
            $display("Branch taken: wrote Mem[201]=%0d", U_BRAM.mem[201]);
        end else begin
            $display("Branch not taken: Mem[201] unchanged (was %0d)", U_BRAM.mem[201]);
        end

        @(posedge slow_clk);

        // 7) Final write verification
        $display("Final: Mem[200]=%0d Mem[201]=%0d", U_BRAM.mem[200], U_BRAM.mem[201]);

        $display("--- Test sequence complete ---");
        #1000 $stop;
    end
	 
	 
	 
	 
	 
	 

endmodule

`default_nettype wire