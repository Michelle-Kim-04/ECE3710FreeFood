`timescale 1ns / 1ps
`default_nettype none

// Potentially Deprecated - do not use (for now)

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


// =======================================
// MUX A & B for ALU integration
// =======================================
module ALUMux16(

	 // NOTE ON RESERVED REGISTERS
    // CR16 reserves registers 13, 14, and 15 for PC, ISP, and INTBASE respectively
    // As such, I've disallowed using them in the MUXs for the ALU
	 
    input wire [15:0] r0,
    input wire [15:0] r1,
    input wire [15:0] r2,
    input wire [15:0] r3,
    input wire [15:0] r4,
    input wire [15:0] r5,
    input wire [15:0] r6,
    input wire [15:0] r7,
    input wire [15:0] r8,
    input wire [15:0] r9,
    input wire [15:0] r10,
    input wire [15:0] r11,
    input wire [15:0] r12,
    input wire [4:0]  select,
    input wire        clk,
    output reg [15:0] muxOut
);

    always @(posedge clk) begin
        case(select)
            5'd0:  muxOut <= r0;
            5'd1:  muxOut <= r1;
            5'd2:  muxOut <= r2;
            5'd3:  muxOut <= r3;
            5'd4:  muxOut <= r4;
            5'd5:  muxOut <= r5;
            5'd6:  muxOut <= r6;
            5'd7:  muxOut <= r7;
            5'd8:  muxOut <= r8;
            5'd9:  muxOut <= r9;
            5'd10: muxOut <= r10;
            5'd11: muxOut <= r11;
            5'd12: muxOut <= r12;              
        endcase
    end

endmodule

`default_nettype wire
