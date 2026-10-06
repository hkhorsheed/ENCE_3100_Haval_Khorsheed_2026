module Hello_Scroll(
    input clk,
    input clear,
    input ena,
    output reg [3:0] position
);

    always @(posedge clk) begin
        if (~clear)
            position <= 4'd0;

        else if (ena) begin
            if (position == 4'd12)
                position <= 4'd0;
            else
                position <= position + 1'b1;
        end
    end

endmodule