`timescale 1ns / 1ps
module s_box
(
input clk,
input rst_n,
input start,
input busy_nxt,
input [127:0] din,
output busy,
output finish,
output [127:0] dout
);
reg busy_r;
reg [127:0] data_out;
reg start_nxt0;
reg start_nxt1;
reg start_nxt2;
reg done_r;
reg finish_r;
reg [127:0] din_lock_r;
wire start_detect;
wire [127:0] din_lock;
wire [127:0] sbox;

always@(posedge clk)
begin
    if(!rst_n)
    begin
    busy_r <= 1'b0;
    end
    else
    begin
        if(start_nxt1)
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

always@(posedge clk)
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
 
always@(posedge clk)
begin
    if(!rst_n)
    begin
    start_nxt0 <= 1'b0;
    start_nxt1 <= 1'b0;
    start_nxt2 <= 1'b0;
    done_r <= 1'b0;
    end
    else
    begin
    start_nxt0 <= start;
    start_nxt1 <= start_nxt0;
    start_nxt2 <= start_nxt1;
    done_r <= start_nxt2;
    end
end
assign start_detect = start_nxt0 & !start_nxt1;

always@(posedge clk)
begin
    if(!rst_n)
    begin
    din_lock_r <= 128'b0;
    end
    else
    begin
        if(start_detect)
        begin
        din_lock_r <= din;
        end
        else
        begin
        din_lock_r <= din_lock_r;
        end
    end
end

always@(posedge clk)
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
        data_out <= sbox;
        end
    end
end

sbox q0
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[7:0]),
.co(sbox[7:0])
);

sbox q1
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[15:8]),
.co(sbox[15:8])
);

sbox q2
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[23:16]),
.co(sbox[23:16])
);

sbox q3
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[31:24]),
.co(sbox[31:24])
);

sbox q4
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[39:32]),
.co(sbox[39:32])
);

sbox q5
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[47:40]),
.co(sbox[47:40])
);

sbox q6
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[55:48]),
.co(sbox[55:48])
);

sbox q7
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[63:56]),
.co(sbox[63:56])
);

sbox q8
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[71:64]),
.co(sbox[71:64])
);

sbox q9
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[79:72]),
.co(sbox[79:72])
);

sbox q10
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[87:80]),
.co(sbox[87:80])
);

sbox q11
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[95:88]),
.co(sbox[95:88])
);

sbox q12
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[103:96]),
.co(sbox[103:96])
);

sbox q13
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[111:104]),
.co(sbox[111:104])
);

sbox q14
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[119:112]),
.co(sbox[119:112])
);

sbox q15
(
.clk(clk),
.rst_n(rst_n),
.a(din_lock[127:120]),
.co(sbox[127:120])
);

assign dout = data_out;
assign busy = busy_r;
assign finish = finish_r;
assign din_lock = din_lock_r;

endmodule