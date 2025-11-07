`timescale 1ns/1ps
`default_nettype none
// ============================================================================
// Lab 4 - Stage 2 FSM (Final Verified Edition)
// ----------------------------------------------------------------------------
// • Supports: MOVI, ADD, SUB, LOAD, STORE, NOP
// • Pipeline stages: FETCH → DECODE → EXEC → MEMACCESS → WRITEBACK
// • Handles synchronous BRAM timing (instruction valid next cycle)
// • PC increments in STORE or WRITEBACK stage
// • Exports latched instruction (ir_out) for HEX display
// ============================================================================

module fsm (
    input  wire        clk,
    input  wire        rst_n,

    // ---- Program Counter ----
    input  wire [15:0] pc_in,
    output reg         pc_en,
    output reg  [15:0] pc_next,

    // ---- Instruction Memory (Port A) ----
    input  wire [15:0] imem_dout,
    output reg         imem_en,
    output reg  [8:0]  imem_addr,

    // ---- Data Memory (Port B) ----
    output reg         dmem_en,
    output reg         dmem_we,
    output reg  [8:0]  dmem_addr,
    output reg  [15:0] dmem_din,
    input  wire [15:0] dmem_dout,

    // ---- Register File ----
    output reg         rf_we,
    output reg  [3:0]  rf_waddr,
    output reg  [15:0] rf_wdata,
    output reg  [3:0]  rf_ra_addr,
    input  wire [15:0] rf_ra_data,
    output reg  [3:0]  rf_rb_addr,
    input  wire [15:0] rf_rb_data,

    // ---- ALU ----
    output reg  [4:0]  alu_op,
    output reg  [4:0]  alu_shamt,
    output reg         alu_flags_en,
    output reg  [4:0]  alu_flags_sel,
    output reg         alu_cin,
    input  wire [15:0] alu_out,

    // ---- Debug Output ----
    output reg  [15:0] ir_out     // latched instruction for HEX display
);

    // FSM state encoding
    localparam S_FETCH     = 3'd0;
    localparam S_DECODE    = 3'd1;
    localparam S_EXEC      = 3'd2;
    localparam S_MEMACCESS = 3'd3;
    localparam S_WB        = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] ir;  // instruction register

    // --- Instruction field extraction ---
    wire [3:0] opcode_hi = ir[15:12];
    wire [3:0] rdest     = ir[11:8];
    wire [3:0] subfunc   = ir[7:4];
    wire [3:0] rsrc      = ir[3:0];

    // --- ALU operation codes ---
    localparam OP_ADD = 5'd0;
    localparam OP_SUB = 5'd8;
    localparam OP_NOP = 5'd29;

    wire [15:0] pc_plus1 = pc_in + 16'd1;
    wire rst = ~rst_n;

    // =========================================================================
    // Sequential logic: update state and latch instruction
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state  <= S_FETCH;
            ir     <= 16'h0000;
            ir_out <= 16'h0000;
        end else begin
            state  <= next_state;
            if (state == S_DECODE)
                ir <= imem_dout;     // latch instruction (BRAM delay)
            ir_out <= ir;            // export for debug
        end
    end

    // =========================================================================
    // Combinational logic: next-state and control signal generation
    // =========================================================================
    always @* begin
        // ---- Default safe values ----
        pc_en         = 1'b0;
        pc_next       = pc_in;
        imem_en       = 1'b1;
        imem_addr     = pc_in[8:0];
        dmem_en       = 1'b0;
        dmem_we       = 1'b0;
        dmem_addr     = 9'd0;
        dmem_din      = 16'h0000;
        rf_we         = 1'b0;
        rf_waddr      = 4'd0;
        rf_wdata      = 16'h0000;
        rf_ra_addr    = 4'd0;
        rf_rb_addr    = 4'd0;
        alu_op        = OP_NOP;
        alu_shamt     = 5'd0;
        alu_flags_en  = 1'b0;
        alu_flags_sel = 5'd0;
        alu_cin       = 1'b0;
        next_state    = state;

        // ---- FSM behavior ----
        case (state)
            // =============================================================
            // FETCH : send PC to instruction memory
            // =============================================================
            S_FETCH: begin
                imem_en   = 1'b1;
                imem_addr = pc_in[8:0];
                next_state = S_DECODE;
            end

            // =============================================================
            // DECODE : instruction available; decide type
            // =============================================================
            S_DECODE: begin
                case (imem_dout[15:12])
                    4'b0000: next_state = S_EXEC;   // R-type
                    4'b0100: next_state = S_EXEC;   // LOAD/STORE
                    4'b0101: next_state = S_WB;     // MOVI
                    default: begin                  // NOP
                        pc_en     = 1'b1;
                        pc_next   = pc_plus1;
                        next_state = S_FETCH;
                    end
                endcase
            end

            // =============================================================
            // EXEC : perform ALU operation or prepare memory address
            // =============================================================
            S_EXEC: begin
                if (opcode_hi == 4'b0000) begin
                    // --- R-type ---
                    rf_ra_addr = rsrc;
                    rf_rb_addr = rdest;
                    case (subfunc)
                        4'b0101: alu_op = OP_ADD;
                        4'b1001: alu_op = OP_SUB;
                        default: alu_op = OP_NOP;
                    endcase
                    next_state = S_WB;

                end else if (opcode_hi == 4'b0100) begin
                    // --- LOAD / STORE ---
                    rf_ra_addr = rsrc;
                    rf_rb_addr = rdest;
                    next_state = S_MEMACCESS;
                end
            end

            // =============================================================
            // MEMACCESS : handle LOAD/STORE with BRAM (Port B)
            // =============================================================
            S_MEMACCESS: begin
                dmem_en = 1'b1;
                if (subfunc == 4'b0000) begin
                    // LOAD Rdest,Rsrc → Rdest ← MEM[Rsrc]
                    dmem_we   = 1'b0;
                    dmem_addr = rf_ra_data[8:0];
                    next_state = S_WB;

                end else if (subfunc == 4'b0100) begin
                    // STORE Rsrc,Rdest → MEM[Rdest] ← Rsrc
                    dmem_we   = 1'b1;
                    dmem_addr = rf_rb_data[8:0];
                    dmem_din  = rf_ra_data;
                    pc_en     = 1'b1;
                    pc_next   = pc_plus1;
                    next_state = S_FETCH;
                end else begin
                    // Unsupported subfunc
                    pc_en     = 1'b1;
                    pc_next   = pc_plus1;
                    next_state = S_FETCH;
                end
            end

            // =============================================================
            // WRITEBACK : write result back to register
            // =============================================================
            S_WB: begin
                case (opcode_hi)
                    // --- R-type (ADD, SUB) ---
                    4'b0000: begin
                        rf_we     = 1'b1;
                        rf_waddr  = rdest;
                        rf_wdata  = alu_out;
                    end

                    // --- LOAD ---
                    4'b0100: begin
                        if (subfunc == 4'b0000) begin
                            rf_we     = 1'b1;
                            rf_waddr  = rdest;
                            rf_wdata  = dmem_dout;
                        end
                    end

                    // --- MOVI ---
                    4'b0101: begin
                        rf_we     = 1'b1;
                        rf_waddr  = rdest;
                        rf_wdata  = {12'b0, rsrc};
                    end
                endcase
                pc_en   = 1'b1;
                pc_next = pc_plus1;
                next_state = S_FETCH;
            end
        endcase
    end
endmodule

`default_nettype wire

