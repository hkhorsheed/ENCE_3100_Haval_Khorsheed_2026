module Seg7_Display(
    input [3:0] bin_number,
    output reg [7:0] seg_display
);

    always @(*) begin 
        case(bin_number) 
            4'd0:  seg_display = 8'b1100_0000;
            4'd1:  seg_display = 8'b1111_1001;
            4'd2:  seg_display = 8'b1010_0100;
            4'd3:  seg_display = 8'b1011_0000;
            4'd4:  seg_display = 8'b1001_1001;
            4'd5:  seg_display = 8'b1001_0010;
            4'd6:  seg_display = 8'b1000_0010;
            4'd7:  seg_display = 8'b1111_1000;
            4'd8:  seg_display = 8'b1000_0000;
            4'd9:  seg_display = 8'b1001_0000;
            4'd10: seg_display = 8'b1000_1000; // A
            4'd11: seg_display = 8'b1000_0011; // b
            4'd12: seg_display = 8'b1100_0110; // C
            4'd13: seg_display = 8'b1010_0001; // d
            4'd14: seg_display = 8'b1000_0110; // E
            4'd15: seg_display = 8'b1000_1110; // F
            //default: seg_display = 8'b1111_1111;
        endcase
    end

endmodule