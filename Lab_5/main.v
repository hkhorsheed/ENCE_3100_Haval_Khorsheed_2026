module main(
    input  [9:0] SW,
    input  [1:0] KEY,
    input        MAX10_CLK1_50,

    output [9:0] LEDR,
    output [7:0] HEX0,
    output [7:0] HEX1,
    output [7:0] HEX2,
    output [7:0] HEX3,
    output [7:0] HEX4,
    output [7:0] HEX5
);

    reg [7:0] A;
    reg [7:0] B;
    reg [15:0] P_reg;

    reg key0_prev;
    reg key1_prev;

    wire [15:0] P;

    Multiplier8x8 mult(
        .A(A),
        .B(B),
        .P(P)
    );

    always @(posedge MAX10_CLK1_50) begin
        key0_prev <= KEY[0];
        key1_prev <= KEY[1];

        if (key0_prev && !KEY[0])
            A <= SW[7:0];

        if (key1_prev && !KEY[1])
            B <= SW[7:0];

        P_reg <= P;
    end

    Seg7_Display displayP0(
        .bin_number(P_reg[3:0]),
        .seg_display(HEX0)
    );

    Seg7_Display displayP1(
        .bin_number(P_reg[7:4]),
        .seg_display(HEX1)
    );

    Seg7_Display displayP2(
        .bin_number(P_reg[11:8]),
        .seg_display(HEX2)
    );

    Seg7_Display displayP3(
        .bin_number(P_reg[15:12]),
        .seg_display(HEX3)
    );

    Seg7_Display displayB(
        .bin_number(B[3:0]),
        .seg_display(HEX4)
    );

    Seg7_Display displayA(
        .bin_number(A[3:0]),
        .seg_display(HEX5)
    );

    assign LEDR = 10'b0;

endmodule