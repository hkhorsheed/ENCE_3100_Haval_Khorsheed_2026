module Seg7_Decoder(
	input [3:0] m,
	output [7:0] out
);

	//
	assign out[7] = 1'b1;
	assign out[6] = ~m[3]&~m[2]&~m[1]|m[2]&m[1]&m[0];
	assign out[5] = ~m[3]&~m[2]&m[0]|~m[2]&m[1];
	assign out[4] = m[0]|m[2]&~m[1];
	assign out[3] = ~m[3]&~m[2]&~m[1]&m[0]|m[2]&~m[1]&~m[0]|m[2]&m[1]&m[0];
	assign out[2] = ~m[2]&m[1]&~m[0];
	assign out[1] = m[2]&~m[1]&m[0]|m[2]&m[1]&~m[0];
	assign out[0] = ~m[3]&~m[2]&~m[1]&m[0]|m[2]&~m[1]&~m[0];
	
endmodule
