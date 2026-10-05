module main(
	// Pinout Assignment
	input		MAX10_CLK1_50,
	input		[9:0]		SW,
	input		[1:0]		KEY,
	output	[9:0]		LEDR,
	output	[35:0]	GPIO,
	output	[7:0]		HEX0,
	output	[7:0]		HEX1,
	output	[7:0]		HEX2,
	output	[7:0]		HEX3,
	output	[7:0]		HEX4,
	output	[7:0]		HEX5
);

	// Your Code
	// assign LEDR[9:0] = SW[9:0];
	
	/*
	TFlipFlop TFF_1(
		.T(SW[0]),
		.clk(SW[9]),
		.clear(SW[8]),
		.Qt(LEDR[0])
	);
	*/
	wire w_clk;
	
	Counter_1Hz Counter_1(
		.in_clk(MAX10_CLK1_50),
		.clear(SW[1]),
		.out_clk(w_clk)
	);
	
	wire w_or;
	assign w_or = (SW[1] & MAX10_CLK1_50) | w_clk;
	
	Counter_8bit counter_0(
        .ena(SW[0]),
        .clk(w_or),
        .clear(SW[1]),
        .count(LEDR)
    );


endmodule
