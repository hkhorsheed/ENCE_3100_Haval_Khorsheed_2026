// nn_core_mlp_784_32_10.v
// Neural network core, model ID 1: MLP 784-32-10 (DESIGN_NOTES.md, sections 8 and 9).
//
//   28x28 pixels --> 32 hidden neurons (ReLU) --> 10 output neurons --> digit (argmax)
//
// One FSM and one datapath with ONE multiplier, as in the VSM: the FSM selects
// what the shared MAC does in each clock cycle.
//
// Bit-exact reference: int_forward() in python/models/mlp_784_32_10.py.
//   acc1   = sum(x * W1) + b1                       (x: pixel 0..127)
//   h      = sat_0_255( round_shift( max(acc1,0), s1 ) )
//   acc2   = sum(h * W2) + b2
//   digit  = first index of the largest acc2        (a tie goes to the lower digit)
//   scores = sat_int16( round_shift(acc2, s2) )      (Q8.8)
//   round_shift(a, s) = (a + (1 << (s-1))) >>> s, and a for s = 0
//
// ---------------------------------------------------------------------------
// FSM: both layers use the same states. "layer" selects the details.
//
//   IDLE --start--> BIAS_LO -> BIAS_HI -> BIAS_LOAD -> MAC (N times) -> DRAIN -> ACT --+
//                     ^                                                                |
//                     +----------------- next neuron (or next layer) <-----------------+
//                                                         after the last output -> DONE -> IDLE
//
//   BIAS_LO/HI  read the 2 bias bytes of this neuron from weight memory
//   BIAS_LOAD   acc = bias (sign-extended)
//   MAC         one multiply-add for each clock: 784 pixels (layer 0) or 32 hidden values (layer 1)
//   DRAIN       the last product is added (memories have one clock of read latency)
//   ACT         layer 0: h[n] = ReLU, shift, saturate
//               layer 1: score[m] = shift, saturate; argmax update
//
// Cycles: layer 0: 32 x (3 + 784 + 2) = 25,248; layer 1: 10 x (3 + 32 + 2) = 370.
// Total about 25,620 clocks = 0.51 ms at 50 MHz.
//
// ---------------------------------------------------------------------------
// Weight memory: the core keeps the blob bytes at the same addresses as in the
// blob (DESIGN_NOTES.md, 9.1). The loader writes byte i to address i. The bytes
// at address 0 and 1 (s1, s2) are also copied into registers.
//
//   0        s1, s2, 0, 0
//   4        W1  32 x 784 int8   (neuron 0 weights 0..783, neuron 1 ...)
//   25092    b1  32 x int16 LE
//   25156    W2  10 x 32 int8
//   25476    b2  10 x int16 LE
//   25496    end
//
// W1 and W2 are read in address order, so one pointer (w_ptr) only counts up.
// The biases also are read in address order, with a second pointer (b_ptr).

`default_nettype none

module nn_core_mlp_784_32_10 (
	input  wire               clk,
	input  wire               rst,

	// Weight write port (from the loader)
	input  wire [17:0]        w_wr_addr,
	input  wire [7:0]         w_wr_data,
	input  wire               w_wr_en,

	// Image read port (to the frame buffer), 1 clock read latency
	output wire [9:0]         px_addr,
	input  wire [6:0]         px_data,

	// Control
	input  wire               start,         // ignored while busy
	output wire               busy,
	output reg                done,          // 1-clock pulse

	// Results (valid after done)
	output reg  [3:0]         digit,
	input  wire [3:0]         score_sel,     // 0..9
	output wire signed [15:0] score,

	// Identity (constants)
	output wire [7:0]         model_id,
	output wire [23:0]        weight_bytes
);

	// ------------------------------------------------------------
	// Model constants
	// ------------------------------------------------------------
	localparam N_IN   = 784;
	localparam N_HID  = 32;
	localparam N_OUT  = 10;

	localparam [14:0] W1_BASE    = 15'd4;
	localparam [14:0] B1_BASE    = W1_BASE + N_IN * N_HID;    // 25092
	localparam [14:0] W2_BASE    = B1_BASE + 2 * N_HID;       // 25156
	localparam [14:0] B2_BASE    = W2_BASE + N_HID * N_OUT;   // 25476
	localparam [14:0] BLOB_BYTES = B2_BASE + 2 * N_OUT;       // 25496

	assign model_id     = 8'd1;
	assign weight_bytes = {9'd0, BLOB_BYTES};

	// ------------------------------------------------------------
	// FSM state and counters
	// ------------------------------------------------------------
	localparam [2:0] S_IDLE      = 3'd0,
	                 S_BIAS_LO   = 3'd1,
	                 S_BIAS_HI   = 3'd2,
	                 S_BIAS_LOAD = 3'd3,
	                 S_MAC       = 3'd4,
	                 S_DRAIN     = 3'd5,
	                 S_ACT       = 3'd6,
	                 S_DONE      = 3'd7;

	reg  [2:0]  state;
	reg         layer;          // 0: hidden layer, 1: output layer
	reg  [5:0]  neuron;         // 0..31 (layer 0) or 0..9 (layer 1)
	reg  [9:0]  idx;            // input index: 0..783 (layer 0) or 0..31 (layer 1)
	reg  [14:0] w_ptr;          // address of the next weight
	reg  [14:0] b_ptr;          // address of the next bias byte

	wire [9:0]  last_idx    = layer ? 10'd31 : 10'd783;    // N_HID-1 : N_IN-1
	wire [5:0]  last_neuron = layer ? 6'd9   : 6'd31;      // N_OUT-1 : N_HID-1

	assign busy    = (state != S_IDLE);
	assign px_addr = idx;

	// ------------------------------------------------------------
	// Weight memory (M9K): one write port, one read port, 1 clock read latency
	// ------------------------------------------------------------
	reg  [7:0]  wmem [0:BLOB_BYTES-1];
	reg  [7:0]  w_q;
	wire [14:0] w_rd_addr = (state == S_BIAS_LO || state == S_BIAS_HI) ? b_ptr : w_ptr;

	always @(posedge clk) begin
		if (w_wr_en && w_wr_addr < BLOB_BYTES)
			wmem[w_wr_addr[14:0]] <= w_wr_data;
		w_q <= wmem[w_rd_addr];
	end

	// Shifts: copied from blob bytes 0 and 1 during the upload (5 bits: 0..31)
	reg [4:0] s1, s2;
	always @(posedge clk)
		if (w_wr_en) begin
			if (w_wr_addr == 18'd0) s1 <= w_wr_data[4:0];
			if (w_wr_addr == 18'd1) s2 <= w_wr_data[4:0];
		end

	// ------------------------------------------------------------
	// Hidden values h[0..31], uint8
	// ------------------------------------------------------------
	reg [7:0] hid [0:N_HID-1];
	reg [7:0] h_q;              // h[idx], registered: same latency as the memories

	// ------------------------------------------------------------
	// MAC datapath: one 9 x 9 signed multiplier and a 32-bit accumulator
	// ------------------------------------------------------------
	reg                mac_en_d;   // 1 = the operands of the last MAC state are valid now
	reg         [7:0]  bias_lo;
	reg  signed [31:0] acc;

	// Both inputs are unsigned: pixel 0..127, h 0..255. A leading 0 makes them signed.
	wire signed [8:0]  mac_a   = layer ? {1'b0, h_q} : {2'b00, px_data};
	wire signed [8:0]  mac_b   = {w_q[7], w_q};                 // int8 weight
	wire signed [17:0] product = mac_a * mac_b;

	always @(posedge clk) begin
		if (state == S_BIAS_LOAD)
			acc <= {{16{w_q[7]}}, w_q, bias_lo};                   // int16 bias, sign-extended
		else if (mac_en_d)
			acc <= acc + {{14{product[17]}}, product};
	end

	// ------------------------------------------------------------
	// Activation: ReLU (layer 0), round_shift, saturate
	// One shifter serves both layers.
	// ------------------------------------------------------------
	wire signed [31:0] act_in  = (layer == 1'b0 && acc[31]) ? 32'sd0 : acc;     // ReLU in layer 0
	wire        [4:0]  sh      = layer ? s2 : s1;
	wire signed [32:0] half    = (sh == 5'd0) ? 33'sd0 : (33'sd1 <<< (sh - 5'd1));
	wire signed [32:0] rounded = {act_in[31], act_in} + half;            // 33 bits: no overflow
	wire signed [32:0] shifted = rounded >>> sh;

	wire [7:0] h_sat = (shifted > 33'sd255) ? 8'd255 : shifted[7:0];   // shifted >= 0 here
	wire signed [15:0] score_sat = (shifted >  33'sd32767) ? 16'sh7FFF :     // +32767
	                               (shifted < -33'sd32768) ? 16'sh8000 :     // -32768
	                                                         shifted[15:0];

	// ------------------------------------------------------------
	// Results: scores and argmax
	// ------------------------------------------------------------
	reg signed [15:0] scores [0:N_OUT-1];
	reg signed [31:0] best_acc;
	reg        [3:0]  best_digit;

	assign score = (score_sel < N_OUT) ? scores[score_sel] : 16'sd0;

	// ------------------------------------------------------------
	// FSM
	// ------------------------------------------------------------
	always @(posedge clk) begin
		if (rst) begin
			state    <= S_IDLE;
			done     <= 1'b0;
			mac_en_d <= 1'b0;
			digit    <= 4'd0;
		end else begin
			done     <= 1'b0;
			mac_en_d <= (state == S_MAC);

			case (state)
				S_IDLE: if (start) begin
					layer  <= 1'b0;
					neuron <= 6'd0;
					w_ptr  <= W1_BASE;
					b_ptr  <= B1_BASE;
					state  <= S_BIAS_LO;
				end

				S_BIAS_LO: begin                 // read address b_ptr (low byte)
					b_ptr <= b_ptr + 1'b1;
					state <= S_BIAS_HI;
				end

				S_BIAS_HI: begin                 // read address b_ptr (high byte); low byte arrives
					b_ptr   <= b_ptr + 1'b1;
					bias_lo <= w_q;
					state   <= S_BIAS_LOAD;
				end

				S_BIAS_LOAD: begin               // high byte arrives; acc <= bias (datapath)
					idx   <= 10'd0;
					state <= S_MAC;
				end

				S_MAC: begin                     // read weight w_ptr and input idx
					h_q   <= hid[idx[4:0]];
					w_ptr <= w_ptr + 1'b1;
					idx   <= idx + 1'b1;
					if (idx == last_idx)
						state <= S_DRAIN;
				end

				S_DRAIN:                         // the last product is added now
					state <= S_ACT;

				S_ACT: begin
					if (layer == 1'b0)
						hid[neuron[4:0]] <= h_sat;
					else begin
						scores[neuron[3:0]] <= score_sat;
						if (neuron == 6'd0 || acc > best_acc) begin   // strict >: a tie keeps the lower digit
							best_acc   <= acc;
							best_digit <= neuron[3:0];
						end
					end

					if (neuron != last_neuron) begin
						neuron <= neuron + 1'b1;
						state  <= S_BIAS_LO;
					end else if (layer == 1'b0) begin
						layer  <= 1'b1;                // go to the output layer
						neuron <= 6'd0;
						w_ptr  <= W2_BASE;
						b_ptr  <= B2_BASE;
						state  <= S_BIAS_LO;
					end else
						state  <= S_DONE;
				end

				S_DONE: begin
					digit <= best_digit;
					done  <= 1'b1;
					state <= S_IDLE;
				end

				default: state <= S_IDLE;
			endcase
		end
	end

endmodule

`default_nettype wire
