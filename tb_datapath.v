`timescale 1ns/1ps
`default_nettype none

module tb_datapath;

    // Test signals
    reg         clk;
    reg         rst;
    reg         we;
    reg  [3:0]  w_addr, ra_addr, rb_addr;
    reg  [4:0]  alu_op;
    wire [15:0] alu_y;
    wire [4:0]  flags;

    wire [15:0] ra_data, rb_data;

    // Instantiate regfile
    regfile RF (
        .clk(clk), .rst(rst), .we(we),
        .w_addr(w_addr), .w_data(alu_y),  // feedback from ALU
        .ra_addr(ra_addr), .rb_addr(rb_addr),
        .ra_data(ra_data), .rb_data(rb_data)
    );

    // Instantiate ALU
    alu16 ALU (
        .a(ra_data), .b(rb_data), .alu_op(alu_op),
        .shamt(5'd1), .psr_c_in(1'b0),
        .flags_en(1'b1), .flags_sel(5'b11111),
        .flags_out(flags), .flags_raw(),
        .y(alu_y), .y_valid()
    );

    // Clock generator
    always #5 clk = ~clk;

    // Test procedure
    initial begin
        clk = 0; rst = 1; we = 0;
        w_addr = 4'd0; ra_addr = 4'd0; rb_addr = 4'd0; alu_op = 5'd0;

        #10 rst = 0; // release reset

        // Step 1: write 5 into R1
        we = 1; w_addr = 4'd1; alu_op = 5'd0;  // alu_op=ADD
        #10;

        // Step 2: write 3 into R2
        w_addr = 4'd2;
        #10;

        we = 0;

        // Step 3: read R1 and R2, do ADD
        ra_addr = 4'd1; rb_addr = 4'd2; alu_op = 5'd0; // ADD
        #10;

        // Step 4: do SUB
        alu_op = 5'd1;
        #10;

        // stop simulation
        #50 $stop;
    end

endmodule
