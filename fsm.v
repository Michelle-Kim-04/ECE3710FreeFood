`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// fsm.v : Read-Modify-Write-Readback FSM (robust timing, Verilog-2001)
// - A-port read holds 2 cycles; B-port readback waits 2 cycles
// - Walk addresses: 0,1,2,508,509,510,511 (for 512-depth RAM)
// ============================================================================
module fsm (
    input  wire        clk,
    input  wire        rst_n,

    // BRAM Port A
    output reg         en_a,
    output reg         we_a,
    output reg  [8:0]  addr_a,   // 9-bit for 512-depth
    output reg  [15:0] din_a,
    input  wire [15:0] dout_a,

    // BRAM Port B
    output reg         en_b,
    output reg         we_b,
    output reg  [8:0]  addr_b,   // 9-bit for 512-depth
    output reg  [15:0] din_b,
    input  wire [15:0] dout_b,

    // Status
    output reg  [15:0] last_value,
    output reg         ok_led
);
    // Address list (≤ 511)
    localparam integer N = 7;
    reg [8:0] addr_list [0:N-1];
    initial begin
        addr_list[0]=9'd0;   addr_list[1]=9'd1;   addr_list[2]=9'd2;
        addr_list[3]=9'd508; addr_list[4]=9'd509; addr_list[5]=9'd510; addr_list[6]=9'd511;
    end

    // States
    localparam [3:0]
        S_IDLE   = 4'd0,
        S_READ1  = 4'd1,  // assert en_a, set addr
        S_READ2  = 4'd2,  // keep en_a one more cycle, then capture dout_a
        S_MODIFY = 4'd3,
        S_WRITE  = 4'd4,
        S_WAIT1  = 4'd5,
        S_WAIT2  = 4'd6,
        S_RBACK  = 4'd7,
        S_NEXT   = 4'd8;

    reg [3:0]  state;
    reg [2:0]  idx;
    reg [15:0] src_val, exp_val;

    wire rst = ~rst_n;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; idx <= 3'd0;
            en_a<=0; we_a<=0; addr_a<=0; din_a<=0;
            en_b<=0; we_b<=0; addr_b<=0; din_b<=0;
            src_val<=0; exp_val<=0; last_value<=0; ok_led<=0;
        end else begin
            // defaults every cycle
            en_a<=1'b0; we_a<=1'b0;
            en_b<=1'b0; we_b<=1'b0;
            ok_led<=1'b0;

            case (state)
            S_IDLE: begin
                addr_a <= addr_list[idx];
                en_a   <= 1'b1;               // start read (cycle 1)
                state  <= S_READ1;
            end
            S_READ1: begin
                en_a   <= 1'b1;               // keep en_a (cycle 2)
                state  <= S_READ2;
            end
            S_READ2: begin
                src_val <= dout_a;             // now stable
                exp_val <= dout_a + 16'd1;
                state   <= S_MODIFY;
            end
            S_MODIFY: begin
                addr_a <= addr_list[idx];
                din_a  <= exp_val;
                en_a   <= 1'b1;  we_a <= 1'b1; // write A
                state  <= S_WRITE;
            end
            S_WRITE: begin
                addr_b <= addr_list[idx];
                en_b   <= 1'b1;                // start B read
                state  <= S_WAIT1;
            end
            S_WAIT1: begin
                en_b   <= 1'b1;                // wait 1
                state  <= S_WAIT2;
            end
            S_WAIT2: begin
                en_b   <= 1'b1;                // wait 2
                state  <= S_RBACK;
            end
            S_RBACK: begin
                last_value <= dout_b;          // readback to display
                ok_led     <= (dout_b == exp_val);
                state      <= S_NEXT;
            end
            S_NEXT: begin
                idx   <= (idx==N-1) ? 3'd0 : (idx+3'd1);
                state <= S_IDLE;
            end
            endcase
        end
    end
endmodule

`default_nettype wire
