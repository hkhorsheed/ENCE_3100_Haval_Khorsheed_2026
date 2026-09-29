module main(
    input  [9:0] SW,
    input  [1:0] KEY,
    output [9:0] LEDR,

    output [7:0] HEX0,
    output [7:0] HEX1,
    output [7:0] HEX2,
    output [7:0] HEX3,
    output [7:0] HEX4,
    output [7:0] HEX5
);

    wire [7:0] A;

    // Store SW[7:0] into A when KEY1 is clocked
    Register8 REG0(
        .Clk(KEY[1]),
        .Reset_n(KEY[0]),
        .D(SW[7:0]),
        .Q(A)
    );

    // Current value B = switches
    Seg7_Display B_LOW(
        .bin_number(SW[3:0]),
        .seg_display(HEX0)
    );

    Seg7_Display B_HIGH(
        .bin_number(SW[7:4]),
        .seg_display(HEX1)
    );

    // Stored value A
    Seg7_Display A_LOW(
        .bin_number(A[3:0]),
        .seg_display(HEX2)
    );

    Seg7_Display A_HIGH(
        .bin_number(A[7:4]),
        .seg_display(HEX3)
    );

    // Turn unused displays off
    assign HEX4 = 8'b1111_1111;
    assign HEX5 = 8'b1111_1111;

    // Show stored A on LEDs too
    assign LEDR[7:0] = A;
    assign LEDR[9:8] = 2'b00;

endmodule