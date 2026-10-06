module Counter_4bit (
    input ena,
    input clk,
    input clear,
    output [3:0] count
); 

    wire [2:0] w_and;
    wire [3:0] w_out;

    assign count = w_out;

    assign w_and[0] = ena & w_out[0];
    assign w_and[1] = w_and[0] & w_out[1];
    assign w_and[2] = w_and[1] & w_out[2];

    TFlipFlop TFF_0 (
        .T(ena),
        .clk(clk),
        .clear(clear),
        .Qt(w_out[0])
    );

    TFlipFlop TFF_1 (
        .T(w_and[0]),
        .clk(clk),
        .clear(clear),
        .Qt(w_out[1])
    );

    TFlipFlop TFF_2 (
        .T(w_and[1]),
        .clk(clk),
        .clear(clear),
        .Qt(w_out[2])
    );

    TFlipFlop TFF_3 (
        .T(w_and[2]),
        .clk(clk),
        .clear(clear),
        .Qt(w_out[3])
    );

endmodule