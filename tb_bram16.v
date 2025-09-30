`timescale 1ns/1ps
`default_nettype none

module tb_bram16;

	// Test Block Ram
	
	// Test signals
	// Port A
	reg clk;
	reg en_a;
	reg [8:0] addr_a;
	reg [15:0] din_a;
	wire [15:0] dout_a;
	
	// Port B
	reg en_b;
	reg we_b;
	reg [8:0] addr_b;
	reg [15:0] din_b;
	wire [15:0] dout_b;
	
	// Instantiate bram
	bram16 BRAM (
		.clk(clk), .en_a(en_a), .addr_a(addr_a),
		.din_a(din_a), .dout_a(dout_a), .en_b(en_b),
		.addr_b(addr_b), .din_b(din_b), .dout_b(dout_b)
	);
	
	// Clock generator
	always #5 clk = ~clk;
	
	// Test procedure
	initial begin
	
		// Reset memory address 0 and 1
		clk = 0; en_a = 1; en_b = 1;
		din_a = 16'd0; din_b = 16'd0;
		addr_a = 9'd0; addr_b = 9'd1;
		
		
		// Disable writing
		#10 en_a = 0; en_b = 0;
		$display("A address: %d, B address: %d, A output: %d, B output: %d", addr_a, addr_b, dout_a, dout_b); //Should be 0, 1, 0, 0
		
		
		// Set memory addresses 0 and 1 to 16 and 32
		#10 din_a = 16'd16; din_b = 16'd32;
		#10 en_a = 1; en_b = 1;
		
		// Disable writing
		#10 en_a = 0; en_b = 0;
		#10 addr_a = 9'd1; addr_b = 9'd1;
		$display("A address: %d, B address: %d, A output: %d, B output: %d", addr_a, addr_b, dout_a, dout_b); // should be 1, 0, 32, 16
	end
	
	
endmodule