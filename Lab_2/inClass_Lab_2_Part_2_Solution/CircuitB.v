module CircuitB(
	input z,
	output [7:0] s
);

	assign s[7] = 1'b1;
	assign s[6] = 1'b1;
	assign s[5] = z;
	assign s[4] = z;
	assign s[3] = z;
	assign s[2] = 1'b0;
	assign s[1] = 1'b0;
	assign s[0] = z;

endmodule
