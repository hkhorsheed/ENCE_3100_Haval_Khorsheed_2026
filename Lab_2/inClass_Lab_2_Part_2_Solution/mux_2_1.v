module mux_2_1(
	input s,
	input x,
	input y,
	output m
);

	assign m = (~s&x)|(s&y);

endmodule
