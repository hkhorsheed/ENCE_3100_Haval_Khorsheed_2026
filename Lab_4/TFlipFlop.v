module TFlipFlop (
	input T,
	input clk,
	input clear,
	output Qt
);

	wire d;
	reg q;

	// Edge Trigger Flip Flop
	always @ (posedge clk) begin 
		if (clear)
			q <= 0;
		else
			q <= d;
	end
	
	assign d = (q & ~T) | (T & ~q);
	assign Qt = q;
	
endmodule