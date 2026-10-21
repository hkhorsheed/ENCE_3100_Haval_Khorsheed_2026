module main(
	// Board I/Os
	input		MAX10_CLK1_50,
	input 	[9:0]		SW,
	output	[9:0]		LEDR,
	output	[35:0]	GPIO
);

	wire w_clk = MAX10_CLK1_50;

	wire w_tick;
	
	wire [9:0] w_counter1;
	wire [9:0] w_counter2;
	wire [9:0] w_counter3;
	wire [9:0] w_counter4;
	wire [9:0] w_counter5;
	
	MUX8_10bits MUX0 (
	.in0(w_counter1),
	.in1(w_counter2),
	.in2(w_counter3),
	.in3(w_counter4),
	.in4(w_counter5),
	.in5(10'd0),
	.in6(10'd0),
	.in7(10'd0),
	.sel(SW[2:0]),
	.out(LEDR[9:0])
	);
	
	// Patterns
	Pattern1 Patt1 (
		.clk(w_clk),
		.rst(SW[9]),
		.en(SW[8]),
		.dir(SW[7]),                 
		.counter(w_counter1)
	);
	
	Pattern2 Patt2 (
		.clk(w_clk),
		.rst(SW[9]),
		.en(SW[8]),
		.dir(SW[7]),                 
		.counter(w_counter2)
	);
	
	Pattern3 Patt3 (
		.clk(w_clk),
		.rst(SW[9]),
		.en(SW[8]),
		.dir(SW[7]),                 
		.counter(w_counter3)
	);
	
	Pattern4 Patt4 (
		.clk(w_clk),
		.rst(SW[9]),
		.en(SW[8]),
		.dir(SW[7]),                 
		.counter(w_counter4)
	);
	
	Pattern5 Patt5 (
		.clk(w_clk),
		.rst(SW[9]),
		.en(SW[8]),
		.dir(SW[7]),                 
		.counter(w_counter5)
	);

endmodule
