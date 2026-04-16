`timescale 1ns / 1ps

module IV_IN
(
input         clk,
input         rst_n,
input         clear,
input  [7:0]  in,
input         in_valid,
input  [2:0]  in_type,
input  [10:0] in_valid_bit,
input         last,
output [1023:0] iv_data,
output [10:0] iv_len_bits,
output        iv_ready
);

localparam TYPE_IV = 3'd0;

reg [1023:0] iv_data_r;
reg [10:0]   iv_len_bits_r;
reg          iv_ready_r;

function [7:0] mask_last_byte;
input [7:0] byte_in;
input [10:0] total_bits;
integer rem_bits;
integer bit_idx;
begin
    rem_bits = total_bits % 8;

    if ((total_bits == 0) || (rem_bits == 0))
    begin
    mask_last_byte = byte_in;
    end
    else
    begin
        mask_last_byte = 8'd0;
        for (bit_idx = 0; bit_idx < rem_bits; bit_idx = bit_idx + 1)
        begin
            mask_last_byte[7 - bit_idx] = byte_in[7 - bit_idx];
        end
    end
end
endfunction

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    iv_data_r     <= 1024'd0;
    iv_len_bits_r <= 11'd0;
    iv_ready_r    <= 1'b0;
    end
    else
    begin
        if(clear)
        begin
        iv_data_r     <= 1024'd0;
        iv_len_bits_r <= 11'd0;
        iv_ready_r    <= 1'b0;
        end
        else
        begin
            if(in_valid && (in_type == TYPE_IV))
            begin
                if(last && (in_valid_bit == 11'd0))
                begin
                iv_len_bits_r <= 11'd0;
                iv_ready_r    <= 1'b1;
                end
                else
                begin
                    if(last)
                    begin
                    iv_data_r     <= {iv_data_r[1015:0], mask_last_byte(in, in_valid_bit)};
                    iv_len_bits_r <= in_valid_bit;
                    iv_ready_r    <= 1'b1;
                    end
                    else
                    begin
                    iv_data_r <= {iv_data_r[1015:0], in};
                    end
                end
            end
        end
    end
end

assign iv_data     = iv_data_r;
assign iv_len_bits = iv_len_bits_r;
assign iv_ready    = iv_ready_r;

endmodule
