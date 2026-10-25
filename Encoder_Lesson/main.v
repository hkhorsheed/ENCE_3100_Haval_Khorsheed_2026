
`default_nettype none

module main(
	// Board I/Os
	input		MAX10_CLK1_50,
	input 	[9:0]		SW,
	output	[9:0]		LEDR,
	inout		[35:0]	GPIO,
	//output 	[7:0]		HEX0,
	inout		[15:0]	ARDUINO_IO
);

	
	wire w_clk = MAX10_CLK1_50;

	/*
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
	*/

	//assign LEDR[7:0] = GPout;
	
	wire w_TxD_start;
	
	async_transmitter TX(
		.clk(w_clk), 
		.TxD(GPIO[33]), 
		.TxD_start(w_TxD_start), 
		.TxD_data(w_TxD_data)
	);
		
	assign LEDR[9] = GPIO[2];
	
	wire [7:0] w_counter;
	reg [7:0] w_TxD_data;
	
	quad Encoder(
		.clk(w_clk), 
		.quadA(GPIO[0]), 
		.quadB(GPIO[1]), 
		.count(w_counter)
	);
	
	always @(posedge w_clk) 
		w_TxD_data <= w_counter;
	
	assign w_TxD_start = (w_counter == w_TxD_data) ? 0 : 1;
	
	assign LEDR[7:0] = w_TxD_data;
	
	/*
	wire w_clk_div;
	
	clock_divider #(.N(25)) Clock_1MHz (
		.clk(w_clk),
		.reset(SW[9]),  
		.clk_div(w_clk_div)
	);
	*/
	
endmodule

`default_nettype wire

