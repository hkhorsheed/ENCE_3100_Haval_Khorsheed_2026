// status_display.v
// What HEX5..HEX0 and LEDR show (DESIGN_NOTES.md, section 7).
//
//   State                       HEX5..HEX0                LEDR
//   upload in progress          "     P"                  progress bar, 1 LED for each 10%
//   upload OK (SHOW_CYCLES)     "  427b" (checksum)       all on
//   upload failed (SHOW_CYCLES) "Err  4" (status code)    off
//   no valid weights            "     -"                  off
//   run mode                    "     7" (digit)          LEDR[0] toggles for each result,
//                               "     -" (empty canvas)   LEDR[9] = rows missing in last frame

`default_nettype none

module status_display #(
	parameter SHOW_CYCLES = 150000000        // 3 s at 50 MHz
)(
	input  wire        clk,
	input  wire        rst,

	input  wire        weights_valid,
	input  wire        loading,
	input  wire [23:0] load_count,
	input  wire [23:0] load_length,
	input  wire        upload_done,          // pulse
	input  wire [2:0]  upload_status,
	input  wire [15:0] upload_checksum,

	input  wire        result_tick,          // pulse for each result
	input  wire [3:0]  result_digit,         // 0..9, 0xF = none
	input  wire        result_rows_ok,

	output wire [7:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
	output reg  [9:0]  LEDR
);

	localparam [7:0] C_BLANK = 8'd32, C_DASH = 8'd45, C_P = 8'd80, C_E = 8'd69, C_R = 8'd114;

	function [7:0] hex_ascii;                // 0..15 -> '0'..'9', 'a'..'f'
		input [3:0] nib;
		hex_ascii = (nib < 4'd10) ? (8'd48 + nib) : (8'd87 + nib);
	endfunction

	// ---- show timer for the upload result ----
	reg [27:0] show_cnt;
	reg [2:0]  last_status;
	reg [15:0] last_checksum;
	always @(posedge clk) begin
		if (rst)
			show_cnt <= 28'd0;
		else if (upload_done) begin
			show_cnt      <= SHOW_CYCLES;
			last_status   <= upload_status;
			last_checksum <= upload_checksum;
		end else if (show_cnt != 28'd0)
			show_cnt <= show_cnt - 1'b1;
	end

	// ---- last result ----
	reg [3:0] digit_r;
	reg       have_result, toggle, rows_ok_r;
	always @(posedge clk) begin
		if (rst) begin
			have_result <= 1'b0;
			toggle      <= 1'b0;
			rows_ok_r   <= 1'b1;
		end else begin
			if (result_tick) begin
				digit_r     <= result_digit;
				rows_ok_r   <= result_rows_ok;
				have_result <= 1'b1;
				toggle      <= ~toggle;
			end
			if (loading) have_result <= 1'b0;
		end
	end

	// ---- progress bar: LED k is on when count / length >= (k+1) / 10 ----
	wire [27:0] count_x10 = {load_count, 3'b000} + {3'b000, load_count, 1'b0};
	wire [9:0]  progress;
	genvar k;
	generate
		for (k = 0; k < 10; k = k + 1) begin : bar
			assign progress[k] = (count_x10 >= load_length * (k + 1));
		end
	endgenerate

	// ---- select the characters ----
	reg [7:0] c0, c1, c2, c3, c4, c5;
	always @(*) begin
		{c5, c4, c3, c2, c1, c0} = {6{C_BLANK}};
		LEDR = 10'd0;
		if (loading) begin
			c0   = C_P;
			LEDR = progress;
		end else if (show_cnt != 28'd0) begin
			if (last_status == 3'd0) begin
				c3 = hex_ascii(last_checksum[15:12]);
				c2 = hex_ascii(last_checksum[11:8]);
				c1 = hex_ascii(last_checksum[7:4]);
				c0 = hex_ascii(last_checksum[3:0]);
				LEDR = 10'h3FF;
			end else begin
				c5 = C_E; c4 = C_R; c3 = C_R;
				c0 = hex_ascii({1'b0, last_status});
			end
		end else if (!weights_valid || !have_result) begin
			c0 = C_DASH;
		end else begin
			c0      = (digit_r == 4'hF) ? C_DASH : hex_ascii(digit_r);
			LEDR[0] = toggle;
			LEDR[9] = ~rows_ok_r;
		end
	end

	char2seg d0 (.char(c0), .HEX0(HEX0));
	char2seg d1 (.char(c1), .HEX0(HEX1));
	char2seg d2 (.char(c2), .HEX0(HEX2));
	char2seg d3 (.char(c3), .HEX0(HEX3));
	char2seg d4 (.char(c4), .HEX0(HEX4));
	char2seg d5 (.char(c5), .HEX0(HEX5));

endmodule

`default_nettype wire
