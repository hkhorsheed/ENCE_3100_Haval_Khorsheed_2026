
`default_nettype none

module ProgramCounter #
(
	parameter N = 4
)
(
	input MainClock,
	input EnableCount,
	input ClearCounter,
	output reg [N-1:0] Counter
);

	always @(posedge MainClock) begin 
		if(ClearCounter)
			Counter <= {N{1'b0}};
		else begin 
			if(EnableCount)
				Counter <= Counter + 1'b1;
		end
	end

endmodule

`default_nettype wire
