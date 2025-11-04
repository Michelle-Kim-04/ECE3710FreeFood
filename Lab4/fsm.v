`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// Lab4 Stage-1 CPU FSM (3-Stage Pipeline Demonstration)
// Stages required by TA:
//
//   S0: FETCH              - send PC to instruction memory
//   S1: DECODE+READ+EXEC   - latch instruction, decode, read regfile, run ALU
//   S2: WRITEBACK          - write ALU result to regfile, increment PC
//
// Notes:
// - No IMEM wait state (hard-coded single-cycle BRAM assumption)
// - Combined decode + read + execute in one cycle per TA request
// - Demonstration only (no hazard or stall logic)
// ============================================================================

module fsm (
    input  wire        clk,
    input  wire        rst_n,

    // instruction from BRAM (sync read assumed)
    input  wire [15:0] instr_word,

    // PC interface
    input  wire [15:0] pc,
    output reg  [15:0] pc_next,
    output reg         pc_en,

    // Register file interface
    output reg  [3:0]  rdest_addr,
    output reg  [3:0]  rsrc_addr,
    output reg         reg_we,

    // ALU interface
    output reg  [4:0]  alu_op_sel,

    // ALU output for writeback & debug
    input  wire [15:0] alu_out,
    input  wire        alu_y_valid,

    output reg  [15:0] last_value,
    output reg         ok_led
);

    // FSM states (3-stage CPU)
    localparam [1:0]
        S_FETCH   = 2'd0,
        S_DECODE  = 2'd1,   // decode + reg read + alu eval
        S_WB      = 2'd2;   // writeback + PC update

    reg [1:0] state, next_state;

    // Latched instruction fields
    reg [3:0] rdest_l, rsrc_l, subfunc_l;

    wire rst = ~rst_n;

    // Decode ISA minor opcode to ALU op
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

    // State register & debug latch
    always @(posedge clk) begin
        if (rst) begin
            state      <= S_FETCH;
            last_value <= 16'd0;
        end else begin
            state <= next_state;
            if (state == S_WB && alu_y_valid)
                last_value <= alu_out; // store result for HEX display
        end
    end

    // Main FSM logic
    always @* begin
        // Default control values
        next_state = state;
        reg_we     = 1'b0;
        pc_en      = 1'b0;
        ok_led     = 1'b0;

        pc_next = pc + 16'd1;
        rdest_addr = rdest_l;
        rsrc_addr  = rsrc_l;
        alu_op_sel = decode_alu_op(subfunc_l);

        case (state)
            // ---------------------------
            // S0: FETCH instruction
            // ---------------------------
            S_FETCH: begin
                next_state = S_DECODE;
            end

            // ---------------------------
            // S1: DECODE + READ + EXECUTE
            // ---------------------------
            S_DECODE: begin
                next_state = S_WB;
            end

            // ---------------------------
            // S2: WRITEBACK + PC++
            // ---------------------------
            S_WB: begin
                reg_we  = alu_y_valid; // write result to regfile
                pc_en   = 1'b1;        // increment PC
                ok_led  = 1'b1;        // LED pulse marks 1 instruction complete
                next_state = S_FETCH;
            end
        endcase
    end

    // Latch instruction fields in FETCH stage
    always @(posedge clk) begin
        if (rst) begin
            rdest_l   <= 4'd0;
            rsrc_l    <= 4'd0;
            subfunc_l <= 4'd0;
        end else if (state == S_FETCH) begin
            rdest_l   <= instr_word[11:8];
            subfunc_l <= instr_word[7:4];
            rsrc_l    <= instr_word[3:0];
        end
    end

endmodule

`default_nettype wire
