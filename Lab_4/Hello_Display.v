module Hello_Display(
    input [3:0] position,
    output reg [7:0] HEX0,
    output reg [7:0] HEX1,
    output reg [7:0] HEX2,
    output reg [7:0] HEX3,
    output reg [7:0] HEX4,
    output reg [7:0] HEX5,
    output reg [7:0] HEX6,
    output reg [7:0] HEX7
);

    // Seven-segment patterns (active LOW)
    parameter BLANK = 8'b1111_1111;
    parameter H     = 8'b1000_1001;
    parameter E     = 8'b1000_0110;
    parameter L     = 8'b1100_0111;
    parameter O     = 8'b1100_0000;

    always @(*) begin

        // Default all displays OFF
        HEX0 = BLANK;
        HEX1 = BLANK;
        HEX2 = BLANK;
        HEX3 = BLANK;
        HEX4 = BLANK;
        HEX5 = BLANK;
        HEX6 = BLANK;
        HEX7 = BLANK;

        case(position)

            4'd0:  HEX0 = H;

            4'd1: begin
                HEX1 = H;
                HEX0 = E;
            end

            4'd2: begin
                HEX2 = H;
                HEX1 = E;
                HEX0 = L;
            end

            4'd3: begin
                HEX3 = H;
                HEX2 = E;
                HEX1 = L;
                HEX0 = L;
            end

            4'd4: begin
                HEX4 = H;
                HEX3 = E;
                HEX2 = L;
                HEX1 = L;
                HEX0 = O;
            end

            4'd5: begin
                HEX5 = H;
                HEX4 = E;
                HEX3 = L;
                HEX2 = L;
                HEX1 = O;
            end

            4'd6: begin
                HEX6 = H;
                HEX5 = E;
                HEX4 = L;
                HEX3 = L;
                HEX2 = O;
            end

            4'd7: begin
                HEX7 = H;
                HEX6 = E;
                HEX5 = L;
                HEX4 = L;
                HEX3 = O;
            end

            4'd8: begin
                HEX7 = E;
                HEX6 = L;
                HEX5 = L;
                HEX4 = O;
            end

            4'd9: begin
                HEX7 = L;
                HEX6 = L;
                HEX5 = O;
            end

            4'd10: begin
                HEX7 = L;
                HEX6 = O;
            end

            4'd11: HEX7 = O;

            4'd12: begin
                // all displays blank
            end

        endcase
    end

endmodule