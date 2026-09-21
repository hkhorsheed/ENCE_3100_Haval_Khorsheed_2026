module CircuitA(
	input [2:0] v,
	output [2:0] out
);

	assign out[2] = v[2]&v[1];
	assign out[1] = ~v[1];
	assign out[0] = v[0];

endmodule
