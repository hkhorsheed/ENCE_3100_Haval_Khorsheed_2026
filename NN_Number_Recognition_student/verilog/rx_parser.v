// rx_parser.v
// Decodes the bytes from the PC (DESIGN_NOTES.md, section 5).
//
// Run mode (prog_mode = 0):
//   0x00..0x7F   pixel of the current row (28 pixels follow each row header)
//   0x80..0x9B   row header, rows 0..27. A row header always restarts the row.
//   0xF0         start of a weight upload  -> load_start pulse
//   0xF1         identify                  -> identify_req pulse
//   other bytes with bit 7 = 1: reserved. They stop the current row.
//
//   Row 0 starts a new frame. When row 27 is complete, frame_done pulses, and
//   rows_ok tells if rows 0..26 also arrived in this frame.
//
// Program mode (prog_mode = 1, the weight loader is active):
//   every byte goes to the weight loader (load_valid, load_data), because a weight
//   byte can have any value.
//
// Model-independent: the image is always 28 x 28 pixels.

`default_nettype none

module rx_parser (
	input  wire       clk,
	input  wire       rst,

	input  wire       rx_valid,          // from async_receiver
	input  wire [7:0] rx_data,
	input  wire       prog_mode,         // weight loader is active

	// Frame buffer write port
	output reg        fb_wr_en,
	output reg  [9:0] fb_wr_addr,        // row * 28 + column
	output reg  [6:0] fb_wr_data,
	output reg        frame_done,        // pulse: row 27 complete
	output reg        rows_ok,           // valid with frame_done

	// Commands
	output reg        load_start,        // pulse: 0xF0
	output reg        identify_req,      // pulse: 0xF1

	// Bytes for the weight loader (program mode)
	output reg        load_valid,
	output reg  [7:0] load_data
);

	reg        row_active;               // 1 = pixels of a row are expected
	reg  [4:0] row;
	reg  [4:0] col;
	reg  [9:0] row_base;                 // row * 28
	reg [27:0] rows_seen;                // one bit for each complete row in this frame

	wire is_pixel  = (rx_data[7] == 1'b0);
	wire is_header = (rx_data >= 8'h80) && (rx_data <= 8'h9B);

	always @(posedge clk) begin
		if (rst) begin
			row_active   <= 1'b0;
			rows_seen    <= 28'd0;
			fb_wr_en     <= 1'b0;
			frame_done   <= 1'b0;
			rows_ok      <= 1'b0;
			load_start   <= 1'b0;
			identify_req <= 1'b0;
			load_valid   <= 1'b0;
		end else begin
			fb_wr_en     <= 1'b0;            // pulses: default 0
			frame_done   <= 1'b0;
			load_start   <= 1'b0;
			identify_req <= 1'b0;
			load_valid   <= 1'b0;

			if (rx_valid) begin
				if (prog_mode) begin
					load_valid <= 1'b1;
					load_data  <= rx_data;

				end else if (is_pixel) begin
					if (row_active) begin
						fb_wr_en   <= 1'b1;
						fb_wr_addr <= row_base + col;
						fb_wr_data <= rx_data[6:0];
						if (col == 5'd27) begin
							row_active     <= 1'b0;
							rows_seen[row] <= 1'b1;
							if (row == 5'd27) begin
								frame_done <= 1'b1;
								rows_ok    <= &rows_seen[26:0];
							end
						end else
							col <= col + 1'b1;
					end                      // a pixel without a row header is ignored

				end else if (is_header) begin
					row        <= rx_data[4:0];
					col        <= 5'd0;
					row_base   <= {5'd0, rx_data[4:0]} * 10'd28;
					row_active <= 1'b1;
					if (rx_data[4:0] == 5'd0)
						rows_seen <= 28'd0;      // row 0 starts a new frame

				end else begin
					row_active <= 1'b0;          // a command or reserved byte stops the row
					if (rx_data == 8'hF0) load_start   <= 1'b1;
					if (rx_data == 8'hF1) identify_req <= 1'b1;
				end
			end
		end
	end

endmodule

`default_nettype wire
