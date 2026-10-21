module Pattern5 #(
    parameter integer DIV_BITS = 20
)(
    input  clk,
    input  rst,
    input  en,
    input  dir,                 // 1 = count up, 0 = count down
    output reg [9:0] counter
);
	// Gray
    reg [DIV_BITS-1:0] div;
    wire tick = &div;

    reg [9:0] bin;

    wire [9:0] gray = bin ^ (bin >> 1);

    always @(posedge clk) begin
        if (rst) begin
            div     <= {DIV_BITS{1'b0}};
            bin     <= 10'd0;
            counter <= 10'd0;
        end else begin
            if (en) div <= div + 1'b1;
            if (en && tick) begin
                bin <= dir ? (bin + 10'd1) : (bin - 10'd1);
                counter <= gray;
            end
        end
    end
endmodule
