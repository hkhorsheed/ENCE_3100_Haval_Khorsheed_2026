
`default_nettype none

module InstructionReg #
(
	parameter N = 4
)
(
	input MainClock,
	input ClearInstr,
	input LatchInstr,
	input EnableInstr,
	input [N-1:0] Data,
	input [N-1:0] Instr,
	output reg [N-1:0] ToInstr,
	output [N-1:0] IB_BUS
);

	reg [N-1: 0] r_data;
	
	// Sequential Logic
	always @(posedge MainClock) begin 
		if(ClearInstr) begin 
			ToInstr <= {N{1'b0}};
			r_data <= {N{1'b0}};
		end
		else begin 
			if(LatchInstr) begin 
				ToInstr <= Instr;
				r_data <= Data;
			end
		end
	end
	
	// Combinational Logic
	assign IB_BUS = (EnableInstr) ? r_data : {N{1'bz}};
	
endmodule

`default_nettype wire
