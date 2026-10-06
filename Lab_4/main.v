module main(
    input MAX10_CLK1_50,
    input [1:0] KEY,
    output [7:0] HEX0,
    output [7:0] HEX1,
    output [7:0] HEX2,
    output [7:0] HEX3,
    output [7:0] HEX4,
    output [7:0] HEX5,
    output [7:0] HEX6,
    output [7:0] HEX7
);

    wire one_sec;
    wire [3:0] position;

    // One-second enable pulse
    Counter_1Hz Counter_1(
        .in_clk(MAX10_CLK1_50),
        .clear(KEY[0]),
        .one_sec(one_sec)
    );

    // Controls scrolling position
    Hello_Scroll Scroll_1(
        .clk(MAX10_CLK1_50),
        .clear(KEY[0]),
        .ena(one_sec),
        .position(position)
    );

    // Displays HELLO
    Hello_Display Display_1(
        .position(position),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .HEX6(HEX6),
        .HEX7(HEX7)
    );

endmodule