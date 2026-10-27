module five_second_counter(
    input wire clk,
    input wire clear,
    output wire done
);

    // 5 seconds at 50 MHz = 250,000,000 cycles
    localparam [27:0] LAST_COUNT = 28'd249999999;

    reg [27:0] count = 28'd0;

    assign done = (count == LAST_COUNT);

    always @(posedge clk) begin
        if (clear || done)
            count <= 28'd0;
        else
            count <= count + 28'd1;
    end

endmodule