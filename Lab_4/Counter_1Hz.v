module Counter_1Hz(
	input in_clk,
	input clear,
	output reg out_clk
);

	reg [25:0] count;

	always @ (posedge in_clk) begin 
		if (clear) begin
			out_clk <= 0;
			count <= 26'd0;
		end
		else begin
			if (count == 26'd49_999_999) begin
				count <= 26'd0;
				out_clk <= 1;
			end
			else begin
				count <= count + 1;
				out_clk <= 0;
			end
		end
	end

endmodule