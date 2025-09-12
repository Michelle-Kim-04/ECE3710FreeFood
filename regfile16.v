
`timescale 1ns / 1ps

module register16(writeInput, wEnable, reset, clk, regValue);

    // input values
    input[15:0] writeInput;

    // input for enable, reset, and clock
    input wenable, reset, clk;

    // output (register value)
    output reg[15:0] regValue;

    // on clock positive edge
    always @(posedge clk) 
    begin

        // Assign registor value based on input, reset = 0, wEnable = dInput, otherwise it remains the same
        if (reset) regValue <= 0;
        else 
            begin
                if (wEnable) regValue = writeInput;
                else regValue = regValue;
            end
    end

endmodule;

module registerBank16(r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15, clk, reset, rEnable, writePort);

    // inputs for clk & reset
    input clk,reset;

    //input for rEnable, and writeport
    input [15:0] rEnable, writePort;

    //output registers
    output [15:0] r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15;

    //implement registers
    register16 instance0(
        .writeInput(writePort),
        .wEnable(rEnable[0]),
        .reset(reset),
        .clk(clk),
        .regValue(r0)
    );
    register16 instance1(writePort, rEnable[1], reset, clk, r1);
    register16 instance2(writePort, rEnable[2], reset, clk, r1);
    register16 instance3(writePort, rEnable[3], reset, clk, r1);
    register16 instance4(writePort, rEnable[4], reset, clk, r1);
    register16 instance5(writePort, rEnable[5], reset, clk, r1);
    register16 instance6(writePort, rEnable[6], reset, clk, r1);
    register16 instance7(writePort, rEnable[7], reset, clk, r1);
    register16 instance8(writePort, rEnable[8], reset, clk, r1);
    register16 instance9(writePort, rEnable[9], reset, clk, r1);
    register16 instance10(writePort, rEnable[10], reset, clk, r1);
    register16 instance11(writePort, rEnable[11], reset, clk, r1);
    register16 instance12(writePort, rEnable[12], reset, clk, r1);
    register16 instance13(writePort, rEnable[13], reset, clk, r1);
    register16 instance14(writePort, rEnable[14], reset, clk, r1);
    register16 instance15(writePort, rEnable[15], reset, clk, r1);

endmodule;

// TODO: module ALUMUXs(writePort, muxA, muxB, regbank);

