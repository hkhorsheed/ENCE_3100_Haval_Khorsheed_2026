
`default_nettype none

module Accumulator_B #
(
	parameter N = 4
)
(
	input MainClock,
	input ClearB,
	input LatchB,
	input [N-1:0] B,
	output reg [N-1:0] AluB
);

	always @(posedge MainClock) begin 
		if(ClearB)
			AluB <= {N{1'b0}};
		else
			if(LatchB)
				AluB <= B;
	end

endmodule

`default_nettype wire
