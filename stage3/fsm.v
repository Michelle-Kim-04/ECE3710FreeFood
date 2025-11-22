`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// Stage 3 FSM for EECS 427 CPU
// Supports: MOVI, ADD, SUB, LOAD, STORE, CMP, CMPI, Bcond, Jcond, JAL
// S0=FETCH, S1=DECODE, S2=EXEC_RTYPE, S3=STORE, S4=LOAD_ADDR, S5=LOAD_WB,
// S6=EXEC_CMP, S7=EXEC_BRANCH, S8=EXEC_JUMP
// ============================================================================

module fsm (
    input  wire        clk,
    input  wire        rst_n,

    // ---- PC ----
    input  wire [15:0] pc_in,
    output reg         pc_en,
    output reg  [15:0] pc_next,

    // ---- IMEM ----
    input  wire [15:0] imem_dout,
    output reg         imem_en,
    output reg  [8:0]  imem_addr,

    // ---- DMEM ----
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
    input  wire [4:0]  alu_flags,   // <-- from ALU flags_out

    // ---- Debug ----
    output reg  [15:0] ir_out
);

    // =========================================================================
    // State definitions
    // =========================================================================
    localparam S_FETCH      = 4'd0;
    localparam S_DECODE     = 4'd1;
    localparam S_EXEC_RTYPE = 4'd2;
    localparam S_STORE      = 4'd3;
    localparam S_LOAD_ADDR  = 4'd4;
    localparam S_LOAD_WB    = 4'd5;
    localparam S_EXEC_CMP   = 4'd6;
    localparam S_EXEC_BRANCH= 4'd7;
    localparam S_EXEC_JUMP  = 4'd8;

    reg [3:0] state, next_state;

    // Instruction register
    reg [15:0] ir;

    // Fields
    wire [3:0] op_hi   = ir[15:12];
    wire [3:0] rdest   = ir[11:8];
    wire [3:0] subfunc = ir[7:4];
    wire [3:0] rsrc    = ir[3:0];

    // decode from imem_dout
    wire [3:0] dec_op_hi   = imem_dout[15:12];
    wire [3:0] dec_subfunc = imem_dout[7:4];

    // PC increment
    wire [15:0] pc_plus1 = pc_in + 16'd1;
    wire rst = ~rst_n;

    // ALU ops
    localparam OP_ADD = 5'd0;
    localparam OP_SUB = 5'd8;
    localparam OP_NOP = 5'd29;

    // =========================================================================
    // Sequential: state, IR latch
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            state  <= S_FETCH;
            ir     <= 16'h0000;
            ir_out <= 16'h0000;
        end else begin
            state <= next_state;

            if (state == S_DECODE)
                ir <= imem_dout;

            ir_out <= ir;
        end
    end

    // =========================================================================
    // Combinational: next state + control
    // =========================================================================
    always @* begin
        // defaults
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
        alu_flags_sel = 5'b00000;
        alu_cin       = 1'b0;

        next_state    = state;

        case (state)

        // =====================================================================
        // S0 FETCH
        // =====================================================================
        S_FETCH: begin
            imem_en    = 1'b1;
            imem_addr  = pc_in[8:0];
            next_state = S_DECODE;
        end

        // =====================================================================
        // S1 DECODE
        // =====================================================================
        S_DECODE: begin
            case (dec_op_hi)

                4'b0000: begin
                    // R-type: ADD/SUB/CMP
                    if (dec_subfunc == 4'b1011)   // CMP
                        next_state = S_EXEC_CMP;
                    else
                        next_state = S_EXEC_RTYPE;
                end

                4'b1101: next_state = S_EXEC_RTYPE; // MOVI

                4'b0100: begin
                    // Special group
                    case (dec_subfunc)
                        4'b0000: next_state = S_LOAD_ADDR; // LOAD
                        4'b0100: next_state = S_STORE;     // STORE
                        4'b1100: next_state = S_EXEC_JUMP; // Jcond
                        4'b1000: next_state = S_EXEC_JUMP; // JAL
                        default: begin
                            pc_en      = 1'b1;
                            pc_next    = pc_plus1;
                            next_state = S_FETCH;
                        end
                    endcase
                end

                4'b1100: next_state = S_EXEC_BRANCH;   // Bcond

                default: begin
                    pc_en      = 1'b1;
                    pc_next    = pc_plus1;
                    next_state = S_FETCH;
                end
            endcase
        end

        // =====================================================================
        // S2 - EXEC_RTYPE (ADD/SUB/MOVI)
        // =====================================================================
        S_EXEC_RTYPE: begin
            case (op_hi)

                4'b0000: begin
                    // ADD/SUB
                    rf_ra_addr = rsrc;
                    rf_rb_addr = rdest;

                    case (subfunc)
                        4'b0101: alu_op = OP_ADD;
                        4'b1001: alu_op = OP_SUB;
                        default: alu_op = OP_NOP;
                    endcase

                    rf_we    = 1'b1;
                    rf_waddr = rdest;
                    rf_wdata = alu_out;

                    pc_en    = 1'b1;
                    pc_next  = pc_plus1;
                    next_state = S_FETCH;
                end

                4'b1101: begin
                    // MOVI
                    rf_we    = 1'b1;
                    rf_waddr = rdest;
                    rf_wdata = {8'h00, ir[7:0]};
                    pc_en    = 1'b1;
                    pc_next  = pc_plus1;
                    next_state = S_FETCH;
                end

                default: begin
                    pc_en      = 1'b1;
                    pc_next    = pc_plus1;
                    next_state = S_FETCH;
                end
            endcase
        end

        // =====================================================================
        // S3 - STORE
        // =====================================================================
        S_STORE: begin
            // STORE Rsrc,Raddr
            rf_ra_addr = rsrc;
            rf_rb_addr = rdest;

            dmem_en   = 1'b1;
            dmem_we   = 1'b1;
            dmem_addr = rf_ra_data[8:0];
            dmem_din  = rf_rb_data;

            pc_en     = 1'b1;
            pc_next   = pc_plus1;
            next_state = S_FETCH;
        end

        // =====================================================================
        // S4 - LOAD_ADDR
        // =====================================================================
        S_LOAD_ADDR: begin
            rf_ra_addr = rsrc;

            dmem_en   = 1'b1;
            dmem_we   = 1'b0;
            dmem_addr = rf_ra_data[8:0];

            next_state = S_LOAD_WB;
        end

        // =====================================================================
        // S5 - LOAD_WB
        // =====================================================================
        S_LOAD_WB: begin
            rf_we    = 1'b1;
            rf_waddr = rdest;
            rf_wdata = dmem_dout;

            pc_en    = 1'b1;
            pc_next  = pc_plus1;
            next_state = S_FETCH;
        end

        // =====================================================================
        // S6 - EXEC_CMP
        // =====================================================================
        S_EXEC_CMP: begin
            if (op_hi == 4'b0000) begin
                // CMP
                rf_ra_addr = rsrc;
                rf_rb_addr = rdest;
            end else begin
                // CMPI (not required in baseline but included)
                rf_rb_addr = rdest;
            end

            alu_op        = OP_SUB;
            alu_flags_en  = 1'b1;
            alu_flags_sel = 5'b00111;   // update Z,L,N

            pc_en    = 1'b1;
            pc_next  = pc_plus1;
            next_state = S_FETCH;
        end

        // =====================================================================
        // S7 - EXEC_BRANCH (Bcond)
        // =====================================================================
        S_EXEC_BRANCH: begin
            // cond = ir[11:8], disp = ir[7:0]
            if (do_branch(ir[11:8], alu_flags)) begin
                pc_en   = 1'b1;
                pc_next = pc_in + {{8{ir[7]}}, ir[7:0]};
            end else begin
                pc_en   = 1'b1;
                pc_next = pc_plus1;
            end
            next_state = S_FETCH;
        end

        // =====================================================================
        // S8 - EXEC_JUMP (Jcond + JAL)
        // =====================================================================
        S_EXEC_JUMP: begin
            if (subfunc == 4'b1100) begin
                // Jcond Rtarget
                if (do_branch(rdest, alu_flags)) begin
                    rf_ra_addr = rsrc;
                    pc_en      = 1'b1;
                    pc_next    = rf_ra_data;
                end else begin
                    pc_en      = 1'b1;
                    pc_next    = pc_plus1;
                end
                next_state = S_FETCH;

            end else if (subfunc == 4'b1000) begin
                // JAL Rlink,Rtarget
                rf_we    = 1'b1;
                rf_waddr = rdest;
                rf_wdata = pc_plus1;

                rf_ra_addr = rsrc;
                pc_en      = 1'b1;
                pc_next    = rf_ra_data;

                next_state = S_FETCH;

            end else begin
                pc_en      = 1'b1;
                pc_next    = pc_plus1;
                next_state = S_FETCH;
            end
        end

        endcase
    end

    // =========================================================================
    // Condition evaluation function (EQ / NE / UC)
    // =========================================================================
    function do_branch;
        input [3:0] cond;
        input [4:0] flags;
        begin
            case (cond)
                4'h0: do_branch = flags[2];     // EQ → Z
                4'h1: do_branch = ~flags[2];    // NE
                4'hD: do_branch = 1'b1;         // UC (unconditional)
                default: do_branch = 1'b0;
            endcase
        end
    endfunction

endmodule

`default_nettype wire
