module BCDAdder(
    input [3:0] A,
    input [3:0] B,
    input cin,
    output [3:0] S0,
    output S1
);

    wire [4:0] binary_sum;
    wire bcd_carry;

    assign binary_sum = A + B + cin;

    assign bcd_carry = binary_sum[4] |
                       (binary_sum[3] & binary_sum[2]) |
                       (binary_sum[3] & binary_sum[1]);

    assign S1 = bcd_carry;

    assign S0 = bcd_carry ?
                (binary_sum[3:0] + 4'b0110) :
                binary_sum[3:0];

endmodule