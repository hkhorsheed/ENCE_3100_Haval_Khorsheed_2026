// uart_tx.v
// Verilog-2001, synthesizable
// 8 data bits, no parity, 1 stop (8N1)

module uart_tx
(
    input  wire       clk,
    input  wire       rst,        // synchronous, active-high
    // control
    input  wire       tick_1x,    // 1x baud tick
    input  wire       tx_start,   // pulse to start when idle
    input  wire [7:0] tx_data,
    output reg        tx_busy,    // high during transmission
    // serial line
    output reg        txd         // idle high
);

    localparam [1:0] S_IDLE = 2'd0,
                     S_START= 2'd1,
                     S_DATA = 2'd2,
                     S_STOP = 2'd3;

    reg [1:0]  state = S_IDLE;
    reg [2:0]  bitpos;
    reg [7:0]  shreg;

    always @(posedge clk) begin
        if (rst) begin
            state  <= S_IDLE;
            bitpos <= 3'd0;
            shreg  <= 8'h00;
            txd    <= 1'b1;
            tx_busy<= 1'b0;
        end else begin
            if (state==S_IDLE) begin
                txd     <= 1'b1;     // idle
                tx_busy <= 1'b0;
                if (tx_start) begin
                    shreg  <= tx_data;
                    bitpos <= 3'd0;
                    tx_busy<= 1'b1;
                    state  <= S_START;
                end
            end else if (tick_1x) begin
                case (state)
                    S_START: begin
                        txd   <= 1'b0;   // start bit
                        state <= S_DATA;
                    end

                    S_DATA: begin
                        txd   <= shreg[0];
                        shreg <= {1'b0, shreg[7:1]};
                        if (bitpos == 3'd7) begin
                            state  <= S_STOP;
                        end
                        bitpos <= bitpos + 3'd1;
                    end

                    S_STOP: begin
                        txd    <= 1'b1;  // stop bit
                        state  <= S_IDLE;
                        tx_busy<= 1'b0;
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
