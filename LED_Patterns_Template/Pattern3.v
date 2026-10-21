// Pattern3: Ping-pong (bouncing dot), 50 MHz in, parameterized speed
module Pattern3 #(
    parameter integer DIV_BITS = 21  // bigger = slower 
)(
    input  wire       clk,    // 50 MHz
    input  wire       rst,    // sync, active-high
    input  wire       en,     // enable motion
    input  wire       dir,    // initial direction on reset: 1=left (toward MSB), 0=right
    output reg [9:0]  counter
);

//PingPong
    // free-running divider to make a 1-cycle tick
    reg  [DIV_BITS-1:0] div;
    wire tick = &div;

    // position of the lit LED: 0..9, where 0 = LSB, 9 = MSB
    reg [3:0] pos;
    reg       going_left;   // 1 = toward MSB (pos++), 0 = toward LSB (pos--)

    always @(posedge clk) begin
        if (rst) begin
            div         <= {DIV_BITS{1'b0}};
            pos         <= 4'd0;       // start at LSB
            going_left  <= dir;        // seed direction from input
            counter     <= 10'b0000000001;
        end else begin
            if (en) div <= div + 1'b1;

            if (en && tick) begin
                // bounce logic at the ends BEFORE moving
                if (pos == 4'd9)       going_left <= 1'b0; // hit MSB -> go right (toward LSB)
                else if (pos == 4'd0)  going_left <= 1'b1; // hit LSB -> go left (toward MSB)

                // move one step in the current direction
                pos <= going_left ? (pos + 4'd1) : (pos - 4'd1);

                // one-hot output from updated position (wrap-safe because of bounce)
                case (going_left ? (pos + 4'd1) : (pos - 4'd1))
                    4'd0:  counter <= 10'b0000000001;
                    4'd1:  counter <= 10'b0000000010;
                    4'd2:  counter <= 10'b0000000100;
                    4'd3:  counter <= 10'b0000001000;
                    4'd4:  counter <= 10'b0000010000;
                    4'd5:  counter <= 10'b0000100000;
                    4'd6:  counter <= 10'b0001000000;
                    4'd7:  counter <= 10'b0010000000;
                    4'd8:  counter <= 10'b0100000000;
                    default: counter <= 10'b1000000000; // 9
                endcase
            end
        end
    end
endmodule
