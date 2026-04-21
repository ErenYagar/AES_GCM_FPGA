`timescale 1ns / 1ps
module tb_onecase_aad384_pt408_tag120_fail;
logic clk,rst,mode,in_valid,last,pc_ct_valid,tag_valid;
logic [7:0] in,out;
logic [2:0] in_type;
logic [10:0] in_valid_bit,pc_ct_len_bit;
logic [3:0] pc_ct_valid_bit;

localparam logic [255:0] KEY=256'h7f65d22033691bce87e55567ac7e1a212d9128e8df34e8b9ad2eeae4f987462f;
localparam logic [1023:0] IV=1024'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d252b363c49c19ea4ce2b84b;
localparam integer IV_BITS=96;
localparam logic [1023:0] AAD=1024'h0000000000000000000000000000000000000000000000000000000000000000e335a5c0a66b7932bc74a26a854e6866cca388f152fce6790fc1059c02fec363b59441acd4107ef523f01d37b43f90e6;
localparam integer AAD_BITS=384;
localparam logic [1023:0] PT=1024'h000000000000000000000000000000000000000000000000bbd8e3d6724ef08845caeb303e1ffc9aacbf62951471fa592c14c8a68c51f922a5c3508402ae721a36c321585a7578ae158d11;
localparam integer PT_BITS=408;
localparam logic [127:0] TAG_EXP=128'h000000000386f4521aef1e891ef284c9e684f62;
localparam integer TAG_BITS=120;
localparam logic [1023:0] CT_EXP=1024'h00000000000000000000000000000000000000000000000074761bf6fff0d09e6220d68c8b8a93a7fd069bbee6f0fd7fa1e04969f6b393d0a311019d0de3f318d7f50266f5ebcd1c610439;

top dut(.clk(clk),.rst(rst),.mode(mode),.in(in),.in_valid(in_valid),.in_type(in_type),.in_valid_bit(in_valid_bit),.last(last),.pc_ct_valid(pc_ct_valid),.tag_valid(tag_valid),.pc_ct_len_bit(pc_ct_len_bit),.pc_ct_valid_bit(pc_ct_valid_bit),.out(out));
always #5 clk=~clk;

function automatic [7:0] getb1024(input logic [1023:0] data_bits,input integer total_bits,input integer byte_idx); integer total_bytes; begin total_bytes=(total_bits+7)/8; if(byte_idx<total_bytes) getb1024=data_bits[((total_bytes-1-byte_idx)*8)+:8]; else getb1024=8'd0; end endfunction
function automatic [7:0] getb256(input logic [255:0] data_bits,input integer total_bits,input integer byte_idx); integer total_bytes; begin total_bytes=(total_bits+7)/8; if(byte_idx<total_bytes) getb256=data_bits[((total_bytes-1-byte_idx)*8)+:8]; else getb256=8'd0; end endfunction

task automatic reset_env; begin @(posedge clk); rst<=1; mode<=0; in<=0; in_valid<=0; in_type<=3'd6; in_valid_bit<=0; last<=0; @(posedge clk); rst<=0; repeat(3) @(posedge clk); end endtask
task automatic send1024(input logic [2:0] field_type,input logic [1023:0] data_bits,input integer total_bits); integer total_bytes,byte_idx; begin total_bytes=(total_bits+7)/8; if(total_bits==0) begin @(posedge clk); in<=0; in_valid<=1; in_type<=field_type; in_valid_bit<=0; last<=1; end else begin for(byte_idx=0;byte_idx<total_bytes;byte_idx=byte_idx+1) begin @(posedge clk); in<=getb1024(data_bits,total_bits,byte_idx); in_valid<=1; in_type<=field_type; in_valid_bit<=(byte_idx==(total_bytes-1))? total_bits[10:0] : 11'd0; last<=(byte_idx==(total_bytes-1)); end end @(posedge clk); in_valid<=0; in_type<=3'd6; in_valid_bit<=0; last<=0; end endtask
task automatic send256(input logic [2:0] field_type,input logic [255:0] data_bits,input integer total_bits); integer total_bytes,byte_idx; begin total_bytes=(total_bits+7)/8; for(byte_idx=0;byte_idx<total_bytes;byte_idx=byte_idx+1) begin @(posedge clk); in<=getb256(data_bits,total_bits,byte_idx); in_valid<=1; in_type<=field_type; in_valid_bit<=(byte_idx==(total_bytes-1))? total_bits[10:0] : 11'd0; last<=(byte_idx==(total_bytes-1)); end @(posedge clk); in_valid<=0; in_type<=3'd6; in_valid_bit<=0; last<=0; end endtask

initial begin
    integer ct_seen=0,tag_seen=0,wait_cycles=0;
    clk=0; rst=0; mode=0; in=0; in_valid=0; in_type=3'd6; in_valid_bit=0; last=0;
    reset_env();
    send256(3'd1,KEY,256);
    send1024(3'd0,IV,IV_BITS);
    send1024(3'd2,AAD,AAD_BITS);
    send1024(3'd3,PT,PT_BITS);
    send1024(3'd5,1024'd0,TAG_BITS);
    while(wait_cycles<80000) begin
        @(posedge clk);
        wait_cycles=wait_cycles+1;
        if(pc_ct_valid) begin
            if(out !== getb1024(CT_EXP, PT_BITS, ct_seen))
                $fatal(1,"CT mismatch at byte %0d. got=%02h expected=%02h",ct_seen,out,getb1024(CT_EXP,PT_BITS,ct_seen));
            ct_seen=ct_seen+1;
        end
        if(tag_valid) begin
            if(out !== getb1024({896'd0,TAG_EXP}, TAG_BITS, tag_seen))
                $fatal(1,"TAG mismatch at byte %0d. got=%02h expected=%02h",tag_seen,out,getb1024({896'd0,TAG_EXP},TAG_BITS,tag_seen));
            tag_seen=tag_seen+1;
        end
        if((ct_seen==51) && (tag_seen==15)) begin
            $display("One-case aad384/pt408/tag120 completed.");
            #20;
            $finish;
        end
    end
    $fatal(1,"Timeout waiting for one-case aad384/pt408/tag120 regression.");
end
endmodule
