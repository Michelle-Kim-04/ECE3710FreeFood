`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// pc_unit.v : Program Counter (16-bit)
// - Holds current instruction address
// - Increments when pc_en=1
// - Reset to 0 when rst_n=0
// ============================================================================

module pc_unit (
    input  wire        clk,      // clock (slow clock from divider)
    input  wire        rst_n,    // active-low reset (KEY0)
    input  wire        pc_en,    // enable update (FSM controlled)
    input  wire [15:0] pc_next,  // next PC value (usually pc + 1)
    output reg  [15:0] pc        // current PC output
);
    wire rst = ~rst_n;

    always @(posedge clk) begin
        if (rst)
            pc <= 16'd0;        // reset to 0
        else if (pc_en)
            pc <= pc_next;      // update when enabled
        else
            pc <= pc;           // hold value
    end
endmodule

`default_nettype wire
