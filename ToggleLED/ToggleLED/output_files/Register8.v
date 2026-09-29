module Register8(
    input        Clk,
    input        Reset_n,
    input  [7:0] D,
    output reg [7:0] Q
);

    always @(posedge Clk or negedge Reset_n) begin
        if (!Reset_n)
            Q <= 8'b0;
        else
            Q <= D;
    end

endmodule