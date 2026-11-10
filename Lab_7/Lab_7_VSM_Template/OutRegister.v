
`default_nettype none

module OutRegister #
(
	parameter N = 4
)
(
	input MainClock,
	input MainReset,
	input EnableOut,
	input [N-1:0] IB_BUS,
	output reg [N-1:0] rOut
);

	always @(posedge MainClock) begin 
		if(MainReset)
		rOut <= {N{1'b0}};
		else begin 
			rOut <= IB_BUS;
		end
	end

endmodule

`default_nettype wire
