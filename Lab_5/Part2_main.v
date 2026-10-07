module main(
    input  [9:0] SW,
    input  [1:0] KEY,
    input        MAX10_CLK1_50,
    output [9:0] LEDR
);

    reg [7:0] S;
    reg key1_prev;

    always @(posedge MAX10_CLK1_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            S <= 8'b0;
            key1_prev <= 1'b1;
        end
        else begin
            key1_prev <= KEY[1];

            // detect KEY1 press: 1 -> 0
            if (key1_prev && !KEY[1]) begin
                if (SW[8])
                    S <= S - SW[7:0];
                else
                    S <= S + SW[7:0];
            end
        end
    end

    assign LEDR[7:0] = S;
    assign LEDR[8] = SW[8];
    assign LEDR[9] = 1'b0;

endmodule