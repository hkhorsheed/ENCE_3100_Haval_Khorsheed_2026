module Pattern2 #(
    parameter integer DIV_BITS = 20
)(
    input  clk,
    input  rst,
    input  en,
    input  dir,                 // 1 = rotate left, 0 = rotate right
    output reg [9:0] counter
);
	// Pattern Rotate
    reg [DIV_BITS-1:0] div;
    wire tick = &div;

    always @(posedge clk) begin
        if (rst) begin
            div     <= {DIV_BITS{1'b0}};
            counter <= 10'b0000000001;               // start at LSB
        end else begin
            if (en) div <= div + 1'b1;
            if (en && tick) begin
                if (dir)
                    counter <= {counter[8:0], counter[9]};  // rotate left
                else
                    counter <= {counter[0], counter[9:1]};  // rotate right
            end
        end
    end
endmodule
