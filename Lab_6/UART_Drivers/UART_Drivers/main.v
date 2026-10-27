
`default_nettype none

module main(
    input MAX10_CLK1_50,
    input [9:0] SW,
    output [9:0] LEDR,
    inout [35:0] GPIO,
    output [7:0] HEX0
);

    wire rx_ready;
    wire [7:0] rx_data;
    wire [7:0] displayed_char;

    // UART Receiver
    async_receiver RX(
        .clk(MAX10_CLK1_50),
        .RxD(GPIO[35]),
        .RxD_data_ready(rx_ready),
        .RxD_data(rx_data)
    );

    // UART Transmitter
    async_transmitter TX(
        .clk(MAX10_CLK1_50),
        .TxD(GPIO[33]),
        .TxD_start(rx_ready),
        .TxD_data(rx_data)
    );

    // FSM with five-second timer
    uart_display_fsm Controller(
        .clk(MAX10_CLK1_50),
        .rx_ready(rx_ready),
        .rx_data(rx_data),
        .displayed_char(displayed_char)
    );

    // Display ASCII character on LEDs
    assign LEDR = {2'b00, displayed_char};

    // Convert ASCII to seven-segment pattern
    char2seg Display(
        .char(displayed_char),
        .HEX0(HEX0)
    );

endmodule

`default_nettype wire
