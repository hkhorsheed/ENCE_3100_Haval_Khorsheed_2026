// frame_buffer.v
// Two 784 x 7-bit image buffers (one M9K memory, 2 banks of 1024).
//
// The parser writes the new frame into the write bank while the NN core reads the
// last frame from the read bank. At the end of a frame (frame_end), if "accept" is
// 1, the banks change places: the new frame becomes readable.
// If "accept" is 0 (for example the core is busy), the frame is dropped and the
// next frame overwrites it.
//
// The buffer also adds up the pixels of each frame. frame_sum is the sum of the frame
// that the last accepted swap made readable (empty-canvas test, outside the core).
//
// Model-independent: the image is always 28 x 28 pixels.

`default_nettype none

module frame_buffer (
	input  wire        clk,
	input  wire        rst,

	// Write port (from rx_parser)
	input  wire        wr_en,
	input  wire [9:0]  wr_addr,
	input  wire [6:0]  wr_data,
	input  wire        frame_end,       // pulse, in the same clock as the last pixel write
	input  wire        accept,          // with frame_end: swap the banks

	// Read port (to the NN core), 1 clock read latency
	input  wire [9:0]  rd_addr,
	output reg  [6:0]  rd_data,

	output reg  [16:0] frame_sum        // 784 x 127 = 99,568 needs 17 bits
);

	reg [6:0]  mem [0:2047];
	reg        wbank;                   // write bank; the read bank is ~wbank
	reg [16:0] sum_acc;

	always @(posedge clk) begin
		if (wr_en)
			mem[{wbank, wr_addr}] <= wr_data;
		rd_data <= mem[{~wbank, rd_addr}];
	end

	wire [16:0] sum_next = sum_acc + (wr_en ? {10'd0, wr_data} : 17'd0);

	always @(posedge clk) begin
		if (rst) begin
			wbank     <= 1'b0;
			sum_acc   <= 17'd0;
			frame_sum <= 17'd0;
		end else if (frame_end) begin
			sum_acc <= 17'd0;
			if (accept) begin
				wbank     <= ~wbank;
				frame_sum <= sum_next;
			end
		end else
			sum_acc <= sum_next;
	end

endmodule

`default_nettype wire
