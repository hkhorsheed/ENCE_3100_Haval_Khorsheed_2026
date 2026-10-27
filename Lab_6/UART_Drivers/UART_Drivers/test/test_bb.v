
module test (
	clk,
	areset,
	a,
	c,
	s,
	en);	

	input		clk;
	input		areset;
	input	[12:0]	a;
	output	[9:0]	c;
	output	[9:0]	s;
	input	[0:0]	en;
endmodule
