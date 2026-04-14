`timescale 1ns / 1ps

module GHASH (
    input         clk,
    input         rst,
    input         init,
    input         en,
    input  [127:0] H,
    input  [127:0] X,
    output reg [127:0] Y,
    output reg        Y_valid
);

localparam [127:0] GF_R = 128'he1000000000000000000000000000000;

function [127:0] gf128_mul;
    input [127:0] x;
    input [127:0] h;
    reg   [127:0] z;
    reg   [127:0] v;
    integer i;
begin
    z = 128'd0;
    v = h;

    for (i = 0; i < 128; i = i + 1) begin
        if (x[127 - i])
            z = z ^ v;

        if (v[0])
            v = (v >> 1) ^ GF_R;
        else
            v = v >> 1;
    end

    gf128_mul = z;
end
endfunction

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        Y       <= 128'd0;
        Y_valid <= 1'b0;
    end
    else begin
        Y_valid <= 1'b0;

        if (init) begin
            Y <= 128'd0;
        end
        else if (en) begin
            Y       <= gf128_mul(Y ^ X, H);
            Y_valid <= 1'b1;
        end
    end
end

endmodule
