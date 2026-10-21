module Pattern4 #(
    parameter integer DIV_BITS = 20
)(
    input  clk,
    input  rst,
    input  en,
    input  dir,                 // if 1, invert output for a different look
    output reg [9:0] counter
);
	//LFSR
    reg [DIV_BITS-1:0] div;
    wire tick = &div;

    reg [9:0] lfsr;

    wire feedback = lfsr[9] ^ lfsr[6];
    wire [9:0] next_lfsr = {lfsr[8:0], feedback};

    always @(posedge clk) begin
        if (rst) begin
            div   <= {DIV_BITS{1'b0}};
            lfsr  <= 10'b0000000001;                 // non-zero seed
            counter <= 10'b0000000001;
        end else begin
            if (en) div <= div + 1'b1;
            if (en && tick) begin
                lfsr    <= (next_lfsr == 10'b0000000000) ? 10'b0000000001 : next_lfsr;
                counter <= dir ? ~lfsr : lfsr;       // optional inversion by 'dir'
            end
        end
    end
endmodule
