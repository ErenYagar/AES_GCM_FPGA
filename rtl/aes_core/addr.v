`timescale 1ns / 1ps
module addr
(
input clk,
input rst_n,
input start,
input busy_nxt,
input [255:0] Key,
input [127:0] din,
output [5:0] Rcon,
output busy,
output finish,
output [127:0] dout
);
reg [127:0] dout_r;
reg busy_r;
reg start_nxt0;
reg start_nxt1;
reg fin_r;
reg [5:0] Rcon_r;

wire start_detect;
wire [127:0] key0;
wire [127:0] key1;
wire [127:0] key2;
wire [127:0] key3;
wire [127:0] key4;
wire [127:0] key5;
wire [127:0] key6;
wire [127:0] key7;
wire [127:0] key8;
wire [127:0] key9;
wire [127:0] key10;
wire [127:0] key11;
wire [127:0] key12;
wire [127:0] key13;
wire [127:0] key14;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    start_nxt0 <= 1'b0;
    start_nxt1 <= 1'b0;
    end
    else
    begin
    start_nxt0 <= start;
    start_nxt1 <= start_nxt0;
    end
end
assign start_detect = start_nxt0 & !start_nxt1;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    Rcon_r <= 6'd0;
    end
    else
    begin
        if(!start_detect)
        begin
        Rcon_r <= Rcon_r;
        end
        else
        begin
            if( Rcon_r != 6'd15)
            begin
            Rcon_r <= Rcon_r + 6'd1;
            end
            else
            begin
            Rcon_r <= 6'd1;
            end
        end
    end
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    busy_r <= 1'b0;
    end
    else
    begin
        if(start_detect)
        begin
        busy_r <= 1'b1;
        end
        else
        begin
        busy_r <= 1'b0;
        end
    end
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    fin_r <= 1'b0;
    end
    else
    begin
        if(busy_r)
        begin
        fin_r <= 1'b1;
        end
        else
        begin
            if(start_detect | busy_nxt)
            begin
            fin_r <= 1'b0;
            end
            else
            begin
            fin_r <= fin_r;
            end
        end
    end
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    dout_r <= 128'd0;
    end
    else
    begin
        if(!busy)
        begin
        dout_r <= dout_r;
        end
        else
        begin
            case(Rcon_r)
            6'd1:
            begin
            dout_r <= din ^ key0;
            end
            6'd2:
            begin
            dout_r <= din ^ key1;
            end
            6'd3:
            begin
            dout_r <= din ^ key2;
            end
            6'd4:
            begin
            dout_r <= din ^ key3;
            end
            6'd5:
            begin
            dout_r <= din ^ key4;
            end
            6'd6:
            begin
            dout_r <= din ^ key5;
            end
            6'd7:
           begin
            dout_r <= din ^ key6;
            end
            6'd8:
            begin
            dout_r <= din ^ key7;
            end
            6'd9:
            begin
            dout_r <= din ^ key8;
            end
            6'd10:
            begin
            dout_r <= din ^ key9;
            end
            6'd11:
            begin
            dout_r <= din ^ key10;
            end
            6'd12:
            begin
            dout_r <= din ^ key11;
            end
            6'd13:
            begin
            dout_r <= din ^ key12;
            end
            6'd14:
            begin
            dout_r <= din ^ key13;
            end
            6'd15:
            begin
            dout_r <= din ^ key14;
            end
            default:
            begin
            dout_r <= dout_r;
            end
            endcase
        end
    end
end
wire [255:0] key_rc1;
wire [255:0] key_rc2;
wire [255:0] key_rc3;
wire [255:0] key_rc4;
wire [255:0] key_rc5;
wire [255:0] key_rc6;
wire [255:0] key_rc7;

assign key0 = Key[255:128];
assign key1 = Key[127:0];
assign key2 = key_rc1[255:128];
assign key3 = key_rc1[127:0];
assign key4 = key_rc2[255:128];
assign key5 = key_rc2[127:0];
assign key6 =  key_rc3[255:128];
assign key7 =  key_rc3[127:0];
assign key8 = key_rc4[255:128]; 
assign key9 = key_rc4[127:0];   
assign key10 =  key_rc5[255:128]; 
assign key11 = key_rc5[127:0];   
assign key12 = key_rc6[255:128]; 
assign key13 = key_rc6[127:0];   
assign key14 = key_rc7[255:128]; 
assign key15 = key_rc7[127:0];   

KeyGeneration rc1 (.clk(clk), .rst_n(rst_n), .rc(4'd1)   ,.key(Key) ,  .keyout(key_rc1));
KeyGeneration rc2 (.clk(clk), .rst_n(rst_n), .rc(4'd2)   ,.key(key_rc1) , .keyout(key_rc2));
KeyGeneration rc3 (.clk(clk), .rst_n(rst_n), .rc(4'd3)   ,.key(key_rc2) , .keyout(key_rc3));
KeyGeneration rc4 (.clk(clk), .rst_n(rst_n), .rc(4'd4)   ,.key(key_rc3) , .keyout(key_rc4));
KeyGeneration rc5 (.clk(clk), .rst_n(rst_n), .rc(4'd5)   ,.key(key_rc4) , .keyout(key_rc5));
KeyGeneration rc6 (.clk(clk), .rst_n(rst_n), .rc(4'd6)   ,.key(key_rc5) , .keyout(key_rc6));
KeyGeneration rc7 (.clk(clk), .rst_n(rst_n), .rc(4'd7)   ,.key(key_rc6) , .keyout(key_rc7));

assign Rcon = Rcon_r;
assign busy = busy_r;
assign finish = fin_r;
assign dout = dout_r;
endmodule