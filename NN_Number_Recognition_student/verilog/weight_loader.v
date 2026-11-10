// weight_loader.v
// Program mode: receives a weight upload and writes it into the NN core
// (DESIGN_NOTES.md, section 5.2).
//
// Bytes after 0xF0:
//   model ID (1) | length (3, little endian) | payload (length bytes) | Fletcher-16 (2, LE)
//
// - The loader writes payload byte i to core address i. It does not know what the
//   bytes mean, so it works for every model.
// - Wrong model ID or wrong length: the loader still reads "length" bytes and the
//   checksum (so the PC and the FPGA stay in step), but it writes nothing.
// - Timeout: if no byte arrives for TIMEOUT_CYCLES clocks, the upload stops.
// - weights_valid goes to 0 at the start of an upload, and to 1 only after a
//   correct upload.
//
// Status codes: 0 = OK, 1 = wrong model ID, 2 = wrong length, 3 = wrong checksum,
//               4 = timeout
//
// Fletcher-16: sum1 = sum of the bytes mod 255, sum2 = sum of the sum1 values mod 255,
// checksum = {sum2, sum1}. Each sum is at most 254 + 255 = 509, so one
// "subtract 255" step is enough.

`default_nettype none

module weight_loader #(
	parameter TIMEOUT_CYCLES = 5000000       // 100 ms at 50 MHz
)(
	input  wire        clk,
	input  wire        rst,

	input  wire        start,               // pulse: 0xF0 received
	input  wire        byte_valid,
	input  wire [7:0]  byte_data,

	input  wire [7:0]  model_id,            // from the NN core
	input  wire [23:0] weight_bytes,

	output wire        busy,                // program mode

	// Write port to the NN core
	output reg  [17:0] w_wr_addr,
	output reg  [7:0]  w_wr_data,
	output reg         w_wr_en,

	// Result
	output reg         done,                // pulse: upload finished (OK or not)
	output reg  [2:0]  status,
	output reg  [15:0] checksum,            // Fletcher-16 of the received payload
	output reg         weights_valid,

	// Progress (for the LEDs)
	output reg  [23:0] count,
	output reg  [23:0] length
);

	localparam [2:0] L_IDLE = 3'd0, L_ID   = 3'd1, L_LEN0 = 3'd2, L_LEN1 = 3'd3,
	                 L_LEN2 = 3'd4, L_DATA = 3'd5, L_CK0  = 3'd6, L_CK1  = 3'd7;

	reg [2:0]  state;
	reg [7:0]  f1, f2;                      // Fletcher sums
	reg [7:0]  ck_lo;
	reg [23:0] idle_cnt;

	assign busy = (state != L_IDLE);

	// Fletcher-16 step for the current byte
	wire [8:0] f1_add = {1'b0, f1} + {1'b0, byte_data};
	wire [7:0] f1_new = (f1_add >= 9'd255) ? (f1_add - 9'd255) : f1_add[7:0];
	wire [8:0] f2_add = {1'b0, f2} + {1'b0, f1_new};
	wire [7:0] f2_new = (f2_add >= 9'd255) ? (f2_add - 9'd255) : f2_add[7:0];

	wire [23:0] new_length = {byte_data, length[15:0]};
	wire        ck_match   = ({byte_data, ck_lo} == {f2, f1});
	wire [2:0]  final_status = (status != 3'd0) ? status : (ck_match ? 3'd0 : 3'd3);

	always @(posedge clk) begin
		if (rst) begin
			state         <= L_IDLE;
			done          <= 1'b0;
			w_wr_en       <= 1'b0;
			weights_valid <= 1'b0;
			status        <= 3'd0;
			checksum      <= 16'd0;
			count         <= 24'd0;
			length        <= 24'd0;
		end else begin
			done    <= 1'b0;
			w_wr_en <= 1'b0;

			if (state == L_IDLE) begin
				if (start) begin
					state         <= L_ID;
					weights_valid <= 1'b0;
					status        <= 3'd0;
					f1            <= 8'd0;
					f2            <= 8'd0;
					count         <= 24'd0;
					length        <= 24'd0;
					idle_cnt      <= 24'd0;
				end

			end else if (!byte_valid) begin
				// Timeout
				idle_cnt <= idle_cnt + 1'b1;
				if (idle_cnt == TIMEOUT_CYCLES - 1) begin
					status   <= 3'd4;
					checksum <= {f2, f1};
					done     <= 1'b1;
					state    <= L_IDLE;
				end

			end else begin
				idle_cnt <= 24'd0;
				case (state)
					L_ID: begin
						if (byte_data != model_id) status <= 3'd1;
						state <= L_LEN0;
					end
					L_LEN0: begin length[7:0]  <= byte_data; state <= L_LEN1; end
					L_LEN1: begin length[15:8] <= byte_data; state <= L_LEN2; end
					L_LEN2: begin
						length[23:16] <= byte_data;
						if (status == 3'd0 && new_length != weight_bytes) status <= 3'd2;
						state <= (new_length == 24'd0) ? L_CK0 : L_DATA;
					end
					L_DATA: begin
						if (status == 3'd0) begin          // header OK: write to the core
							w_wr_en   <= 1'b1;
							w_wr_addr <= count[17:0];
							w_wr_data <= byte_data;
						end
						f1    <= f1_new;
						f2    <= f2_new;
						count <= count + 1'b1;
						if (count == length - 1'b1) state <= L_CK0;
					end
					L_CK0: begin ck_lo <= byte_data; state <= L_CK1; end
					L_CK1: begin
						status        <= final_status;
						checksum      <= {f2, f1};
						weights_valid <= (final_status == 3'd0);
						done          <= 1'b1;
						state         <= L_IDLE;
					end
					default: state <= L_IDLE;
				endcase
			end
		end
	end

endmodule

`default_nettype wire
