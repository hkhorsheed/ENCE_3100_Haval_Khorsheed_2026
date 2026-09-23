module main(
	input [9:0] SW,
	output [9:0] LEDR,
	
	input 	MAX10_CLK1_50,
	output	[7:0]		HEX0,
	output	[7:0]		HEX1,
	output	[7:0]		HEX2,
	output	[7:0]		HEX3,
	output	[7:0]		HEX4,
	output	[7:0]		HEX5
);

	//assign LEDR[9:0] = SW[9:0];
	
	// PART II
	wire [7:0] part2_hex0;
	wire [7:0] part2_hex1;
	
	wire [3:0] w_m;
	
	// 7 Segment Display 
	Seg7_Decoder D0(
		.m(w_m), // 4bits
		.out(part2_hex0)  // 8bits
	);
	
	wire w_z;
	//assign w_z = SW[9];
	
	
	wire [2:0] w_ca;
	// MUltiplexers
	mux_2_1 M0(
		.s(w_z),
		.x(SW[0]),
		.y(w_ca[0]),
		.m(w_m[0])
	);

	mux_2_1 M1(
		.s(w_z),
		.x(SW[1]),
		.y(w_ca[1]),
		.m(w_m[1])
	);
	
	mux_2_1 M2(
		.s(w_z),
		.x(SW[2]),
		.y(w_ca[2]),
		.m(w_m[2])
	);
	
	mux_2_1 M3(
		.s(w_z),
		.x(SW[3]),
		.y(1'b0),
		.m(w_m[3])
	);
	
	// Circuit A
	CircuitA CA(
		.v({SW[2], SW[1], SW[0]}),
		.out(w_ca)
	);
	
	// Comparator
	Comparator myC(
		.v({SW[3], SW[2], SW[1], SW[0]}),
		.z(w_z)	
	);
	
	// Circuit B
	CircuitB CB(
		.z(w_z),
		.s(part2_hex1)
	);
	
	//Part III
	wire [3:0] A;
   wire [3:0] B;
   wire [3:0] S;

   wire c1;
   wire c2;
   wire c3;
   wire cout;

   assign A = SW[7:4];
   assign B = SW[3:0];
	 
	// Full Adders
	FullAdder FA0(
   .a(A[0]),
   .b(B[0]),
   .ci(SW[8]),
   .s(S[0]),
   .co(c1)
	);

	FullAdder FA1(
   .a(A[1]),
   .b(B[1]),
   .ci(c1),
   .s(S[1]),
   .co(c2)
	);

	FullAdder FA2(
   .a(A[2]),
   .b(B[2]),
   .ci(c2),
   .s(S[2]),
   .co(c3)
	);

	FullAdder FA3(
   .a(A[3]),
   .b(B[3]),
   .ci(c3),
   .s(S[3]),
   .co(cout)
	);
	
	// Display Part III result on LEDs
	assign LEDR[3:0] = S;
	assign LEDR[4] = cout;
	
	// PART IV
	wire [4:0] binary_sum;
	wire [3:0] S0;
	wire [3:0] S1;
	wire bcd_carry;
	
	wire [7:0] part4_hex0;
	wire [7:0] part4_hex1;

	assign binary_sum = {cout, S};

	assign bcd_carry = binary_sum[4] | (binary_sum[3] & binary_sum[2]) | (binary_sum[3] & binary_sum[1]);

	assign S1 = {3'b000, bcd_carry};

	assign S0 = bcd_carry ? (binary_sum[3:0] + 4'b0110) : binary_sum[3:0];
	
	// Display BCD result
	Seg7_Decoder D1(
		.m(S0),
		.out(part4_hex0)
	);

	Seg7_Decoder D2(
		.m(S1),
		.out(part4_hex1)
	);
	
	Seg7_Decoder D3(
		.m(A),
		.out(HEX5)
	);

	Seg7_Decoder D4(
		.m(B),
		.out(HEX4)
	);
	
	// Check for invalid BCD inputs
	wire A_error;
	wire B_error;
	wire bcd_error;

	assign A_error = A[3] & (A[2] | A[1]);
	assign B_error = B[3] & (B[2] | B[1]);

	assign bcd_error = A_error | B_error;

	assign LEDR[9] = bcd_error;
	
	// PART V
	wire [3:0] A0;
	wire [3:0] A1;
	wire [3:0] B0;
	wire [3:0] B1;

	wire [3:0] part5_S0;
	wire [3:0] part5_S1;
	wire part5_carry;
	wire part5_S2;
	
	// Add ones digits
	BCDAdder BA0(
		.A(A0),
		.B(B0),
		.cin(1'b0),
		.S0(part5_S0),
		.S1(part5_carry)
	);

	// Add tens digits
	BCDAdder BA1(
		.A(A1),
		.B(B1),
		.cin(part5_carry),
		.S0(part5_S1),
		.S1(part5_S2)
	);
	
	// Test values for Part V
	assign A1 = 4'b0101;  // 5
	assign A0 = 4'b1001;  // 9

	assign B1 = 4'b0010;  // 2
	assign B0 = 4'b0100;  // 4
	
	// Display Part V result
	Seg7_Decoder D5(
		.m(part5_S0),
		.out(HEX0)
	);

	Seg7_Decoder D6(
		.m(part5_S1),
		.out(HEX1)
	);

	Seg7_Decoder D7(
		.m({3'b000, part5_S2}),
		.out(HEX2)
	); 
endmodule
