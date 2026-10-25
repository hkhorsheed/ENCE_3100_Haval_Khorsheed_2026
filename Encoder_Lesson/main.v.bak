
`default_nettype none

module main(
	// Board I/Os
	input		MAX10_CLK1_50,
	input 	[9:0]		SW,
	output	[9:0]		LEDR,
	inout		[35:0]	GPIO,
	output 	[7:0]		HEX0
	//inout		[15:0]	ARDUINO_IO
);

	
	wire w_clk = MAX10_CLK1_50;

	
	wire RxD_data_ready;
	wire [7:0] RxD_data;
	reg [7:0] GPout;

	async_receiver RX(
		.clk(w_clk), 
		.RxD(GPIO[35]), 
		.RxD_data_ready(RxD_data_ready), 
		.RxD_data(RxD_data)
	);
	
	always @(posedge w_clk) 
		if(RxD_data_ready) 
			GPout <= RxD_data;

	async_transmitter TX(
		.clk(w_clk), 
		.TxD(GPIO[33]), 
		.TxD_start(RxD_data_ready), 
		.TxD_data(RxD_data)
	);
	
	assign LEDR[7:0] = GPout;
	
	char2seg Display(
		.char(GPout),
		.HEX0(HEX0)
	);
	
endmodule

`default_nettype wire
