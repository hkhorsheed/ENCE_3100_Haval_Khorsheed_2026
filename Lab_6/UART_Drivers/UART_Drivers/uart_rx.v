// uart_rx.v
// Verilog-2001, synthesizable
// 8 data bits, no parity, 1 stop (8N1), 16x oversampling with mid-bit sampling
// Fixes: LSB-first shift, consistent mid-bit sampling, 3-tap majority vote

module uart_rx
(
    input  wire       clk,
    input  wire       rst,           // synchronous, active-high
    input  wire       tick_16x,      // oversample tick (BAUD * 16)
    input  wire       rxd,           // async serial input (idle high)
    output reg  [7:0] rx_data,
    output reg        rx_valid,      // 1-clk pulse when a byte is ready
    output reg        rx_busy,       // high while receiving a frame
    output reg        framing_error  // high for 1 clk if stop bit not high
);

    // ------------------------------------------------------------
    // 2FF synchronizer for the async RXD
    // ------------------------------------------------------------
    reg rxd_meta, rxd_sync;
    always @(posedge clk) begin
        if (rst) begin
            rxd_meta <= 1'b1;
            rxd_sync <= 1'b1;
        end else begin
            rxd_meta <= rxd;
            rxd_sync <= rxd_meta;
        end
    end

    // Rising/falling edge detect on synchronized RXD
    reg rxd_sync_d;
    always @(posedge clk) begin
        if (rst) rxd_sync_d <= 1'b1;
        else     rxd_sync_d <= rxd_sync;
    end
    wire start_edge = (rxd_sync_d == 1'b1) && (rxd_sync == 1'b0); // idle->start (high->low)

    // ------------------------------------------------------------
    // Majority-of-3 helper (no 'automatic' to keep Verilog-2001)
    // ------------------------------------------------------------
    function [0:0] majority3;
        input a, b, c;
        begin
            majority3 = (a & b) | (a & c) | (b & c);
        end
    endfunction

    // ------------------------------------------------------------
    // RX FSM
    // ------------------------------------------------------------
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0] state;
    reg [3:0] osr_cnt;          // 0..15 oversample counter
    reg [2:0] bitpos;           // 0..7 data bit index
    reg [7:0] shreg;            // shift register (LSB-first)
    reg       samp6, samp7;     // mid-bit window samples at counts 6 and 7

    always @(posedge clk) begin
        if (rst) begin
            state          <= S_IDLE;
            osr_cnt        <= 4'd0;
            bitpos         <= 3'd0;
            shreg          <= 8'h00;
            samp6          <= 1'b1;
            samp7          <= 1'b1;
            rx_data        <= 8'h00;
            rx_valid       <= 1'b0;
            rx_busy        <= 1'b0;
            framing_error  <= 1'b0;
        end else begin
            rx_valid <= 1'b0; // default (1-clk pulse)

            case (state)
                // ------------------------------------------------
                S_IDLE: begin
                    rx_busy       <= 1'b0;
                    framing_error <= 1'b0;
                    if (start_edge) begin
                        rx_busy <= 1'b1;
                        osr_cnt <= 4'd0;   // start measuring toward mid of start bit
                        state   <= S_START;
                    end
                end

                // ------------------------------------------------
                // Wait to sample the START bit in the middle
                S_START: begin
                    if (tick_16x) begin
                        osr_cnt <= osr_cnt + 4'd1;
                        if (osr_cnt == 4'd7) begin
                            // Mid-bit of start; must be low to be valid
                            if (rxd_sync == 1'b0) begin
                                osr_cnt <= 4'd0;   // re-center for data bits
                                bitpos  <= 3'd0;
                                state   <= S_DATA;
                            end else begin
                                // Glitch/false start
                                state <= S_IDLE;
                            end
                        end
                    end
                end

                // ------------------------------------------------
                // Sample each data bit at mid-bit using majority over 6,7,8
                // Shift LSB-first: {older[6:0], new_bit}
                S_DATA: begin
                    if (tick_16x) begin
                        osr_cnt <= osr_cnt + 4'd1;

                        if (osr_cnt == 4'd6) samp6 <= rxd_sync;
                        if (osr_cnt == 4'd7) samp7 <= rxd_sync;

                        if (osr_cnt == 4'd8) begin
                            shreg   <= {shreg[6:0], majority3(samp6, samp7, rxd_sync)}; // LSB-first
                            osr_cnt <= 4'd0;

                            if (bitpos == 3'd7) begin
                                state  <= S_STOP;
                            end
                            bitpos <= bitpos + 3'd1;
                        end
                    end
                end

                // ------------------------------------------------
                // Sample STOP bit the same way; check it's high
                S_STOP: begin
                    if (tick_16x) begin
                        osr_cnt <= osr_cnt + 4'd1;

                        if (osr_cnt == 4'd6) samp6 <= rxd_sync;
                        if (osr_cnt == 4'd7) samp7 <= rxd_sync;

                        if (osr_cnt == 4'd8) begin
                            rx_data       <= shreg;                        // final byte
                            rx_valid      <= 1'b1;                         // pulse
                            framing_error <= ~majority3(samp6, samp7, rxd_sync); // expect high
                            rx_busy       <= 1'b0;
                            state         <= S_IDLE;
                            osr_cnt       <= 4'd0;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
