
`default_nettype none

module Arithmetic_Unit #
(
	parameter N = 4
)
(
	input EnableALU,
	input AddSub,
	input [N-1:0] A,
	input [N-1:0] B,
	output reg Carry,
	output reg [N-1:0] IB_ALU
);

	always @(*) begin 
		if(EnableALU) begin 
			if(AddSub) begin 
				// Sub
				{Carry, IB_ALU} = A - B;
			end
			else begin 
				// Sub
				{Carry, IB_ALU} = B + A;
			end
		end
		else begin
			IB_ALU = {N{1'bz}};
			Carry = 1'b0;
		end
	end

endmodule

`default_nettype wire
