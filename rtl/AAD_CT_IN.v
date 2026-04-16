`timescale 1ns / 1ps

module AAD_CT_IN
(
input           clk,
input           rst_n,
input           clear,
input  [7:0]    in,
input           in_valid,
input  [2:0]    in_type,
input  [10:0]   in_valid_bit,
input           last,
output [1023:0] aad_data,
output [10:0]   aad_len_bits,
output          aad_ready,
output [1023:0] pt_data,
output [10:0]   pt_len_bits,
output          pt_ready,
output [1023:0] ct_data,
output [10:0]   ct_len_bits,
output          ct_ready,
output [127:0]  tag_data,
output [10:0]   tag_len_bits,
output          tag_ready
);

localparam TYPE_AAD = 3'd2;
localparam TYPE_PT  = 3'd3;
localparam TYPE_CT  = 3'd4;
localparam TYPE_TAG = 3'd5;

reg [1023:0] aad_data_r;
reg [10:0]   aad_len_bits_r;
reg          aad_ready_r;

reg [1023:0] pt_data_r;
reg [10:0]   pt_len_bits_r;
reg          pt_ready_r;

reg [1023:0] ct_data_r;
reg [10:0]   ct_len_bits_r;
reg          ct_ready_r;

reg [127:0]  tag_data_r;
reg [10:0]   tag_len_bits_r;
reg          tag_ready_r;

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
    aad_data_r     <= 1024'd0;
    aad_len_bits_r <= 11'd0;
    aad_ready_r    <= 1'b0;
    pt_data_r      <= 1024'd0;
    pt_len_bits_r  <= 11'd0;
    pt_ready_r     <= 1'b0;
    ct_data_r      <= 1024'd0;
    ct_len_bits_r  <= 11'd0;
    ct_ready_r     <= 1'b0;
    tag_data_r     <= 128'd0;
    tag_len_bits_r <= 11'd0;
    tag_ready_r    <= 1'b0;
    end
    else
    begin
        if(clear)
        begin
        aad_data_r     <= 1024'd0;
        aad_len_bits_r <= 11'd0;
        aad_ready_r    <= 1'b0;
        pt_data_r      <= 1024'd0;
        pt_len_bits_r  <= 11'd0;
        pt_ready_r     <= 1'b0;
        ct_data_r      <= 1024'd0;
        ct_len_bits_r  <= 11'd0;
        ct_ready_r     <= 1'b0;
        tag_data_r     <= 128'd0;
        tag_len_bits_r <= 11'd0;
        tag_ready_r    <= 1'b0;
        end
        else
        begin
            if(in_valid)
            begin
                case (in_type)
                    TYPE_AAD:
                    begin
                        if(last && (in_valid_bit == 11'd0))
                        begin
                        aad_len_bits_r <= 11'd0;
                        aad_ready_r    <= 1'b1;
                        end
                        else
                        begin
                            if(last)
                            begin
                            aad_data_r     <= {aad_data_r[1015:0], mask_last_byte(in, in_valid_bit)};
                            aad_len_bits_r <= in_valid_bit;
                            aad_ready_r    <= 1'b1;
                            end
                            else
                            begin
                            aad_data_r <= {aad_data_r[1015:0], in};
                            end
                        end
                    end

                    TYPE_PT:
                    begin
                        if(last && (in_valid_bit == 11'd0))
                        begin
                        pt_len_bits_r <= 11'd0;
                        pt_ready_r    <= 1'b1;
                        end
                        else
                        begin
                            if(last)
                            begin
                            pt_data_r     <= {pt_data_r[1015:0], mask_last_byte(in, in_valid_bit)};
                            pt_len_bits_r <= in_valid_bit;
                            pt_ready_r    <= 1'b1;
                            end
                            else
                            begin
                            pt_data_r <= {pt_data_r[1015:0], in};
                            end
                        end
                    end

                    TYPE_CT:
                    begin
                        if(last && (in_valid_bit == 11'd0))
                        begin
                        ct_len_bits_r <= 11'd0;
                        ct_ready_r    <= 1'b1;
                        end
                        else
                        begin
                            if(last)
                            begin
                            ct_data_r     <= {ct_data_r[1015:0], mask_last_byte(in, in_valid_bit)};
                            ct_len_bits_r <= in_valid_bit;
                            ct_ready_r    <= 1'b1;
                            end
                            else
                            begin
                            ct_data_r <= {ct_data_r[1015:0], in};
                            end
                        end
                    end

                    TYPE_TAG:
                    begin
                        if(last && (in_valid_bit == 11'd0))
                        begin
                        tag_len_bits_r <= 11'd0;
                        tag_ready_r    <= 1'b1;
                        end
                        else
                        begin
                            if(last)
                            begin
                            tag_data_r     <= {tag_data_r[119:0], mask_last_byte(in, in_valid_bit)};
                            tag_len_bits_r <= in_valid_bit;
                            tag_ready_r    <= 1'b1;
                            end
                            else
                            begin
                            tag_data_r <= {tag_data_r[119:0], in};
                            end
                        end
                    end

                    default:
                    begin
                    end
                endcase
            end
        end
    end
end

assign aad_data     = aad_data_r;
assign aad_len_bits = aad_len_bits_r;
assign aad_ready    = aad_ready_r;
assign pt_data      = pt_data_r;
assign pt_len_bits  = pt_len_bits_r;
assign pt_ready     = pt_ready_r;
assign ct_data      = ct_data_r;
assign ct_len_bits  = ct_len_bits_r;
assign ct_ready     = ct_ready_r;
assign tag_data     = tag_data_r;
assign tag_len_bits = tag_len_bits_r;
assign tag_ready    = tag_ready_r;

endmodule
