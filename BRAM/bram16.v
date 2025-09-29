`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// bram16.v : True Dual-Port BRAM (write-first, synchronous read)
// - 16-bit x 512 (ADDR_WIDTH = 9)
// - Force M10K and bind init.mif via attribute
// ============================================================================
module bram16 #(
    parameter ADDR_WIDTH = 9  // 2^9 = 512
)(
    input  wire                   clk,
    // Port A
    input  wire                   en_a,
    input  wire                   we_a,
    input  wire [ADDR_WIDTH-1:0]  addr_a,
    input  wire [15:0]            din_a,
    output reg  [15:0]            dout_a,
    // Port B
    input  wire                   en_b,
    input  wire                   we_b,
    input  wire [ADDR_WIDTH-1:0]  addr_b,
    input  wire [15:0]            din_b,
    output reg  [15:0]            dout_b
);
    localparam DEPTH = (1 << ADDR_WIDTH);

    // Map to M10K and preload from init.mif
    (* ramstyle = "M10K", ram_init_file = "init.mif" *)
    reg [15:0] mem [0:DEPTH-1];

    // Port A: write-first, synchronous read
    always @(posedge clk) begin
        if (en_a) begin
            if (we_a) begin
                mem[addr_a] <= din_a;
                dout_a      <= din_a;       // write-first behavior
            end else begin
                dout_a      <= mem[addr_a];
            end
        end
    end

    // Port B: write-first, synchronous read
    always @(posedge clk) begin
        if (en_b) begin
            if (we_b) begin
                mem[addr_b] <= din_b;
                dout_b      <= din_b;       // write-first behavior
            end else begin
                dout_b      <= mem[addr_b];
            end
        end
    end
endmodule

`default_nettype wire
