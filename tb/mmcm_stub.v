`timescale 1ns / 1ps

module MMCME2_BASE #(
    parameter BANDWIDTH = "OPTIMIZED",
    parameter CLKFBOUT_MULT_F = 5.0,
    parameter CLKFBOUT_PHASE = 0.0,
    parameter CLKIN1_PERIOD = 0.0,
    parameter CLKOUT0_DIVIDE_F = 1.0,
    parameter CLKOUT0_DUTY_CYCLE = 0.5,
    parameter CLKOUT0_PHASE = 0.0,
    parameter CLKOUT1_DIVIDE = 1,
    parameter CLKOUT2_DIVIDE = 1,
    parameter CLKOUT3_DIVIDE = 1,
    parameter CLKOUT4_DIVIDE = 1,
    parameter CLKOUT5_DIVIDE = 1,
    parameter CLKOUT6_DIVIDE = 1,
    parameter DIVCLK_DIVIDE = 1,
    parameter REF_JITTER1 = 0.0,
    parameter STARTUP_WAIT = "FALSE"
) (
    input  wire CLKIN1,
    input  wire CLKFBIN,
    input  wire RST,
    input  wire PWRDWN,
    output wire CLKFBOUT,
    output wire CLKFBOUTB,
    output wire CLKOUT0,
    output wire CLKOUT0B,
    output wire CLKOUT1,
    output wire CLKOUT1B,
    output wire CLKOUT2,
    output wire CLKOUT2B,
    output wire CLKOUT3,
    output wire CLKOUT3B,
    output wire CLKOUT4,
    output wire CLKOUT5,
    output wire CLKOUT6,
    output wire LOCKED
);

reg clk_div2 = 1'b0;
reg clk_div4 = 1'b0;
reg [2:0] lock_cnt = 3'd0;
reg locked_r = 1'b0;

always @(posedge CLKIN1 or posedge RST) begin
    if (RST || PWRDWN) begin
        clk_div2 <= 1'b0;
        clk_div4 <= 1'b0;
        lock_cnt <= 3'd0;
        locked_r <= 1'b0;
    end
    else begin
        clk_div2 <= ~clk_div2;
        if (clk_div2)
            clk_div4 <= ~clk_div4;

        if (!locked_r) begin
            lock_cnt <= lock_cnt + 3'd1;
            if (lock_cnt == 3'd4)
                locked_r <= 1'b1;
        end
    end
end

assign CLKFBOUT  = CLKIN1;
assign CLKFBOUTB = ~CLKIN1;
assign CLKOUT0   = clk_div4;
assign CLKOUT0B  = ~clk_div4;
assign CLKOUT1   = 1'b0;
assign CLKOUT1B  = 1'b1;
assign CLKOUT2   = 1'b0;
assign CLKOUT2B  = 1'b1;
assign CLKOUT3   = 1'b0;
assign CLKOUT3B  = 1'b1;
assign CLKOUT4   = 1'b0;
assign CLKOUT5   = 1'b0;
assign CLKOUT6   = 1'b0;
assign LOCKED    = locked_r;

endmodule
