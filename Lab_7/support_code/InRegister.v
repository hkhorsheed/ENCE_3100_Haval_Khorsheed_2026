
`default_nettype none

module InRegister #
(
	parameter N = 4
)
(
	input EnableIN,
	input [N-1:0] DataIn,
	output [N-1:0] IB_BUS
);

	assign IB_BUS = (EnableIN) ? DataIn : {N{1'bz}};

endmodule

`default_nettype wire
