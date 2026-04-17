`timescale 1ns / 1ps
module AES_e
(
input clk,
input rst_n,
input start,
input [255:0] Key,
input [127:0] word,
output busy,
output finish,
output [127:0] wordout
);
wire fin_AES;
wire Rcon11;
wire busy_nxt3;
reg busy_r;

reg busy_nxt3_r;

reg [127:0] wordout_r;

wire [5:0] Rcon;
reg start_nxt0;
reg start_nxt1;
wire start_detect;
reg fin_nxt0;
reg fin_r;

wire fin_detect;

wire s_box_start;
reg [127:0] s_box_i;
wire s_box_busy;
wire s_box_fin;
wire [127:0] s_box_o;

wire s_row_start;
assign s_row_start = s_box_fin;
wire [127:0] s_row_i;
assign s_row_i = s_box_o;
wire s_row_busy;
wire s_row_fin;
wire [127:0] s_row_o;

wire m_col_start;
reg [127:0] m_col_i;
wire m_col_busy;
wire m_col_fin;
wire [127:0] m_col_o;

reg addr_start;
reg [127:0] addr_i;
wire addr_busy;
wire addr_fin;
wire [127:0] addr_o;


always@(posedge clk)
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

always@(posedge clk)
begin
    if(!rst_n)
    begin
    fin_nxt0 <= 1'b0;
    end
    else
    begin
    fin_nxt0 <= fin_AES;
    end
end
assign fin_detect = fin_AES & !fin_nxt0;

always@(posedge clk)
begin
    if(!rst_n)
    begin
    fin_r <= 1'b0;
    end
    else
    begin
        if(fin_detect)
        begin
        fin_r <= 1'b1;
        end
        else
        begin
            if(start_detect)
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
reg fin_r_d1;
reg fin_r_d2;
wire done;
always@(posedge clk)
begin
    if(!rst_n)
    begin
    fin_r_d1 <= 1'b0;
    fin_r_d2 <= 1'b0;
    end
    else
    begin
    fin_r_d1 <= fin_r;
    fin_r_d2 <= fin_r_d1;
    end
end
assign done = fin_r_d1 && !fin_r_d2;

always@(posedge clk)
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
            if(fin_detect)
            begin
            busy_r <= 1'b0;
            end
            else
            begin
            busy_r <= busy_r;
            end
        end
    end
end

always@(posedge clk)
begin
    if(!rst_n)
    begin
    s_box_i <= 128'd0;
    end
    else
    begin
        if(Rcon11)
        begin
        s_box_i <= s_box_i;
        end
        else
        begin
        s_box_i <= addr_o;
        end
    end
end

always@(posedge clk)
begin
    if(!rst_n)
    begin
    wordout_r <= 128'd0;
    end
    else
    begin
        if(fin_AES)
        begin
        wordout_r <= addr_o;
        end
        else
        begin
        wordout_r <= wordout_r;
        end
    end
end

always@(*)
begin
    case(Rcon)
    4'd1: 
    begin
    addr_i = word;
    end
    4'd2: 
    begin
    addr_i = m_col_o;
    end
    4'd3: 
    begin
    addr_i = m_col_o;
    end
    4'd4: 
    begin
    addr_i = m_col_o;
    end
    4'd5: 
    begin
    addr_i = m_col_o;
    end
    4'd6: 
    begin
    addr_i = m_col_o;
    end
    4'd7: 
    begin
    addr_i = m_col_o;
    end
    4'd8: 
    begin
    addr_i = m_col_o;
    end
    4'd9: 
    begin
    addr_i = m_col_o;
    end
    4'd10: 
    begin
    addr_i = m_col_o;
    end
    4'd11: 
    begin
    addr_i = m_col_o;
    end
    4'd12: 
    begin
    addr_i = m_col_o;
    end    
    4'd13: 
    begin
    addr_i = m_col_o;
    end    
    4'd14: 
    begin
    addr_i = m_col_o;
    end    
    4'd15: 
    begin
    addr_i = s_row_o;
    end    

    default:
    begin
    addr_i = 16'hxx;
    end
    endcase
end

always@(*)
begin
    case(Rcon)
    4'd0: 
    begin
    addr_start = start;
    end
    4'd1:
    begin
    addr_start = m_col_fin;
    end
    4'd2: 
    begin
    addr_start = m_col_fin;
    end
    4'd3: 
    begin
    addr_start = m_col_fin;
    end
    4'd4: 
    begin
    addr_start = m_col_fin;
    end
    4'd5: 
    begin
    addr_start = m_col_fin;
    end
    4'd6: 
    begin
    addr_start = m_col_fin;
    end
    4'd7: 
    begin
    addr_start = m_col_fin;
    end
    4'd8: 
    begin
    addr_start = m_col_fin;
    end
    4'd9: 
    begin
    addr_start = m_col_fin;
    end
    4'd10: 
    begin
    addr_start = m_col_fin;
    end
    4'd11: 
    begin
    addr_start = m_col_fin;
    end
    4'd12: 
    begin
    addr_start = m_col_fin;    
    end
    4'd13: 
    begin
    addr_start = m_col_fin;    
    end
    4'd14: 
    begin
    addr_start = m_col_fin;    
    end
    4'd15:
    begin
    addr_start = start;
    end
    default:
    begin
    addr_start = 1'b0;
    end
    endcase
end

always@(*)
begin
    case(Rcon)
    4'd2: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd3: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd4: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd5: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd6: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd7: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd8: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd9: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd10: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd11: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    4'd12: 
    begin
    busy_nxt3_r = m_col_busy;
    end    
    4'd13: 
    begin
    busy_nxt3_r = m_col_busy;
    end    
    4'd14: 
    begin
    busy_nxt3_r = m_col_busy;
    end    
    4'd15: 
    begin
    busy_nxt3_r = m_col_busy;
    end
    
    default:
    begin
    busy_nxt3_r = 1'b0;
    end
    endcase
end

always@(posedge clk)
begin
    if(!rst_n)
    begin
    m_col_i <= 128'd0;
    end
    else
    begin
        if(Rcon11)
        begin
        m_col_i <= m_col_i;
        end
        else
        begin
        m_col_i <= s_row_o;
        end
    end
end

s_box g2
(
.clk(clk),
.rst_n(rst_n),
.start(s_box_start),
.busy_nxt(s_row_busy),
.din(s_box_i),
.busy(s_box_busy),
.finish(s_box_fin),
.dout(s_box_o)
);

s_row g3
(
.clk(clk),
.rst_n(rst_n),
.start(s_row_start),
.din(s_row_i),
.busy_nxt(busy_nxt3),
.busy(s_row_busy),
.finish(s_row_fin),
.dout(s_row_o)
);

m_col g4
(
.clk(clk),
.rst_n(rst_n),
.start(m_col_start),
.busy_nxt(addr_busy),
.inArr(m_col_i),
.busy(m_col_busy),
.finish(m_col_fin),
.outArr(m_col_o)
);

addr g5
(
.clk(clk),
.rst_n(rst_n),
.start(addr_start),
.Key(Key),
.Rcon(Rcon),
.busy(addr_busy),
.busy_nxt(s_box_busy),
.finish(addr_fin),
.din(addr_i),
.dout(addr_o)
);

assign fin_AES = Rcon11 ? addr_fin: 1'b0;
assign s_box_start = Rcon11 ? 1'b0 : addr_fin;
assign m_col_start = Rcon11 ? 1'b0 : s_row_fin;
assign finish = done;
assign busy = busy_r;
assign wordout = wordout_r;
assign Rcon11 = (Rcon == 4'd15) ? 1'b1 : 1'b0;
assign busy_nxt3 = busy_nxt3_r;

endmodule