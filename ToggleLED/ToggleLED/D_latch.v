module D_latch(
    input D,
    input Clk,
    output Q
);

    wire R;
    wire S_g, R_g, Qa, Qb /* synthesis keep */;

    assign R   = ~D;
    assign S_g = D & Clk;
    assign R_g = R & Clk;

    assign Qa = ~(R_g | Qb);
    assign Qb = ~(S_g | Qa);

    assign Q = Qa;

endmodule