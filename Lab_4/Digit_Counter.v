module Digit_Counter(
    input clk,
    input clear,
    input ena,
    output reg [3:0] digit
);

    always @(posedge clk) begin
        if (~clear)
            digit <= 4'd0;

        else if (ena) begin
            if (digit == 4'd9)
                digit <= 4'd0;
            else
                digit <= digit + 1'b1;
        end
    end

endmodule