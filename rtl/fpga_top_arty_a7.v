`timescale 1ns / 1ps

module fpga_top_arty_a7 (
    input  wire       clk,
    input  wire       rst_btn,
    output reg  [3:0] led
);

reg [25:0] blink_div;

always @(posedge clk) begin
    if (!rst_btn) begin
        blink_div <= 26'd0;
        led       <= 4'b0001;
    end
    else begin
        blink_div <= blink_div + 26'd1;
        led[0]    <= blink_div[25];
        led[1]    <= blink_div[24];
        led[2]    <= blink_div[23];
        led[3]    <= 1'b1;
    end
end

endmodule
