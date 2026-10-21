module FSM_Moore(
	input clk,
	input reset,
	input w,
	output Y
);

	reg [1:0] state, next_state;

	// States
	localparam [1:0] A = 2'b00, B = 2'b01, C = 2'b10; 

	// 1. State Register (sequential)
	always @(posedge clk) begin
		if(reset)
			state <= A;
		else
			state <= next_state;
	end
	
	// 2. Next-State Logic (combinational)
	always @(*) begin
		
		next_state = A; // default
	
		case(state)
			A: next_state = w ? B : C;
			B: next_state = w ? A : C;
			C: next_state = w ? B : C;
		endcase
	end
	
	// 3. Output Logic (combinational)
	
	assign Y = (state == C);

endmodule
