`timescale 1ns/1ps
`default_nettype none

// 16-bit ALU for Lab1 with PSR flag control and ADDC family
// Implements: ADD, ADDI, ADDU, ADDUI, ADDC, ADDCI, ADDCU, ADDCUI,
//             SUB, SUBI, CMP, CMPI, CMPU, CMPUI,
//             AND, ANDI, OR, ORI, XOR, XORI, NOT,
//             LSH, LSHI, RSH, RSHI, ALSH, ARSH,
//             MOV, LUI, NOP, WAIT
module alu16 #(
  parameter WIDTH = 16,
  // If set to 1, only allow baseline 1-bit shift (|shamt|==1)
  parameter BASELINE_ONE_BIT_SHIFT = 0
)(
  input  wire [WIDTH-1:0] a,          // usually Rdest
  input  wire [WIDTH-1:0] b,          // Rsrc or (already sign/zero-extended) Imm
  input  wire [4:0]       alu_op,     // operation select code (see localparam list)
  input  wire [4:0]       shamt,      // signed shift amount (-15..+15)
  input  wire             psr_c_in,   // carry-in from PSR (for ADDC family)

  // --- PSR flag control (driven by decoder) ---
  input  wire             flags_en,   // enable writeback to PSR this cycle
  input  wire [4:0]       flags_sel,  // mask of which flags to write {C,F,Z,L,N}
  output wire [4:0]       flags_out,  // masked/controlled flag outputs (to PSR)
  output wire [4:0]       flags_raw,  // raw flags (for debug/trace)

  // --- result outputs ---
  output wire [WIDTH-1:0] y,          // ALU result
  output wire             y_valid     // 0 = no architectural writeback (CMP/WAIT)
);

  // ------------ ALU opcodes (internal codes, not ISA encodings) ------------
  localparam [4:0]
    OP_ADD    = 5'd0,   OP_ADDI   = 5'd1,   OP_ADDU   = 5'd2,   OP_ADDUI  = 5'd3,
    OP_ADDC   = 5'd4,   OP_ADDCI  = 5'd5,   OP_ADDCU  = 5'd6,   OP_ADDCUI = 5'd7,
    OP_SUB    = 5'd8,   OP_SUBI   = 5'd9,
    OP_CMP    = 5'd10,  OP_CMPI   = 5'd11,  OP_CMPU   = 5'd12,  OP_CMPUI  = 5'd13,
    OP_AND    = 5'd14,  OP_ANDI   = 5'd15,  OP_OR     = 5'd16,  OP_ORI    = 5'd17,
    OP_XOR    = 5'd18,  OP_XORI   = 5'd19,  OP_NOT    = 5'd20,
    OP_LSH    = 5'd21,  OP_LSHI   = 5'd22,  OP_RSH    = 5'd23,  OP_RSHI   = 5'd24,
    OP_ARSH   = 5'd25,  OP_ALSH   = 5'd26,
    OP_MOV    = 5'd27,  OP_LUI    = 5'd28,
    OP_NOP    = 5'd29,  OP_WAIT   = 5'd30;

  // ------------ Arithmetic datapaths ------------
  wire [WIDTH:0] add_base = {1'b0, a} + {1'b0, b};
  wire [WIDTH:0] addc_ext = {1'b0, a} + {1'b0, b} + {{WIDTH{1'b0}}, psr_c_in};
  wire [WIDTH:0] sub_ext  = {1'b0, a} - {1'b0, b};

  // Carry/borrow and overflow detection
  wire add_carry    = add_base[WIDTH];
  wire add_overflow = (~(a[WIDTH-1]^b[WIDTH-1])) & (a[WIDTH-1]^add_base[WIDTH-1]);

  wire addc_carry    = addc_ext[WIDTH];
  wire addc_overflow = (~(a[WIDTH-1]^b[WIDTH-1])) & (a[WIDTH-1]^addc_ext[WIDTH-1]);

  wire sub_borrow   = (a < b); // unsigned borrow
  wire sub_overflow = ( a[WIDTH-1]^b[WIDTH-1]) & (a[WIDTH-1]^sub_ext[WIDTH-1]);

  // ------------ Comparison results ------------
  wire cmp_eq         = (a == b);
  wire cmp_l_unsigned = (a <  b);
  wire cmp_l_signed   = ($signed(a) < $signed(b));

  // ------------ Shifter control ------------
  wire signed [4:0] s_shamt   = shamt;
  wire [4:0]        mag_shamt = s_shamt[4] ? (~s_shamt + 5'd1) : s_shamt;

  // Optional restriction to baseline 1-bit shift
  wire [4:0] eff_mag =
    (BASELINE_ONE_BIT_SHIFT != 0) ? (mag_shamt != 0 ? 5'd1 : 5'd0) : mag_shamt;

  // ------------ Main ALU logic ------------
  reg [WIDTH-1:0] result;
  reg             res_valid;
  reg c,f,z,l,n;

  always @* begin
    result    = {WIDTH{1'b0}};
    res_valid = 1'b1;
    c=1'b0; f=1'b0; z=1'b0; l=1'b0; n=1'b0;

    case (alu_op)

      // ====== ADD family ======
      OP_ADD, OP_ADDI: begin
        result = add_base[WIDTH-1:0];
        c = add_carry;  f = add_overflow;
        z = (result == {WIDTH{1'b0}});
      end
      OP_ADDU, OP_ADDUI: begin
        result = add_base[WIDTH-1:0]; // same as ADD, decoder masks PSR updates
        c = add_carry;  f = add_overflow;
        z = (result == {WIDTH{1'b0}});
      end
      OP_ADDC, OP_ADDCI: begin
        result = addc_ext[WIDTH-1:0];
        c = addc_carry; f = addc_overflow;
        z = (result == {WIDTH{1'b0}});
      end
      OP_ADDCU, OP_ADDCUI: begin
        result = addc_ext[WIDTH-1:0]; // same as ADDC, decoder masks PSR updates
        c = addc_carry; f = addc_overflow;
        z = (result == {WIDTH{1'b0}});
      end

      // ====== SUB / CMP family ======
      OP_SUB, OP_SUBI: begin
        result = sub_ext[WIDTH-1:0];
        c = sub_borrow; f = sub_overflow;
        z = (result == {WIDTH{1'b0}});
      end
      OP_CMP, OP_CMPI: begin
        result    = sub_ext[WIDTH-1:0]; // useful for debug, not written back
        res_valid = 1'b0;
        z = cmp_eq;
        l = cmp_l_unsigned;
        n = cmp_l_signed;
        c = sub_borrow;
        f = sub_overflow;
      end
      OP_CMPU, OP_CMPUI: begin
        result    = sub_ext[WIDTH-1:0];
        res_valid = 1'b0;
        z = cmp_eq;
        l = cmp_l_unsigned;
        n = cmp_l_signed;
        c = sub_borrow;
        f = sub_overflow;
      end

      // ====== Logic ======a
      OP_AND, OP_ANDI: begin result = a & b; z = (result == 0); end
      OP_OR,  OP_ORI:  begin result = a | b; z = (result == 0); end
      OP_XOR, OP_XORI: begin result = a ^ b; z = (result == 0); end
      OP_NOT:          begin result = ~a; z = (result == 0); end

      // ====== Shifts ======
      OP_LSH, OP_LSHI: begin
        if (!s_shamt[4]) result = a <<  s_shamt;
        else             result = a >>  eff_mag;
        z = (result == 0);
      end
      OP_RSH, OP_RSHI: begin
        result = a >> eff_mag;
        z = (result == 0);
      end
      OP_ARSH: begin
        if (!s_shamt[4]) result = $signed(a) >>> s_shamt;
        else             result = a << eff_mag;
        z = (result == 0);
      end
      OP_ALSH: begin
        result = a << eff_mag;
        z = (result == 0);
      end

      // ====== Data move / misc ======
      OP_MOV: begin
        result = b; z = (result == 0);
      end
      OP_LUI: begin
        result = {b[7:0], 8'h00}; // upper 8 bits = imm8, lower = 0
        z = (result == 0);
      end
      OP_NOP: begin
        result = a; z = (result == 0);
      end
      OP_WAIT: begin
        result    = a;  // no observable effect
        res_valid = 1'b0; // no writeback
        z = (result == 0);
      end

      default: begin
        result    = {WIDTH{1'b0}};
        res_valid = 1'b1;
      end
    endcase
  end

  // Raw flags {C,F,Z,L,N}
  assign flags_raw = {c,f,z,l,n};

  // Apply decoder control: only update when enabled, and only selected bits
  wire [4:0] masked = flags_raw & flags_sel;
  assign flags_out  = flags_en ? masked : 5'b0;

  assign y       = result;
  assign y_valid = res_valid;

endmodule

`default_nettype wire
