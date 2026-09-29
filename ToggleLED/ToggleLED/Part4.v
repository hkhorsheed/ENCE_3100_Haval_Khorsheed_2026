module Part4(
    input D,
    input Clk,
    output reg Qa,
    output reg Qb,
    output reg Qc
);

    // Gated D latch
    always @(*) begin
        if (Clk)
            Qa = D;
    end

    // Positive-edge D flip-flop
    always @(posedge Clk) begin
        Qb <= D;
    end

    // Negative-edge D flip-flop
    always @(negedge Clk) begin
        Qc <= D;
    end

endmodule