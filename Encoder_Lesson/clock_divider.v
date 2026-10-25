
`default_nettype none

module clock_divider #
(
	parameter integer N = 25
)
(
	input clk,
	input reset,  // synchronous, active-high
	output reg clk_div
);

	reg [$clog2(N):0] count;

	always @(posedge clk) begin
		if(reset) begin
			count <= 0; 
			clk_div <= 1'b0;
		end
		else begin
			if(count == N-1) begin
				clk_div <= ~clk_div; // toggles every N cycles
				count <= 0;
			end
			else
				count <= count + 1'b1;
		end
	end

endmodule

`default_nettype wire

