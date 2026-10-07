module Multiplier8x8(
    input  [7:0] A,
    input  [7:0] B,
    output [15:0] P
);

    wire [15:0] p0;
    wire [15:0] p1;
    wire [15:0] p2;
    wire [15:0] p3;
    wire [15:0] p4;
    wire [15:0] p5;
    wire [15:0] p6;
    wire [15:0] p7;

    assign p0 = B[0] ? {8'b0, A}       : 16'b0;
    assign p1 = B[1] ? {7'b0, A, 1'b0} : 16'b0;
    assign p2 = B[2] ? {6'b0, A, 2'b0} : 16'b0;
    assign p3 = B[3] ? {5'b0, A, 3'b0} : 16'b0;
    assign p4 = B[4] ? {4'b0, A, 4'b0} : 16'b0;
    assign p5 = B[5] ? {3'b0, A, 5'b0} : 16'b0;
    assign p6 = B[6] ? {2'b0, A, 6'b0} : 16'b0;
    assign p7 = B[7] ? {1'b0, A, 7'b0} : 16'b0;

    assign P = p0 + p1 + p2 + p3 + p4 + p5 + p6 + p7;

endmodule