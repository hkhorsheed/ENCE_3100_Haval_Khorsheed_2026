module main(
	// Pinout Assignment
	input		MAX10_CLK1_50,
	input		[9:0]		SW,
	output	[9:0]		LEDR,
	output	[1:0]		KEY,
	output	[35:0]	GPIO
);

	ram32x8_lut LUT0(
	.clk(SW[9]),
	.we(SW[8]),
	.addr(SW[4:0]),
	.din({5'd0, SW[7:5]}),
	.dout(w_mem_1)
	);
	
	ram32x8_IP IP_RAM0(
		.address(~SW[4:0]),
		.clock(SW[9]),
		.data({5'd0, SW[7:5]}),
		.wren(SW[8]),
		.q(w_mem_2)
	);
	
	wire [7:0] w_mem_1;
	wire [7:0] w_mem_2;
	
	assign LEDR[7:0] = (KEY[0]) ? w_mem_1 : w_mem_2;

endmodule
