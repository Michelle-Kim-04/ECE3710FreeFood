`timescale 1ns / 1ps
`default_nettype none

// =======================================
// 16-bit Register
// =======================================
module register16 (
    input  wire [15:0] writeInput,
    input  wire        wenable,
    input  wire        reset,
    input  wire        clk,
    output reg  [15:0] regValue
);

    always @(posedge clk) begin
        if (reset) 
            regValue <= 16'b0;         // reset → 0
        else if (wenable) 
            regValue <= writeInput;    // write enable → update
    end

endmodule


// =======================================
// Register Bank with 16 registers
// =======================================
module registerBank16 (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] rEnable,   // one-hot write enables for each register
    input  wire [15:0] writePort, // data to write into selected register

    output wire [15:0] r0,
    output wire [15:0] r1,
    output wire [15:0] r2,
    output wire [15:0] r3,
    output wire [15:0] r4,
    output wire [15:0] r5,
    output wire [15:0] r6,
    output wire [15:0] r7,
    output wire [15:0] r8,
    output wire [15:0] r9,
    output wire [15:0] r10,
    output wire [15:0] r11,
    output wire [15:0] r12,
    output wire [15:0] r13,
    output wire [15:0] r14,
    output wire [15:0] r15
);

    register16 instance0  (writePort, rEnable[0],  reset, clk, r0);
    register16 instance1  (writePort, rEnable[1],  reset, clk, r1);
    register16 instance2  (writePort, rEnable[2],  reset, clk, r2);
    register16 instance3  (writePort, rEnable[3],  reset, clk, r3);
    register16 instance4  (writePort, rEnable[4],  reset, clk, r4);
    register16 instance5  (writePort, rEnable[5],  reset, clk, r5);
    register16 instance6  (writePort, rEnable[6],  reset, clk, r6);
    register16 instance7  (writePort, rEnable[7],  reset, clk, r7);
    register16 instance8  (writePort, rEnable[8],  reset, clk, r8);
    register16 instance9  (writePort, rEnable[9],  reset, clk, r9);
    register16 instance10 (writePort, rEnable[10], reset, clk, r10);
    register16 instance11 (writePort, rEnable[11], reset, clk, r11);
    register16 instance12 (writePort, rEnable[12], reset, clk, r12);
    register16 instance13 (writePort, rEnable[13], reset, clk, r13);
    register16 instance14 (writePort, rEnable[14], reset, clk, r14);
    register16 instance15 (writePort, rEnable[15], reset, clk, r15);

endmodule

`default_nettype wire
