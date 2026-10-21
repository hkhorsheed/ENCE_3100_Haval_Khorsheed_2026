module ram32x8_lut (
	input 				clk,
	input 				we,
	input 		[4:0] addr,
	input 		[7:0] din,
	output reg 	[7:0] dout
);

	(* ramstyle = "logic" *) reg [7:0] mem [0:31];
	
	always @(posedge clk) begin 
		if(we)
			mem[addr] <= din;
			
		dout <= mem[addr];
	end

endmodule