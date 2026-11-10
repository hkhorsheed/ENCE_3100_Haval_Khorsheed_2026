// tx_packet.v
// Sends packets from the FPGA to the PC (DESIGN_NOTES.md, section 6).
//
//   0xA5 | type | len | payload (len bytes) | ck_a | ck_b
//   ck_a, ck_b = Fletcher-16 (sum1, sum2) over type, len and payload
//
//   type 1  result    len 22: flags, digit, 10 x int16 scores (little endian)
//                     flags bit 0 = rows_ok, bit 1 = empty canvas; digit 0xF = none
//   type 2  ack       len 3:  status, Fletcher-16 of the received weights (LE)
//   type 3  identify  len 6:  model ID, weight_bytes (3, LE), weights_valid, baud code
//
// Requests are pulses. If several packets wait, ack goes first, then identify,
// then result.
//
// Result snapshot: on req_result the module copies the digit and the 10 scores
// (10 clocks, through score_sel). Thus the next inference cannot change a packet
// in transmission. A result request while a result packet is in transmission is
// dropped (the next frame gives a new result).
//
// Model-independent: every model gives 10 int16 scores.

`default_nettype none

module tx_packet (
	input  wire        clk,
	input  wire        rst,

	// Result (from the NN core)
	input  wire        req_result,
	input  wire [7:0]  res_flags,
	input  wire [3:0]  res_digit,
	output reg  [3:0]  score_sel,
	input  wire [15:0] score,

	// Ack (from the weight loader)
	input  wire        req_ack,
	input  wire [2:0]  ack_status,
	input  wire [15:0] ack_checksum,

	// Identify
	input  wire        req_identify,
	input  wire [7:0]  id_model,
	input  wire [23:0] id_weight_bytes,
	input  wire        id_weights_valid,
	input  wire [7:0]  id_baud_code,

	// To async_transmitter
	output reg         tx_start,
	output reg  [7:0]  tx_data,
	input  wire        tx_busy
);

	// ------------------------------------------------------------
	// Request capture
	// ------------------------------------------------------------
	reg        pend_result, pend_ack, pend_id;
	reg        capturing;
	reg [3:0]  cap_i;
	reg [7:0]  r_flags;
	reg [3:0]  r_digit;
	reg [15:0] r_score [0:9];
	reg [2:0]  a_status;
	reg [15:0] a_checksum;
	reg        i_valid;

	// ------------------------------------------------------------
	// Send FSM
	// ------------------------------------------------------------
	localparam [1:0] T_IDLE = 2'd0, T_BYTE = 2'd1, T_WAIT = 2'd2;
	reg [1:0] state;
	reg [7:0] ptype;                     // packet type being sent
	reg [7:0] plen;                      // payload length
	reg [7:0] i;                         // byte index in the packet
	reg [7:0] f1, f2;                    // Fletcher sums

	wire sending_result = (state != T_IDLE) && (ptype == 8'd1);

	// Payload byte p of the current packet
	wire [7:0] p = i - 8'd3;
	reg  [7:0] payload_byte;
	always @(*) begin
		payload_byte = 8'h00;
		case (ptype)
			8'd1: begin
				if      (p == 8'd0) payload_byte = r_flags;
				else if (p == 8'd1) payload_byte = {4'd0, r_digit};
				else if (p[0] == 1'b0) payload_byte = r_score[(p - 8'd2) >> 1][7:0];     // low byte
				else                   payload_byte = r_score[(p - 8'd2) >> 1][15:8];    // high byte
			end
			8'd2: case (p)
				8'd0: payload_byte = {5'd0, a_status};
				8'd1: payload_byte = a_checksum[7:0];
				8'd2: payload_byte = a_checksum[15:8];
				default: payload_byte = 8'h00;
			endcase
			8'd3: case (p)
				8'd0: payload_byte = id_model;
				8'd1: payload_byte = id_weight_bytes[7:0];
				8'd2: payload_byte = id_weight_bytes[15:8];
				8'd3: payload_byte = id_weight_bytes[23:16];
				8'd4: payload_byte = {7'd0, i_valid};
				8'd5: payload_byte = id_baud_code;
				default: payload_byte = 8'h00;
			endcase
			default: payload_byte = 8'h00;
		endcase
	end

	// Byte i of the packet
	reg [7:0] packet_byte;
	always @(*) begin
		if      (i == 8'd0)        packet_byte = 8'hA5;
		else if (i == 8'd1)        packet_byte = ptype;
		else if (i == 8'd2)        packet_byte = plen;
		else if (i == plen + 8'd3) packet_byte = f1;          // ck_a
		else if (i == plen + 8'd4) packet_byte = f2;          // ck_b
		else                       packet_byte = payload_byte;
	end

	// Fletcher-16 step
	wire [8:0] f1_add = {1'b0, f1} + {1'b0, packet_byte};
	wire [7:0] f1_new = (f1_add >= 9'd255) ? (f1_add - 9'd255) : f1_add[7:0];
	wire [8:0] f2_add = {1'b0, f2} + {1'b0, f1_new};
	wire [7:0] f2_new = (f2_add >= 9'd255) ? (f2_add - 9'd255) : f2_add[7:0];
	wire       in_checksum = (i >= 8'd1) && (i <= plen + 8'd2);    // type, len, payload

	always @(posedge clk) begin
		if (rst) begin
			pend_result <= 1'b0;
			pend_ack    <= 1'b0;
			pend_id     <= 1'b0;
			capturing   <= 1'b0;
			score_sel   <= 4'd0;
			state       <= T_IDLE;
			tx_start    <= 1'b0;
			ptype       <= 8'd0;
		end else begin
			// ---- capture requests ----
			if (req_ack) begin
				pend_ack   <= 1'b1;
				a_status   <= ack_status;
				a_checksum <= ack_checksum;
			end
			if (req_identify) begin
				pend_id <= 1'b1;
				i_valid <= id_weights_valid;
			end
			if (req_result && !capturing && !sending_result) begin
				capturing <= 1'b1;
				cap_i     <= 4'd0;
				score_sel <= 4'd0;
				r_flags   <= res_flags;
				r_digit   <= res_digit;
			end else if (capturing) begin
				r_score[cap_i] <= score;              // score belongs to score_sel = cap_i
				if (cap_i == 4'd9) begin
					capturing   <= 1'b0;
					pend_result <= 1'b1;
				end else begin
					cap_i     <= cap_i + 1'b1;
					score_sel <= cap_i + 1'b1;
				end
			end

			// ---- send ----
			tx_start <= 1'b0;
			case (state)
				T_IDLE: begin
					i  <= 8'd0;
					f1 <= 8'd0;
					f2 <= 8'd0;
					if (pend_ack) begin
						pend_ack <= 1'b0; ptype <= 8'd2; plen <= 8'd3;  state <= T_BYTE;
					end else if (pend_id) begin
						pend_id  <= 1'b0; ptype <= 8'd3; plen <= 8'd6;  state <= T_BYTE;
					end else if (pend_result && !capturing) begin
						pend_result <= 1'b0; ptype <= 8'd1; plen <= 8'd22; state <= T_BYTE;
					end
				end

				T_BYTE: if (!tx_busy) begin
					tx_data  <= packet_byte;
					tx_start <= 1'b1;
					if (in_checksum) begin
						f1 <= f1_new;
						f2 <= f2_new;
					end
					i     <= i + 1'b1;
					state <= T_WAIT;
				end

				T_WAIT:                              // tx_start is high now; busy rises next clock
					state <= (i == plen + 8'd5) ? T_IDLE : T_BYTE;

				default: state <= T_IDLE;
			endcase
		end
	end

endmodule

`default_nettype wire
