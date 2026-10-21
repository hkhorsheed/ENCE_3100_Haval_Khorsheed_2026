// Pattern1: up/down 10-bit counter with parameterized speed (50 MHz in)
module Pattern1 #(
    parameter integer DIV_BITS = 24,   // adjust speed: larger = slower
    parameter integer STEP     = 1     // optional: change step size
)(
    input  wire       clk,     // 50 MHz
    input  wire       rst,     // sync, active-high
    input  wire       en,      // enable counting
    input  wire       dir,     // 1 = up, 0 = down
    output reg [9:0]  counter
);
	// UpDown

    // simple free-running divider to generate a 1-cycle tick
    reg  [DIV_BITS-1:0] div;
    wire tick = &div;          // overflow pulse when all bits = 1

    always @(posedge clk) begin
        if (rst) begin
            div     <= {DIV_BITS{1'b0}};
            counter <= 10'd0;
        end else begin
            // divider runs whenever enabled so tick cadence is stable
            if (en) div <= div + 1'b1;

            if (en && tick) begin
                if (dir)
                    counter <= counter + STEP;   // wraps naturally at 10 bits
                else
                    counter <= counter - STEP;
            end
        end
    end
endmodule
