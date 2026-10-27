module uart_display_fsm(
    input wire clk,
    input wire rx_ready,
    input wire [7:0] rx_data,
    output reg [7:0] displayed_char = 8'h00
);

    localparam IDLE = 1'b0;
    localparam HOLD = 1'b1;

    reg state = IDLE;

    wire timeout;

    wire clear_timer = (state == IDLE) || rx_ready;

    five_second_counter timer(
        .clk(clk),
        .clear(clear_timer),
        .done(timeout)
    );

    always @(posedge clk) begin
        case(state)

            IDLE: begin
                if(rx_ready) begin
                    displayed_char <= rx_data;
                    state <= HOLD;
                end
            end

            HOLD: begin
                if(rx_ready) begin
                    displayed_char <= rx_data;
                end
                else if(timeout) begin
                    displayed_char <= 8'h00;
                    state <= IDLE;
                end
            end

            default: begin
                displayed_char <= 8'h00;
                state <= IDLE;
            end

        endcase
    end

endmodule