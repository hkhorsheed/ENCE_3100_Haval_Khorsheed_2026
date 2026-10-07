module main(
    input  [9:0] SW,
    output [9:0] LEDR,
    output [7:0] HEX0,
    output [7:0] HEX1,
    output [7:0] HEX4,
    output [7:0] HEX5
);

    // multiplier code...

    assign LEDR = 10'b0000000000;

    wire [3:0] A;
    wire [3:0] B;
    wire [7:0] P;

    assign A = SW[9:6];
    assign B = SW[3:0];

    Multiplier4x4 mult(
        .A(A),
        .B(B),
        .P(P)
    );

    Seg7_Display displayA(
        .bin_number(A),
        .seg_display(HEX5)
    );

    Seg7_Display displayB(
        .bin_number(B),
        .seg_display(HEX4)
    );

    Seg7_Display displayHigh(
        .bin_number(P[7:4]),
        .seg_display(HEX1)
    );

    Seg7_Display displayLow(
        .bin_number(P[3:0]),
        .seg_display(HEX0)
    );

endmodule