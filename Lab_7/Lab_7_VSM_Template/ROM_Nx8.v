
`default_nettype none

module ROM_Nx8 #
(
	parameter N = 8
)
(
	input [$clog2(N)-1:0] address,
	output reg [7:0] data
);

	(* ramstyle = "logic" *) reg [7:0] rom [0:N-1];
	
	// Initialize memory -> your asm instructions
	initial begin
		rom[0] = 8'h55;
		rom[1] = 8'h12;
		rom[2] = 8'h30;
		rom[3] = 8'h28;
		rom[4] = 8'h30;
		rom[5] = 8'h40;
		rom[6] = 8'h13;
		rom[7] = 8'h30;
		// maximum 16 instructions
	end
	
	// Combinational Logic (async)
	always @(*) begin
		case (address)
			3'd0: data = 8'h40; // IN
			3'd1: data = 8'h13; // ADD 3
			3'd2: data = 8'h30; // OUT
			3'd3: data = 8'h21; // SUB 1
			3'd4: data = 8'h30; // OUT
			3'd5: data = 8'h59; // LDA 9
			3'd6: data = 8'h30; // OUT
			3'd7: data = 8'h00; // NOP
			default: data = 8'h00;
		endcase
	end

endmodule

`default_nettype wire
