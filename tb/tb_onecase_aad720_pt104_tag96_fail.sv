`timescale 1ns / 1ps
module tb_onecase_aad720_pt104_tag96_fail;
logic clk,rst,mode,in_valid,last,pc_ct_valid,tag_valid;
logic [7:0] in,out;
logic [2:0] in_type;
logic [10:0] in_valid_bit,pc_ct_len_bit;
logic [3:0] pc_ct_valid_bit;

localparam logic [255:0] KEY=256'hd2e1ddf323e2cb9f42d2ff2c6563dd921b4c90d89060555e780a1779297d5182;
localparam logic [1023:0] IV=1024'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004173596cd182835b5f1f4377;
localparam integer IV_BITS=96;
localparam logic [1023:0] AAD=1024'h00000000000000000000000000000000000000000000008a728a9b5182b414dd2a75cedffaccb0dab9732a5b971b878423a0934f2b43eb914f54ebfdee72eb16076cfc0dca25d92161e2c70fef7521a713e08e61f9d23a371ce9b132a2daf296e6cce65b667db9457d0e9af2e6b76a0e82;
localparam integer AAD_BITS=720;
localparam logic [1023:0] PT=1024'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d98c22a4bc9be2686fd045d41b;
localparam integer PT_BITS=104;
localparam logic [127:0] TAG_EXP=128'h00000000d3486ea01dedc7ee39bd61fa;
localparam integer TAG_BITS=96;
localparam logic [1023:0] CT_EXP=1024'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009848a064352376e5701f1ba9cf;

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
    while(wait_cycles<60000) begin
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
        if((ct_seen==13) && (tag_seen==12)) begin
            $display("One-case aad720/pt104/tag96 completed.");
            #20;
            $finish;
        end
    end
    $fatal(1,"Timeout waiting for one-case aad720/pt104/tag96 regression.");
end
endmodule
