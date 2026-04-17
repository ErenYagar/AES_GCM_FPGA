`timescale 1ns / 1ps
module s_row
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
wire start_detect;
reg [7:0] state [0:15];   

reg start_detect_nxt1;

always@(posedge clk)
begin
    if(!rst_n)
    begin
    state[0]  <= 8'd0;
    state[1]  <= 8'd0;
    state[2]  <= 8'd0;
    state[3]  <= 8'd0;
                     
    state[4]  <= 8'd0;
    state[5]  <= 8'd0;
    state[6]  <= 8'd0;
    state[7]  <= 8'd0;
                     
    state[8]  <= 8'd0;
    state[9]  <= 8'd0;
    state[10] <= 8'd0;
    state[11] <= 8'd0;
                     
    state[12] <= 8'd0;
    state[13] <= 8'd0;
    state[14] <= 8'd0;
    state[15] <= 8'd0;
    end
    else
    begin
        if(start_detect)
        begin
        state[0]  <= din[127:120];
        state[1]  <= din[119:112];
        state[2]  <= din[111:104];
        state[3]  <= din[103:96];
                     
        state[4]  <= din[95:88];
        state[5]  <= din[87:80];
        state[6]  <= din[79:72];
        state[7]  <= din[71:64];
                     
        state[8]  <= din[63:56];
        state[9]  <= din[55:48];
        state[10] <= din[47:40];
        state[11] <= din[39:32];
                     
        state[12] <= din[31:24];
        state[13] <= din[23:16];
        state[14] <= din[15:8];
        state[15] <= din[7:0];

        end
        else
        begin
        state[0]  <=  state[0];
        state[1]  <=  state[1];
        state[2]  <=  state[2];
        state[3]  <=  state[3];
                              
        state[4]  <=  state[4];
        state[5]  <=  state[5];
        state[6]  <=  state[6];
        state[7]  <=  state[7];
                              
        state[8]  <=  state[8];
        state[9]  <=  state[9];
        state[10] <=  state[10];
        state[11] <=  state[11];
                              
        state[12] <=  state[12];
        state[13] <=  state[13];
        state[14] <=  state[14];
        state[15] <=  state[15];
        end
    end
end
reg [7:0] shifted [0:15]; 
always@(posedge clk)
begin
    if(!rst_n)
    begin
    shifted[0]  <= 8'd0;     
    shifted[4]  <= 8'd0;     
    shifted[8]  <= 8'd0;     
    shifted[12] <= 8'd0;                                

    shifted[1]  <= 8'd0;     
    shifted[5]  <= 8'd0;     
    shifted[9]  <= 8'd0;    
    shifted[13] <= 8'd0;     

    shifted[2]  <= 8'd0;    
    shifted[6]  <= 8'd0;    
    shifted[10] <= 8'd0;     
    shifted[14] <= 8'd0;     

    shifted[3]  <= 8'd0;    
    shifted[7]  <= 8'd0;     
    shifted[11] <= 8'd0;     
    shifted[15] <= 8'd0;                
    end
    else
    begin
        if(start_detect_nxt1)
        begin
        shifted[0]  <= state[0];     
        shifted[4]  <= state[4];     
        shifted[8]  <= state[8];     
        shifted[12] <= state[12];    
                                                  
        shifted[1]  <= state[5];     
        shifted[5]  <= state[9];     
        shifted[9]  <= state[13];    
        shifted[13] <= state[1];     
                                     
        shifted[2]  <= state[10];    
        shifted[6]  <= state[14];    
        shifted[10] <= state[2];     
        shifted[14] <= state[6];     
                           
        shifted[3]  <= state[15];    
        shifted[7]  <= state[3];     
        shifted[11] <= state[7];     
        shifted[15] <= state[11];
        end
        else
        begin
        shifted[0]  <= shifted[0] ;     
        shifted[4]  <= shifted[4] ;     
        shifted[8]  <= shifted[8] ;     
        shifted[12] <= shifted[12];                                

        shifted[1]  <= shifted[1] ;     
        shifted[5]  <= shifted[5] ;     
        shifted[9]  <= shifted[9] ;    
        shifted[13] <= shifted[13];     

        shifted[2]  <= shifted[2] ;    
        shifted[6]  <= shifted[6] ;    
        shifted[10] <= shifted[10];     
        shifted[14] <= shifted[14];     

        shifted[3]  <= shifted[3] ;    
        shifted[7]  <= shifted[7] ;     
        shifted[11] <= shifted[11];     
        shifted[15] <= shifted[15];
        end
    end
end

always@(posedge clk)
begin
    if(!rst_n)
    begin
    data_out <= 128'd0;
    end
    else
    begin
        if(busy)
        begin
        data_out <= {
        shifted[0], shifted[1], shifted[2], shifted[3],
        shifted[4], shifted[5], shifted[6], shifted[7],
        shifted[8], shifted[9], shifted[10], shifted[11],
        shifted[12], shifted[13], shifted[14], shifted[15]
        };
        end
        else
        begin
        data_out <= data_out;
        end
    end
end

always@(posedge clk)
begin
    if(!rst_n)
    begin
    busy_r <= 1'b0;
    end
    else
    begin
        if(start_nxt0)
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
    start_detect_nxt1 <= 1'b0;
    end
    else
    begin
    start_detect_nxt1 <= start_detect;
    end
end

assign dout = data_out;
assign busy = busy_r;
assign finish = finish_r;

endmodule