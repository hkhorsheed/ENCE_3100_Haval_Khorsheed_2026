
`default_nettype none

module main(
	input		MAX10_CLK1_50,
	input		[1:0]		KEY,
	input		[9:0]		SW,
	inout		[35:0] 	GPIO,
	output	[9:0]		LEDR,
	output	[7:0]		HEX0,
	output	[7:0]		HEX1,
	output	[7:0]		HEX2,
	output	[7:0]		HEX4,
	output	[7:0]		HEX5
);

	localparam N = 4;

	// User Wires
	// ------------------------------
	// KEY1 clock with debounce
	reg [1:0] key_sync = 2'b11;
	reg key_stable = 1'b1;
	reg [19:0] debounce_count = 20'd0;

	always @(posedge MAX10_CLK1_50) begin
		key_sync <= {key_sync[0], KEY[1]};

		if (key_sync[1] == key_stable) begin
        debounce_count <= 20'd0;
		end
		else if (debounce_count == 20'd999_999) begin
        key_stable <= key_sync[1];
        debounce_count <= 20'd0;
		end
		else begin
        debounce_count <= debounce_count + 20'd1;
		end
	end

	wire w_clock = ~key_stable;
	wire w_reset = SW[8];
	
	wire [N-1:0] w_user_input = SW[3:0];
	
	wire w_carry;
	assign LEDR[9] = w_carry;
	
	wire [N-1:0] w_rOut;
	assign LEDR[3:0] = w_rOut;
	
	// DEBUG
	//assign LEDR[7:4] = w_AluA;
	
	// ------------------------------
	
	// Internal Wires
	// ------------------------------
	wire [N-1:0] w_IB_BUS;
	wire [N-1:0] w_AluA;
	wire [N-1:0] w_AluB;
	
	wire [N-1:0] w_counter;
	wire [N-1:0] w_data;
	wire [N-1:0] w_instruction;
	
	// ------------------------------
	
	// FSM CONTROL Wires
	// ------------------------------
	wire w_LatchA;
	wire w_EnableA;
	wire w_LatchB;
	wire w_EnableALU;
	wire w_AddSub;
	wire w_EnableIN;
	wire w_EnableOut;
	wire w_LoadInstr;
	wire w_EnableInstr;
	wire [N-1:0] w_ToInstr;
	wire w_ProgCount;
	wire w_EnableCount;
	// ------------------------------
	
	// Accumulator A (default 4bits)
	Accumulator_A AccA(
		.MainClock(w_clock),
		.ClearA(w_reset),
		.LatchA(w_LatchA),  		// FSM CONTROL
		.EnableA(w_EnableA),  	// FSM CONTROL
		.A(w_IB_BUS),
		.IB_BUS(w_IB_BUS),
		.AluA(w_AluA)
	);
	
	seg7Decoder SEG1(
		.i_bin(w_AluA),
		.o_HEX(HEX1)
	);
	
	// Accumulator B (default 4bits)
	Accumulator_B AccB (
		.MainClock(w_clock),
		.ClearB(w_reset),
		.LatchB(w_LatchB),  // FSM CONTROL
		.B(w_IB_BUS),
		.AluB(w_AluB)
	);
	
	seg7Decoder SEG2(
		.i_bin(w_AluB),
		.o_HEX(HEX2)
	);
	
	// ALU (default 4bits)
	Arithmetic_Unit ALU (
		.EnableALU(w_EnableALU),  	// FSM CONTROL
		.AddSub(w_AddSub),  			// FSM CONTROL
		.A(w_AluA),
		.B(w_AluB),
		.Carry(w_carry),
		.IB_ALU(w_IB_BUS)
	);
	
	seg7Decoder SEG0(
		.i_bin(w_IB_BUS),
		.o_HEX(HEX0)
	);
	
	// Input Register (default 4bits)
	InRegister InReg(
		.EnableIN(w_EnableIN),  // FSM CONTROL
		.DataIn(w_user_input),
		.IB_BUS(w_IB_BUS)
	);
	
	seg7Decoder SEG4(
		.i_bin(w_user_input),
		.o_HEX(HEX4)
	);
	
	// Output Register (default 4bits)
	OutRegister OutReg(
		.MainClock(w_clock),
		.MainReset(w_reset),
		.EnableOut(w_EnableOut),  // FSM CONTROL
		.IB_BUS(w_IB_BUS),
		.rOut(w_rOut)
	);
	
	seg7Decoder SEG5(
		.i_bin(w_rOut),
		.o_HEX(HEX5)
	);
	
	// Instruction Register (default 4bits)
	InstructionReg InstrReg(
		.MainClock(w_clock),
		.ClearInstr(w_reset),
		.LatchInstr(w_LoadInstr),  	// FSM CONTROL
		.EnableInstr(w_EnableInstr), 	// FSM CONTROL 
		.Data(w_data),
		.Instr(w_instruction),
		.ToInstr(w_ToInstr),
		.IB_BUS(w_IB_BUS)
	);
	
	// Program Counter (default 4bits)
	ProgramCounter ProgCounter (
		.MainClock(w_clock),
		.EnableCount(w_EnableCount),  // FSM CONTROL
		.ClearCounter(w_reset),
		.Counter(w_counter)
	);
	
	// Memory ROM 8x8
	
	wire [7:0] w_rom_data;
	
	ROM_Nx8 ROM (
		.address(w_counter[2:0]),
		.data(w_rom_data)
	);
	
	assign {w_instruction, w_data} = w_rom_data;
	
	// Microinstructions (FSM)
	FSM_MicroInstr Controller (
		.clk(w_clock),
		.reset(w_reset),
		.IB_BUS(w_IB_BUS),		
		.LatchA(w_LatchA),
		.EnableA(w_EnableA),
		.LatchB(w_LatchB),
		.EnableALU(w_EnableALU),
		.AddSub(w_AddSub),
		.EnableIN(w_EnableIN),
		.EnableOut(w_EnableOut),
		.LoadInstr(w_LoadInstr),
		.EnableInstr(w_EnableInstr),
		.ToInstr(w_ToInstr),
		.EnableCount(w_EnableCount)
	);

endmodule

`default_nettype wire
