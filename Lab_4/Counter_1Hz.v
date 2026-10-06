module Counter_1Hz(
    input in_clk,
    input clear,
    output reg one_sec
);

    reg [25:0] count;

    always @(posedge in_clk) begin
        if (~clear) begin
            count <= 26'd0;
            one_sec <= 1'b0;
        end
        else begin
            if (count == 26'd49_999_999) begin
                count <= 26'd0;
                one_sec <= 1'b1;
            end
            else begin
                count <= count + 1'b1;
                one_sec <= 1'b0;
            end
        end
    end

endmodule