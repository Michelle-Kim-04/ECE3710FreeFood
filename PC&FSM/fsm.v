`timescale 1ns/1ps
`default_nettype none

// fsm.v : Lab4 Stage1 Control FSM
//  FETCH → DECODE → EXECUTE → WRITEBACK

module fsm (
    input  wire        clk,
    input  wire        rst_n,

    // from instruction memory
    input  wire [15:0] instr_word,

    // current PC
    input  wire [15:0] pc,
    output reg  [15:0] pc_next,
    output reg         pc_en,

    // regfile interface
    output reg  [3:0]  rdest_addr,
    output reg  [3:0]  rsrc_addr,
    output reg         reg_we,

    // ALU interface
    output reg  [4:0]  alu_op_sel,

    // display/debug
    input  wire [15:0] alu_out,
    input  wire        alu_y_valid,
    output reg  [15:0] last_value,
    output reg         ok_led
);
    localparam [1:0]
        S_FETCH     = 2'd0,
        S_DECODE    = 2'd1,
        S_EXECUTE   = 2'd2,
        S_WRITEBACK = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] rdest_l, rsrc_l, subfunc_l;
    wire rst = ~rst_n;

    // decode sub-opcode → alu_op
    function [4:0] decode_alu_op(input [3:0] subf);
        case (subf)
            4'b0101: decode_alu_op = 5'd0;   // ADD
            4'b1001: decode_alu_op = 5'd8;   // SUB
            4'b0001: decode_alu_op = 5'd14;  // AND
            4'b0010: decode_alu_op = 5'd16;  // OR
            4'b0011: decode_alu_op = 5'd18;  // XOR
            4'b1101: decode_alu_op = 5'd27;  // MOV
            default: decode_alu_op = 5'd29;  // NOP
        endcase
    endfunction

    // state register
    always @(posedge clk) begin
        if (rst) begin
            state <= S_FETCH;
            last_value <= 16'd0;
        end else begin
            state <= next_state;
            if (state == S_WRITEBACK && alu_y_valid)
                last_value <= alu_out;
        end
    end

    // next-state logic
    always @* begin
        next_state = state;
        pc_en      = 1'b0;
        pc_next    = pc + 16'd1;
        reg_we     = 1'b0;
        ok_led     = 1'b0;

        rdest_addr = rdest_l;
        rsrc_addr  = rsrc_l;
        alu_op_sel = decode_alu_op(subfunc_l);

        case (state)
            S_FETCH:     next_state = S_DECODE;
            S_DECODE:    next_state = S_EXECUTE;
            S_EXECUTE:   next_state = S_WRITEBACK;
            S_WRITEBACK: begin
                reg_we   = alu_y_valid;
                ok_led   = 1'b1;
                pc_en    = 1'b1;
                next_state = S_FETCH;
            end
        endcase
    end

    // latch instruction fields
    always @(posedge clk) begin
        if (rst) begin
            rdest_l <= 4'd0;
            rsrc_l  <= 4'd0;
            subfunc_l <= 4'd0;
        end else if (state == S_FETCH) begin
            rdest_l   <= instr_word[11:8];
            subfunc_l <= instr_word[7:4];
            rsrc_l    <= instr_word[3:0];
        end
    end
endmodule

`default_nettype wire
