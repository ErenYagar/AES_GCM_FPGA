`timescale 1ns / 1ps
module multiply
(
input [7:0] inArr, 
input [7:0] mat, 
output [7:0] outArr
); 
wire [7:0] res;

assign res = inArr[7]? (( inArr << 1) ^ 'h1b) : ( inArr << 1);  
assign outArr = (mat == 'h03 )? res ^ inArr : (mat == 'h02 )? res:inArr;

endmodule 

module multiplyByMat 
(
input [31:0] col,
input [7:0] r1,
input [7:0] r2,
input [7:0] r3,
input [7:0] r4,
output[7:0] s
);
wire [7:0] m1;
wire [7:0] m2;
wire [7:0] m3;
wire [7:0] m4;
multiply g0
(
.inArr(col[31:24]),
.mat(r1),
.outArr(m1)
);

multiply g1
(
.inArr(col[23:16]),
.mat(r2),
.outArr(m2)
);

multiply g2
(
.inArr(col[15:8]),
.mat(r3),
.outArr(m3)
);

multiply g3
(
.inArr(col[7:0]),
.mat(r4),
.outArr(m4)
);

assign s=m1^m2^m3^m4;

endmodule 

module m_col 
(
input clk,
input rst_n,
input start,
input busy_nxt,
input [127:0] inArr,
output busy,
output finish,
output [127:0] outArr
);
reg busy_r;
reg start_nxt0;
reg start_nxt1;
reg done_r;
reg finish_r;
wire start_detect;
reg start_detect1;
wire [127:0] din_lock;
reg [127:0] din_lock_r;
reg [127:0] data_out;
wire [127:0] mcol;

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
    start_detect1 <= 1'b0;
    done_r <= 1'b0;
    end
    else
    begin
    start_detect1 <= start_detect;
    done_r <= start_detect1;
    end
end
assign start_detect = start_nxt0 & !start_nxt1;

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
            if(done_r)
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

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    finish_r <= 1'b0;
    end
    else
    begin
        if(done_r)
        begin
        finish_r <= 1'b1;
        end
        else
        begin
            if(start_detect | busy_nxt)
            begin
            finish_r <= 1'b0;
            end
            else
            begin
            finish_r <= finish_r;
            end
        end
    end
end

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    din_lock_r <= 128'b0;
    end
    else
    begin
        if(start_detect)
        begin
        din_lock_r <= inArr;
        end
        else
        begin
        din_lock_r <= din_lock_r;
        end
    end
end


always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    data_out <= 8'd0;
    end
    else
    begin
        if(!busy)
        begin
        data_out <= data_out;
        end
        else
        begin
        data_out <= mcol;
        end
    end
end

multiplyByMat c11
(
.col(din_lock[127:96]),
.r1(8'h02),
.r2(8'h03),
.r3(8'h01),
.r4(8'h01),
.s(mcol[127:120])
);
multiplyByMat c12
(
.col(din_lock[127:96]),
.r1(8'h01),
.r2(8'h02),
.r3(8'h03),
.r4(8'h01),
.s(mcol[119:112])
);
multiplyByMat c13
(
.col(din_lock[127:96]),
.r1(8'h01),
.r2(8'h01),
.r3(8'h02),
.r4(8'h03),
.s(mcol[111:104])
);
multiplyByMat c14
(
.col(din_lock[127:96]),
.r1(8'h03),
.r2(8'h01),
.r3(8'h01),
.r4(8'h02),
.s(mcol[103:96])
);

multiplyByMat c21
(
.col(din_lock[95:64]),
.r1(8'h02),
.r2(8'h03),
.r3(8'h01),
.r4(8'h01),
.s(mcol[95:88])
);
multiplyByMat c22
(
.col(din_lock[95:64]),
.r1(8'h01),
.r2(8'h02),
.r3(8'h03),
.r4(8'h01), 
.s(mcol[87:80])
);
multiplyByMat c23
(
.col(din_lock[95:64]),
.r1(8'h01),
.r2(8'h01),
.r3(8'h02),
.r4(8'h03), 
.s(mcol[79:72])
);
multiplyByMat c24
(
.col(din_lock[95:64]),
.r1(8'h03),
.r2(8'h01),
.r3(8'h01),
.r4(8'h02),
.s(mcol[71:64])
);

multiplyByMat c31
(
.col(din_lock[63:32]),
.r1(8'h02),
.r2(8'h03),
.r3(8'h01),
.r4(8'h01), 
.s(mcol[63:56])
);
multiplyByMat c32
(
.col(din_lock[63:32]),
.r1(8'h01),
.r2(8'h02),
.r3(8'h03),
.r4(8'h01),
.s(mcol[55:48])
);
multiplyByMat c33
(
.col(din_lock[63:32]),
.r1(8'h01),
.r2(8'h01),
.r3(8'h02),
.r4(8'h03), 
.s(mcol[47:40])
);
multiplyByMat c34
(
.col(din_lock[63:32]),
.r1(8'h03),
.r2(8'h01),
.r3(8'h01),
.r4(8'h02), 
.s(mcol[39:32])
);

multiplyByMat c41
(
.col(din_lock[31:0]),
.r1(8'h02),
.r2(8'h03),
.r3(8'h01),
.r4(8'h01),  
.s(mcol[31:24])
);
multiplyByMat c42
(
.col(din_lock[31:0]),
.r1(8'h01),
.r2(8'h02),
.r3(8'h03),
.r4(8'h01),  
.s(mcol[23:16])
);
multiplyByMat c43
(
.col(din_lock[31:0]),
.r1(8'h01),
.r2(8'h01),
.r3(8'h02),
.r4(8'h03),
.s(mcol[15:8])
);
multiplyByMat c44
(
.col(din_lock[31:0]),
.r1(8'h03),
.r2(8'h01),
.r3(8'h01),
.r4(8'h02),
.s(mcol[7:0])
);

assign busy = busy_r;
assign finish = finish_r;
assign din_lock = din_lock_r;
assign outArr = data_out;

endmodule 