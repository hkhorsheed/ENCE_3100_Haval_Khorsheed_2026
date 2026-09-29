module D_flipflop(
    input D,
    input Clk,
    output Q
);

    wire Qm;

    D_latch Master(
        .D(D),
        .Clk(~Clk),
        .Q(Qm)
    );

    D_latch Slave(
        .D(Qm),
        .Clk(Clk),
        .Q(Q)
    );

endmodule