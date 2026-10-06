module main(
	// Pinout Assignment
	input		[9:0]		SW,
	output	[9:0]		LEDR
);

	//Unsigned
	wire [3:0] A = SW[3:0];
	wire [3:0] A = SW[7:4];
	wire [3:0] Sum;
	wire Cout;
	
	assign {Cout,Sum} = A + B;
	
	assign LEDR[3:0] = Sum;
	assign LEDR[4] = Cout;
	
	//Signed
	wire signed [3:0] A = SW[3:0];
	wire signed [3:0] A = SW[7:4];
	wire [3:0] Sum;
	wire Cout;
	
	assign {Cout,Sum} = A + B;
	
	assign LEDR[3:0] = Sum;
	assign LEDR[4] = Cout;
	
	//Unsigned/Signed multiplication
	assign P = A * B;
	
	assign LEDR[7:0] = P;
	
	//Unsigned/Signed Division
	assign D = A / B;
	
	assign LEDR[7:0] = Div;

endmodule
