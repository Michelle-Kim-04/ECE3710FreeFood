`timescale 1ns / 1ps
`default_nettype none

// =======================================
// 16x16 Register File
//  - 16 registers, each 16 bits wide
//  - 2 asynchronous read ports
//  - 1 synchronous write port
// =======================================
module regfile (
    input  wire        clk,       // clock
    input  wire        rst,       // synchronous reset (active high)
    input  wire        we,        // write enable
    input  wire [3:0]  w_addr,    // write address
    input  wire [15:0] w_data,    // data to write
    input  wire [3:0]  ra_addr,   // read address A
    input  wire [3:0]  rb_addr,   // read address B
    output wire [15:0] ra_data,   // read data A
    output wire [15:0] rb_data    // read data B
);

    // 16 registers, each 16-bit
    reg [15:0] regs [0:15];
    integer i;

    // synchronous write + reset
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 16'd0;
        end else if (we) begin
            regs[w_addr] <= w_data;
        end
    end

    // asynchronous read
    assign ra_data = regs[ra_addr];
    assign rb_data = regs[rb_addr];

endmodule

`default_nettype wire
