module Counter_16bit (
    input clk,
    input ena,
    input clear,
    output reg [15:0] Q
);

    always @(posedge clk) begin
        if (~clear)
            Q <= 16'd0;
        else if (ena)
            Q <= Q + 1;
    end

endmodule