`timescale 1ns / 1ps
module tb_onecase_aad128_newfail;
logic clk,rst,mode,in_valid,last,pc_ct_valid,tag_valid;
logic [7:0] in,out;
logic [2:0] in_type;
logic [10:0] in_valid_bit,pc_ct_len_bit;
logic [3:0] pc_ct_valid_bit;
localparam logic [255:0] KEY=256'h78dc4e0aaf52d935c3c01eea57428f00ca1fd475f5da86a49c8dd73d68c8e223;
localparam logic [1023:0] IV=1024'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d79cf22d504cc793c3fb6c8a;
localparam integer IV_BITS=96;
localparam logic [1023:0] AAD=1024'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b96baa8c1c75a671bfb2d08d06be5f36;
localparam integer AAD_BITS=128;
localparam logic [1023:0] PT=1024'd0;
localparam integer PT_BITS=0;
localparam logic [127:0] TAG_EXP=128'h3e5d486aa2e30b22e040b85723a06e76;
localparam integer TAG_BITS=128;
top dut(.clk(clk),.rst(rst),.mode(mode),.in(in),.in_valid(in_valid),.in_type(in_type),.in_valid_bit(in_valid_bit),.last(last),.pc_ct_valid(pc_ct_valid),.tag_valid(tag_valid),.pc_ct_len_bit(pc_ct_len_bit),.pc_ct_valid_bit(pc_ct_valid_bit),.out(out));
always #5 clk=~clk;
function automatic [7:0] getb1024(input logic [1023:0] data_bits,input integer total_bits,input integer byte_idx); integer total_bytes; begin total_bytes=(total_bits+7)/8; if(byte_idx<total_bytes) getb1024=data_bits[((total_bytes-1-byte_idx)*8)+:8]; else getb1024=8'd0; end endfunction
function automatic [7:0] getb256(input logic [255:0] data_bits,input integer total_bits,input integer byte_idx); integer total_bytes; begin total_bytes=(total_bits+7)/8; if(byte_idx<total_bytes) getb256=data_bits[((total_bytes-1-byte_idx)*8)+:8]; else getb256=8'd0; end endfunction
task automatic reset_env; begin @(posedge clk); rst<=1; mode<=0; in<=0; in_valid<=0; in_type<=3'd6; in_valid_bit<=0; last<=0; @(posedge clk); rst<=0; repeat(3) @(posedge clk); end endtask
task automatic send1024(input logic [2:0] field_type,input logic [1023:0] data_bits,input integer total_bits); integer total_bytes,byte_idx; begin total_bytes=(total_bits+7)/8; if(total_bits==0) begin @(posedge clk); in<=0; in_valid<=1; in_type<=field_type; in_valid_bit<=0; last<=1; end else begin for(byte_idx=0;byte_idx<total_bytes;byte_idx=byte_idx+1) begin @(posedge clk); in<=getb1024(data_bits,total_bits,byte_idx); in_valid<=1; in_type<=field_type; in_valid_bit<=(byte_idx==(total_bytes-1))? total_bits[10:0] : 11'd0; last<=(byte_idx==(total_bytes-1)); end end @(posedge clk); in_valid<=0; in_type<=3'd6; in_valid_bit<=0; last<=0; end endtask
task automatic send256(input logic [2:0] field_type,input logic [255:0] data_bits,input integer total_bits); integer total_bytes,byte_idx; begin total_bytes=(total_bits+7)/8; for(byte_idx=0;byte_idx<total_bytes;byte_idx=byte_idx+1) begin @(posedge clk); in<=getb256(data_bits,total_bits,byte_idx); in_valid<=1; in_type<=field_type; in_valid_bit<=(byte_idx==(total_bytes-1))? total_bits[10:0] : 11'd0; last<=(byte_idx==(total_bytes-1)); end @(posedge clk); in_valid<=0; in_type<=3'd6; in_valid_bit<=0; last<=0; end endtask
initial begin integer tag_seen=0,wait_cycles=0; clk=0; rst=0; mode=0; in=0; in_valid=0; in_type=3'd6; in_valid_bit=0; last=0; reset_env(); send256(3'd1,KEY,256); send1024(3'd0,IV,IV_BITS); send1024(3'd2,AAD,AAD_BITS); send1024(3'd3,PT,PT_BITS); send1024(3'd5,{896'd0,TAG_EXP},TAG_BITS); while(wait_cycles<40000) begin @(posedge clk); wait_cycles=wait_cycles+1; if(pc_ct_valid) $fatal(1,"Unexpected ciphertext output for PTlen=0."); if(tag_valid) begin if(out !== getb1024({896'd0,TAG_EXP}, TAG_BITS, tag_seen)) $fatal(1,"TAG mismatch at byte %0d. got=%02h expected=%02h",tag_seen,out,getb1024({896'd0,TAG_EXP},TAG_BITS,tag_seen)); tag_seen=tag_seen+1; end if(tag_seen==16) begin $display("One-case aad128/newfail completed."); #20; $finish; end end $fatal(1,"Timeout waiting for one-case regression."); end
endmodule
