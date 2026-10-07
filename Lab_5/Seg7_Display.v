module Seg7_Display(
    input  [3:0] bin_number,
    output reg [7:0] seg_display
);

    always @(*) begin
        case (bin_number)
            4'h0: seg_display = 8'b1100_0000;
            4'h1: seg_display = 8'b1111_1001;
            4'h2: seg_display = 8'b1010_0100;
            4'h3: seg_display = 8'b1011_0000;
            4'h4: seg_display = 8'b1001_1001;
            4'h5: seg_display = 8'b1001_0010;
            4'h6: seg_display = 8'b1000_0010;
            4'h7: seg_display = 8'b1111_1000;
            4'h8: seg_display = 8'b1000_0000;
            4'h9: seg_display = 8'b1001_0000;
            4'hA: seg_display = 8'b1000_1000;
            4'hB: seg_display = 8'b1000_0011;
            4'hC: seg_display = 8'b1100_0110;
            4'hD: seg_display = 8'b1010_0001;
            4'hE: seg_display = 8'b1000_0110;
            4'hF: seg_display = 8'b1000_1110;
            default: seg_display = 8'b1111_1111;
        endcase
    end

endmodule