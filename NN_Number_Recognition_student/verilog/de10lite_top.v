// de10lite_top.v
// NN Number Recognition on the DE10-Lite (DESIGN_NOTES.md, sections 3 and 8).
//
//   PC --UART--> rx_parser --run mode-----> frame_buffer --> NN core --> tx_packet --UART--> PC
//                          --program mode-> weight_loader --^               |
//                                                                     status_display -> HEX, LEDR
//
// Wires (USB-serial adapter, 3.3 V):
//   UART_RXD = GPIO[35] (PIN_AA2) <- adapter TX
//   UART_TXD = GPIO[33] (PIN_Y3)  -> adapter RX
//   GND to GND
// KEY[0] = reset. After a reset the FPGA has no weights; the GUI uploads them.
//
// To add a model: write its core with the same ports as nn_core_mlp_784_32_10,
// add a branch to the generate block below, and set MODEL.

`default_nettype none

module de10lite_top #(
	parameter CLK_HZ          = 50000000,
	parameter BAUD            = 921600,
	parameter MODEL           = 1,            // 1 = MLP 784-32-10
	parameter TIMEOUT_CYCLES  = 5000000,      // upload timeout: 100 ms
	parameter SHOW_CYCLES     = 150000000,    // show the upload result for 3 s
	parameter EMPTY_THRESHOLD = 1270          // pixel sum below this = empty canvas (10 full pixels)
)(
	input  wire       MAX10_CLK1_50,
	input  wire [1:0] KEY,
	output wire [9:0] LEDR,
	output wire [7:0] HEX0,
	output wire [7:0] HEX1,
	output wire [7:0] HEX2,
	output wire [7:0] HEX3,
	output wire [7:0] HEX4,
	output wire [7:0] HEX5,
	input  wire       UART_RXD,
	output wire       UART_TXD
);

	wire clk = MAX10_CLK1_50;

	// ------------------------------------------------------------
	// Reset: KEY[0] (active low), synchronized
	// ------------------------------------------------------------
	reg [1:0] key_sync = 2'b00;
	always @(posedge clk) key_sync <= {key_sync[0], KEY[0]};
	wire rst = ~key_sync[1];

	// ------------------------------------------------------------
	// UART (fpga4fun, unchanged)
	// ------------------------------------------------------------
	wire       rx_valid;
	wire [7:0] rx_data;
	wire       tx_start, tx_busy;
	wire [7:0] tx_data;

	async_receiver #(.ClkFrequency(CLK_HZ), .Baud(BAUD)) uart_rx (
		.clk(clk), .RxD(UART_RXD), .RxD_data_ready(rx_valid), .RxD_data(rx_data),
		.RxD_idle(), .RxD_endofpacket()
	);

	async_transmitter #(.ClkFrequency(CLK_HZ), .Baud(BAUD)) uart_tx (
		.clk(clk), .TxD_start(tx_start), .TxD_data(tx_data), .TxD(UART_TXD), .TxD_busy(tx_busy)
	);

	localparam [7:0] BAUD_CODE = (BAUD == 115200) ? 8'd0 : (BAUD == 230400) ? 8'd1 :
	                             (BAUD == 460800) ? 8'd2 : (BAUD == 921600) ? 8'd3 : 8'hFF;

	// ------------------------------------------------------------
	// Parser
	// ------------------------------------------------------------
	wire       fb_wr_en, frame_done, rows_ok;
	wire [9:0] fb_wr_addr;
	wire [6:0] fb_wr_data;
	wire       load_start, identify_req, load_valid;
	wire [7:0] load_data;
	wire       loading;

	rx_parser parser (
		.clk(clk), .rst(rst),
		.rx_valid(rx_valid), .rx_data(rx_data), .prog_mode(loading),
		.fb_wr_en(fb_wr_en), .fb_wr_addr(fb_wr_addr), .fb_wr_data(fb_wr_data),
		.frame_done(frame_done), .rows_ok(rows_ok),
		.load_start(load_start), .identify_req(identify_req),
		.load_valid(load_valid), .load_data(load_data)
	);

	// ------------------------------------------------------------
	// NN core (selected by MODEL)
	// ------------------------------------------------------------
	wire [17:0] w_wr_addr;
	wire [7:0]  w_wr_data;
	wire        w_wr_en;
	wire [9:0]  px_addr;
	wire [6:0]  px_data;
	reg         core_start;
	wire        core_busy, core_done;
	wire [3:0]  core_digit;
	wire [3:0]  score_sel;
	wire [15:0] score;
	wire [7:0]  model_id;
	wire [23:0] weight_bytes;

	generate
		if (MODEL == 1) begin : core
			nn_core_mlp_784_32_10 nn (
				.clk(clk), .rst(rst),
				.w_wr_addr(w_wr_addr), .w_wr_data(w_wr_data), .w_wr_en(w_wr_en),
				.px_addr(px_addr), .px_data(px_data),
				.start(core_start), .busy(core_busy), .done(core_done),
				.digit(core_digit), .score_sel(score_sel), .score(score),
				.model_id(model_id), .weight_bytes(weight_bytes)
			);
		end
		// else if (MODEL == 2) begin : core  nn_core_cnn_... (same ports)  end
	endgenerate

	// ------------------------------------------------------------
	// Weight loader
	// ------------------------------------------------------------
	wire        upload_done, weights_valid;
	wire [2:0]  upload_status;
	wire [15:0] upload_checksum;
	wire [23:0] load_count, load_length;

	weight_loader #(.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) loader (
		.clk(clk), .rst(rst),
		.start(load_start), .byte_valid(load_valid), .byte_data(load_data),
		.model_id(model_id), .weight_bytes(weight_bytes),
		.busy(loading),
		.w_wr_addr(w_wr_addr), .w_wr_data(w_wr_data), .w_wr_en(w_wr_en),
		.done(upload_done), .status(upload_status), .checksum(upload_checksum),
		.weights_valid(weights_valid),
		.count(load_count), .length(load_length)
	);

	// ------------------------------------------------------------
	// Frame buffer and core start
	// A complete frame is accepted only if the weights are valid, no upload runs,
	// and the core is free. Then the banks swap and the core starts one clock later.
	// ------------------------------------------------------------
	wire        accept = frame_done && weights_valid && !loading && !core_busy && !core_start;
	wire [16:0] frame_sum;
	reg         frame_rows_ok;

	frame_buffer fbuf (
		.clk(clk), .rst(rst),
		.wr_en(fb_wr_en), .wr_addr(fb_wr_addr), .wr_data(fb_wr_data),
		.frame_end(frame_done), .accept(accept),
		.rd_addr(px_addr), .rd_data(px_data),
		.frame_sum(frame_sum)
	);

	always @(posedge clk) begin
		if (rst)
			core_start <= 1'b0;
		else
			core_start <= accept;
		if (accept)
			frame_rows_ok <= rows_ok;
	end

	// ------------------------------------------------------------
	// Result: digit, or 0xF for an empty canvas
	// ------------------------------------------------------------
	wire       empty        = (frame_sum < EMPTY_THRESHOLD);
	wire [3:0] result_digit = empty ? 4'hF : core_digit;
	wire [7:0] result_flags = {6'd0, empty, frame_rows_ok};

	// ------------------------------------------------------------
	// Packets to the PC
	// ------------------------------------------------------------
	tx_packet tx (
		.clk(clk), .rst(rst),
		.req_result(core_done), .res_flags(result_flags), .res_digit(result_digit),
		.score_sel(score_sel), .score(score),
		.req_ack(upload_done), .ack_status(upload_status), .ack_checksum(upload_checksum),
		.req_identify(identify_req), .id_model(model_id), .id_weight_bytes(weight_bytes),
		.id_weights_valid(weights_valid), .id_baud_code(BAUD_CODE),
		.tx_start(tx_start), .tx_data(tx_data), .tx_busy(tx_busy)
	);

	// ------------------------------------------------------------
	// Board display
	// ------------------------------------------------------------
	status_display #(.SHOW_CYCLES(SHOW_CYCLES)) display (
		.clk(clk), .rst(rst),
		.weights_valid(weights_valid), .loading(loading),
		.load_count(load_count), .load_length(load_length),
		.upload_done(upload_done), .upload_status(upload_status), .upload_checksum(upload_checksum),
		.result_tick(core_done), .result_digit(result_digit), .result_rows_ok(frame_rows_ok),
		.HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
		.LEDR(LEDR)
	);

endmodule

`default_nettype wire
