module Comparator(
	input [3:0] v,
	output z
);

	assign z = v[3]&v[1]|v[3]&v[2];

endmodule
