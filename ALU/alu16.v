`timescale 1ns/1ps
`default_nettype none

module alu16 #(
  parameter WIDTH = 16,
  parameter BASELINE_ONE_BIT_SHIFT = 0
)(
  input  wire [WIDTH-1:0] a,
  input  wire [WIDTH-1:0] b,
  input  wire [4:0]       alu_op,
  input  wire [4:0]       shamt,
  input  wire             psr_c_in,

  input  wire             flags_en,
  input  wire [4:0]       flags_sel,
  output wire [4:0]       flags_out,
  output wire [4:0]       flags_raw,

  output wire [WIDTH-1:0] y,
  output wire             y_valid
);

  // ------------ ALU opcodes ------------
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

  wire add_carry    = add_base[WIDTH];
  wire add_overflow = (~(a[WIDTH-1]^b[WIDTH-1])) & (a[WIDTH-1]^add_base[WIDTH-1]);

  wire addc_carry    = addc_ext[WIDTH];
  wire addc_overflow = (~(a[WIDTH-1]^b[WIDTH-1])) & (a[WIDTH-1]^addc_ext[WIDTH-1]);

  wire sub_borrow   = (a < b);
  wire sub_overflow = ( a[WIDTH-1]^b[WIDTH-1]) & (a[WIDTH-1]^sub_ext[WIDTH-1]);

  // ------------ Comparison results ------------
  wire cmp_eq         = (a == b);
  wire cmp_l_unsigned = (a <  b);
  wire cmp_l_signed   = ($signed(a) < $signed(b));

  // ------------ Shifter control ------------
  wire signed [4:0] s_shamt   = shamt;
  wire [4:0]        mag_shamt = s_shamt[4] ? (~s_shamt + 5'd1) : s_shamt;

  wire [4:0] eff_mag =
    (BASELINE_ONE_BIT_SHIFT != 0) ? (mag_shamt != 0 ? 5'd1 : 5'd0) : mag_shamt;

  // ------------ Main ALU logic ------------
  reg [WIDTH-1:0] result;
  reg             res_valid;
  reg c,f,z,l,n;

  always @* begin
    result    = {WIDTH{1'b0}};
    res_valid = 1'b1;
    c=0; f=0; z=0; l=0; n=0;

    case (alu_op)

      // ====== ADD family ======
      OP_ADD, OP_ADDI: begin
        result = add_base[WIDTH-1:0];
        c = add_carry;
        f = add_overflow;
        z = (result == 0);
        n = ($signed(result) < 0);
      end

      OP_ADDU, OP_ADDUI: begin
        result = add_base[WIDTH-1:0];
        // unsigned add: no c/f
        z = (result == 0);
        n = ($signed(result) < 0);
      end

      // ====== ADDC family ======
      OP_ADDC, OP_ADDCI: begin
        result = addc_ext[WIDTH-1:0];
        c = addc_carry;
        f = addc_overflow;
        z = (result == 0);
        n = ($signed(result) < 0);
      end

      OP_ADDCU, OP_ADDCUI: begin
        result = addc_ext[WIDTH-1:0];
        // unsigned add with carry: ignore c/f
        z = (result == 0);
        n = ($signed(result) < 0);
      end

      // ====== SUB family ======
      OP_SUB, OP_SUBI: begin
        result = sub_ext[WIDTH-1:0];
        c = 0; // do not use borrow for signed
        f = sub_overflow;
        z = (result == 0);
        n = ($signed(result) < 0);
      end

      // ====== CMP family ======
      OP_CMP, OP_CMPI, OP_CMPU, OP_CMPUI: begin
        result    = {WIDTH{1'b0}}; // no output
        res_valid = 1'b0;          // no writeback
        c = 0;                     // CMP does not set carry
        f = 0;                     // CMP does not set overflow
        z = cmp_eq;                // Z = equality
        l = cmp_l_unsigned;        // L = unsigned less
        n = cmp_l_signed;          // N = signed less
      end

      // ====== Logic ======
      OP_AND, OP_ANDI: begin
        result = a & b;
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_OR, OP_ORI: begin
        result = a | b;
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_XOR, OP_XORI: begin
        result = a ^ b;
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_NOT: begin
        result = ~a;
        z = (result == 0);
        n = ($signed(result) < 0);
      end

      // ====== Shifts ======
      OP_LSH, OP_LSHI: begin
        result = a << eff_mag;
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_RSH, OP_RSHI: begin
        result = a >> eff_mag; // logical shift
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_ARSH: begin
        result = $signed(a) >>> eff_mag; // arithmetic shift
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_ALSH: begin
        result = a << eff_mag;
        z = (result == 0);
        n = ($signed(result) < 0);
      end

      // ====== Data move / misc ======
      OP_MOV: begin
        result = b;
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_LUI: begin
        result = {b[7:0], 8'h00};
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_NOP: begin
        result = a;
        z = (result == 0);
        n = ($signed(result) < 0);
      end
      OP_WAIT: begin
        result    = a;
        res_valid = 1'b0;
        z = (result == 0);
        n = ($signed(result) < 0);
      end

      default: begin
        result    = {WIDTH{1'b0}};
        res_valid = 1'b1;
      end
    endcase
  end

  // Raw flags {C,F,Z,L,N}
  assign flags_raw = {c,f,z,l,n};

  // Apply decoder control
  wire [4:0] masked = flags_raw & flags_sel;
  assign flags_out  = flags_en ? masked : 5'b0;

  assign y       = result;
  assign y_valid = res_valid;

endmodule

`default_nettype wire
