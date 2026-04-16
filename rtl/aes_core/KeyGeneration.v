`timescale 1ns / 1ps
module KeyGeneration
(
input clk,
input rst_n,
input [3:0] rc,
input [255:0] key,
output [255:0] keyout
);
wire [31:0] w0;
wire [31:0] w1;
wire [31:0] w2;
wire [31:0] w3;
wire [31:0] w4;
wire [31:0] w5;
wire [31:0] w6;
wire [31:0] w7;
wire [31:0] tem4;
wire [31:0] tem8;

assign w0 = key[255:224];
assign w1 = key[223:192];
assign w2 = key[191:160];
assign w3 = key[159:128];

assign w4 = key[127:96];
assign w5 = key[95:64];
assign w6 = key[63:32];
assign w7 = key[31:0];

assign keyout[255:224]  = w0 ^ tem8 ^ rcon(rc);       // w 8      temp = SubWord(RotWord(w[i-1])) ^ Rcon[i/8];
assign keyout[223:192]  = w0 ^ tem8 ^ rcon(rc)^ w1;   // w9
assign keyout[191:160]  = w0 ^ tem8 ^ rcon(rc)^ w1 ^ w2;   //w10
assign keyout[159:128]  = w0 ^ tem8 ^ rcon(rc)^ w1 ^ w2 ^ w3;   // w11

assign keyout[127:96]   = w4 ^tem4;   // w12         temp = SubWord(w[i-1]);
assign keyout[95:64]    = w4 ^tem4 ^ w5;   //w13
assign keyout[63:32]    = w4 ^tem4 ^ w5 ^ w6;  //w14
assign keyout[31:0]     = w4 ^tem4 ^ w5 ^ w6 ^ w7;   //15

sbox w4_1(.clk(clk), .rst_n(rst_n), .a(keyout[159:152]),.co(tem4[31:24]));
sbox w4_2(.clk(clk), .rst_n(rst_n), .a(keyout[151:144]),.co(tem4[23:16]));
sbox w4_3(.clk(clk), .rst_n(rst_n), .a(keyout[143:136]),.co(tem4[15:8]));
sbox w4_4(.clk(clk), .rst_n(rst_n), .a(keyout[135:128]),.co(tem4[7:0]));

sbox w8_1(.clk(clk), .rst_n(rst_n), .a(w7[23:16]),.co(tem8[31:24]));
sbox w8_2(.clk(clk), .rst_n(rst_n), .a(w7[15:8]),.co(tem8[23:16]));
sbox w8_3(.clk(clk), .rst_n(rst_n), .a(w7[7:0]),.co(tem8[15:8]));
sbox w8_4(.clk(clk), .rst_n(rst_n), .a(w7[31:24]),.co(tem8[7:0]));
           
      function [31:0] rcon;
      input	[3:0] rc;
      case(rc)	
         4'd1: rcon=32'h01_00_00_00;
         4'd2: rcon=32'h02_00_00_00;
         4'd3: rcon=32'h04_00_00_00;
         4'd4: rcon=32'h08_00_00_00;
         4'd5: rcon=32'h10_00_00_00;
         4'd6: rcon=32'h20_00_00_00;
         4'd7: rcon=32'h40_00_00_00;
         4'd8: rcon=32'h80_00_00_00;
         4'd9: rcon=32'h1b_00_00_00;
         4'd10: rcon=32'h36_00_00_00;
         default: rcon=32'h00_00_00_00;
       endcase

     endfunction

endmodule