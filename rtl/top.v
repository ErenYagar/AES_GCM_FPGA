`timescale 1ns / 1ps

module top
(
input         clk,
input         rst,
input         mode,
input  [7:0]  in,
input         in_valid,
input  [2:0]  in_type,
input  [10:0] in_valid_bit,
input         last,
output reg    pc_ct_valid,
output reg    tag_valid,
output reg [10:0] pc_ct_len_bit,
output reg [3:0] pc_ct_valid_bit,
output reg [7:0] out
);

localparam TYPE_IV  = 3'd0;
localparam TYPE_KEY = 3'd1;
localparam TYPE_AAD = 3'd2;
localparam TYPE_PT  = 3'd3;
localparam TYPE_CT  = 3'd4;
localparam TYPE_TAG = 3'd5;

localparam ST_COLLECT        = 5'd0;
localparam ST_H_START        = 5'd1;
localparam ST_H_WAIT         = 5'd2;
localparam ST_H_LOAD         = 5'd3;
localparam ST_J0_INIT        = 5'd4;
localparam ST_J0_PUSH        = 5'd5;
localparam ST_J0_WAIT        = 5'd6;
localparam ST_J0_LEN_PUSH    = 5'd7;
localparam ST_J0_LEN_WAIT    = 5'd8;
localparam ST_DATA_PREP      = 5'd9;
localparam ST_DATA_START     = 5'd10;
localparam ST_DATA_WAIT      = 5'd11;
localparam ST_GHASH_INIT     = 5'd12;
localparam ST_GHASH_AAD_PUSH = 5'd13;
localparam ST_GHASH_AAD_WAIT = 5'd14;
localparam ST_GHASH_CT_PUSH  = 5'd15;
localparam ST_GHASH_CT_WAIT  = 5'd16;
localparam ST_GHASH_LEN_PUSH = 5'd17;
localparam ST_GHASH_LEN_WAIT = 5'd18;
localparam ST_TAG_START      = 5'd19;
localparam ST_TAG_WAIT       = 5'd20;
localparam ST_OUT_PC         = 5'd21;
localparam ST_OUT_TAG        = 5'd22;
localparam ST_OUT_DEC_STATUS = 5'd23;
localparam ST_CLEAR          = 5'd24;

wire rst_n;
assign rst_n = ~rst;

wire [1023:0] iv_data;
wire [10:0]   iv_len_bits;
wire          iv_ready;

wire [1023:0] aad_data;
wire [10:0]   aad_len_bits;
wire          aad_ready;
wire [1023:0] pt_data;
wire [10:0]   pt_len_bits;
wire          pt_ready;
wire [1023:0] ct_data;
wire [10:0]   ct_len_bits;
wire          ct_ready;
wire [127:0]  tag_data;
wire [10:0]   tag_len_bits;
wire          tag_ready;

reg          clear_collectors;

reg  [255:0] key_reg;
reg  [5:0]   key_byte_count;
reg          key_ready;

reg          mode_reg;
reg  [4:0]   state;
reg  [127:0] h_reg;
reg  [127:0] j0_reg;
reg  [127:0] ctr_nonce_reg;
reg  [1023:0] pc_out_buf;
reg  [10:0]  pc_out_len_bits;
reg  [1023:0] tag_out_buf;
reg  [10:0]  tag_out_len_bits;
reg          auth_ok;

reg  [3:0]   data_block_idx;
reg  [3:0]   aad_block_idx;
reg  [3:0]   ct_block_idx;
reg  [6:0]   out_byte_idx;

reg          hcalc_start;
reg  [255:0] hcalc_key;
reg  [127:0] hcalc_word;
wire         hcalc_busy;
wire         hcalc_done;
wire [127:0] hcalc_wordout;

reg          data_start;
reg  [127:0] data_nonce;
reg  [127:0] data_plaintext;
reg  [7:0]   data_valid_bits;
reg  [255:0] data_key;
wire [127:0] data_ciphertext;
wire         data_done;

reg          tag_start;
reg  [127:0] tag_nonce;
reg  [127:0] tag_plaintext;
reg  [7:0]   tag_valid_bits_cfg;
reg  [255:0] tag_key;
wire [127:0] tag_ciphertext;
wire         tag_done;

reg          ghash_init;
reg  [127:0] ghash_block;
reg          ghash_en;
reg  [127:0] ghash_h;
reg          ghash_h_done;
wire         ghash_busy;
wire         ghash_done;
wire [127:0] ghash_y;

wire collect_en;
assign collect_en = (state == ST_COLLECT) ? in_valid : 1'b0;

IV_IN u_iv_in (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear      (clear_collectors),
    .in         (in),
    .in_valid   (collect_en),
    .in_type    (in_type),
    .in_valid_bit(in_valid_bit),
    .last       (last),
    .iv_data    (iv_data),
    .iv_len_bits(iv_len_bits),
    .iv_ready   (iv_ready)
);

AAD_CT_IN u_aad_ct_in (
    .clk        (clk),
    .rst_n      (rst_n),
    .clear      (clear_collectors),
    .in         (in),
    .in_valid   (collect_en),
    .in_type    (in_type),
    .in_valid_bit(in_valid_bit),
    .last       (last),
    .aad_data   (aad_data),
    .aad_len_bits(aad_len_bits),
    .aad_ready  (aad_ready),
    .pt_data    (pt_data),
    .pt_len_bits(pt_len_bits),
    .pt_ready   (pt_ready),
    .ct_data    (ct_data),
    .ct_len_bits(ct_len_bits),
    .ct_ready   (ct_ready),
    .tag_data   (tag_data),
    .tag_len_bits(tag_len_bits),
    .tag_ready  (tag_ready)
);

AES_e u_hcalc (
    .clk    (clk),
    .rst_n  (rst_n),
    .start  (hcalc_start),
    .Key    (hcalc_key),
    .word   (hcalc_word),
    .busy   (hcalc_busy),
    .finish (hcalc_done),
    .wordout(hcalc_wordout)
);

aes_ctr_wrapper u_data_ctr (
    .clk       (clk),
    .rst_n     (rst_n),
    .start     (data_start),
    .nonce     (data_nonce),
    .plaintext (data_plaintext),
    .valid_bits(data_valid_bits),
    .key       (data_key),
    .ciphertext(data_ciphertext),
    .done      (data_done)
);

aes_ctr_wrapper u_tag_ctr (
    .clk       (clk),
    .rst_n     (rst_n),
    .start     (tag_start),
    .nonce     (tag_nonce),
    .plaintext (tag_plaintext),
    .valid_bits(tag_valid_bits_cfg),
    .key       (tag_key),
    .ciphertext(tag_ciphertext),
    .done      (tag_done)
);

GHASH u_ghash (
    .clk        (clk),
    .rst_n      (rst_n),
    .init       (ghash_init),
    .GHASH_block(ghash_block),
    .GHASH_en   (ghash_en),
    .H          (ghash_h),
    .H_done     (ghash_h_done),
    .busy       (ghash_busy),
    .done       (ghash_done),
    .Y          (ghash_y)
);

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

function [127:0] inc32;
input [127:0] counter_in;
begin
    inc32 = {counter_in[127:32], counter_in[31:0] + 32'd1};
end
endfunction

function integer block_count;
input [10:0] total_bits;
begin
    if (total_bits == 11'd0)
        block_count = 0;
    else
        block_count = (total_bits + 11'd127) / 11'd128;
end
endfunction

function [7:0] block_valid_count;
input [10:0] total_bits;
input integer blk_idx;
integer bits_left;
begin
    bits_left = total_bits - (blk_idx * 128);
    if (bits_left >= 128)
        block_valid_count = 8'd128;
    else if (bits_left <= 0)
        block_valid_count = 8'd0;
    else
        block_valid_count = bits_left[7:0];
end
endfunction

function [127:0] extract_block_1024;
input [1023:0] data_bits;
input [10:0] total_bits;
input integer blk_idx;
integer total_bytes;
integer block_byte_start;
integer bytes_left;
integer block_bytes;
integer byte_idx;
integer src_byte_idx;
reg [127:0] tmp;
begin
    tmp = 128'd0;
    total_bytes      = (total_bits + 11'd7) / 11'd8;
    block_byte_start = blk_idx * 16;
    bytes_left       = total_bytes - block_byte_start;

    if (bytes_left < 0)
        bytes_left = 0;

    if (bytes_left > 16)
        block_bytes = 16;
    else
        block_bytes = bytes_left;

    for (byte_idx = 0; byte_idx < block_bytes; byte_idx = byte_idx + 1)
    begin
        src_byte_idx = block_byte_start + byte_idx;
        tmp[127 - (byte_idx * 8) -: 8] = data_bits[((total_bytes - 1 - src_byte_idx) * 8) +: 8];
    end

    extract_block_1024 = tmp;
end
endfunction

function [127:0] compact_block_to_128;
input [127:0] block_in;
input [10:0] total_bits;
integer total_bytes;
integer byte_idx;
reg [127:0] tmp;
begin
    tmp = 128'd0;
    total_bytes = (total_bits + 11'd7) / 11'd8;

    for (byte_idx = 0; byte_idx < total_bytes; byte_idx = byte_idx + 1)
    begin
        tmp = {tmp[119:0], block_in[127 - (byte_idx * 8) -: 8]};
    end

    compact_block_to_128 = tmp;
end
endfunction

function [7:0] get_buffer_byte_1024;
input [1023:0] data_bits;
input [10:0] total_bits;
input integer byte_idx;
integer total_bytes;
begin
    total_bytes = (total_bits + 11'd7) / 11'd8;
    if (byte_idx < total_bytes)
        get_buffer_byte_1024 = data_bits[((total_bytes - 1 - byte_idx) * 8) +: 8];
    else
        get_buffer_byte_1024 = 8'd0;
end
endfunction

function [3:0] get_byte_valid_bits;
input [10:0] total_bits;
input integer byte_idx;
integer total_bytes;
integer rem_bits;
begin
    total_bytes = (total_bits + 11'd7) / 11'd8;
    rem_bits    = total_bits % 8;

    if (total_bytes == 0)
        get_byte_valid_bits = 4'd0;
    else if (byte_idx < (total_bytes - 1))
        get_byte_valid_bits = 4'd8;
    else if (rem_bits == 0)
        get_byte_valid_bits = 4'd8;
    else
        get_byte_valid_bits = rem_bits[3:0];
end
endfunction

task store_block_to_buffer;
input      [127:0] block_in;
input      [10:0] total_bits;
input      integer blk_idx;
inout reg [1023:0] data_bits;
integer total_bytes;
integer block_byte_start;
integer bytes_left;
integer block_bytes;
integer byte_idx;
integer dst_byte_idx;
begin
    total_bytes      = (total_bits + 11'd7) / 11'd8;
    block_byte_start = blk_idx * 16;
    bytes_left       = total_bytes - block_byte_start;

    if (bytes_left < 0)
        bytes_left = 0;

    if (bytes_left > 16)
        block_bytes = 16;
    else
        block_bytes = bytes_left;

    for (byte_idx = 0; byte_idx < block_bytes; byte_idx = byte_idx + 1)
    begin
        dst_byte_idx = block_byte_start + byte_idx;
        data_bits[((total_bytes - 1 - dst_byte_idx) * 8) +: 8] = block_in[127 - (byte_idx * 8) -: 8];
    end
end
endtask

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
    key_reg           <= 256'd0;
    key_byte_count    <= 6'd0;
    key_ready         <= 1'b0;
    mode_reg          <= 1'b0;
    state             <= ST_COLLECT;
    h_reg             <= 128'd0;
    j0_reg            <= 128'd0;
    ctr_nonce_reg     <= 128'd0;
    pc_out_buf        <= 1024'd0;
    pc_out_len_bits   <= 11'd0;
    tag_out_buf       <= 1024'd0;
    tag_out_len_bits  <= 11'd0;
    auth_ok           <= 1'b0;
    data_block_idx    <= 4'd0;
    aad_block_idx     <= 4'd0;
    ct_block_idx      <= 4'd0;
    out_byte_idx      <= 7'd0;
    hcalc_start       <= 1'b0;
    hcalc_key         <= 256'd0;
    hcalc_word        <= 128'd0;
    data_start        <= 1'b0;
    data_nonce        <= 128'd0;
    data_plaintext    <= 128'd0;
    data_valid_bits   <= 8'd128;
    data_key          <= 256'd0;
    tag_start         <= 1'b0;
    tag_nonce         <= 128'd0;
    tag_plaintext     <= 128'd0;
    tag_valid_bits_cfg<= 8'd128;
    tag_key           <= 256'd0;
    ghash_init        <= 1'b0;
    ghash_block       <= 128'd0;
    ghash_en          <= 1'b0;
    ghash_h           <= 128'd0;
    ghash_h_done      <= 1'b0;
    clear_collectors  <= 1'b0;
    pc_ct_valid       <= 1'b0;
    tag_valid         <= 1'b0;
    pc_ct_len_bit     <= 11'd0;
    pc_ct_valid_bit   <= 4'd0;
    out               <= 8'd0;
    end
    else
    begin
        hcalc_start      <= 1'b0;
        data_start       <= 1'b0;
        tag_start        <= 1'b0;
        ghash_init       <= 1'b0;
        ghash_en         <= 1'b0;
        ghash_h_done     <= 1'b0;
        clear_collectors <= 1'b0;
        pc_ct_valid      <= 1'b0;
        tag_valid        <= 1'b0;
        pc_ct_len_bit    <= pc_ct_len_bit;
        pc_ct_valid_bit  <= 4'd0;

        if((state == ST_COLLECT) && in_valid && (in_type == TYPE_KEY))
        begin
            if(last && (in_valid_bit == 11'd0) && (key_byte_count == 6'd0))
            begin
            key_reg        <= 256'd0;
            key_byte_count <= 6'd0;
            key_ready      <= 1'b0;
            end
            else
            begin
            key_reg <= {key_reg[247:0], last ? mask_last_byte(in, in_valid_bit) : in};

                if(last)
                begin
                key_byte_count <= 6'd0;
                key_ready      <= 1'b1;
                end
                else
                begin
                key_byte_count <= key_byte_count + 6'd1;
                end
            end
        end

        case (state)
            ST_COLLECT:
            begin
                if(mode)
                begin
                    if(key_ready && iv_ready && aad_ready && ct_ready && tag_ready)
                    begin
                    mode_reg <= 1'b1;
                    state    <= ST_H_START;
                    end
                end
                else
                begin
                    if(key_ready && iv_ready && aad_ready && pt_ready && tag_ready)
                    begin
                    mode_reg <= 1'b0;
                    state    <= ST_H_START;
                    end
                end
            end

            ST_H_START:
            begin
                hcalc_key   <= key_reg;
                hcalc_word  <= 128'd0;
                hcalc_start <= 1'b1;
                state       <= ST_H_WAIT;
            end

            ST_H_WAIT:
            begin
                if(hcalc_done)
                begin
                h_reg <= hcalc_wordout;
                ghash_h <= hcalc_wordout;
                state <= ST_H_LOAD;
                end
            end

            ST_H_LOAD:
            begin
                ghash_h_done <= 1'b1;
                if(iv_len_bits == 11'd96)
                begin
                j0_reg <= {iv_data[95:0], 32'h00000001};
                state  <= ST_DATA_PREP;
                end
                else
                begin
                state <= ST_J0_INIT;
                end
            end

            ST_J0_INIT:
            begin
                ghash_init     <= 1'b1;
                data_block_idx <= 4'd0;
                state          <= ST_J0_PUSH;
            end

            ST_J0_PUSH:
            begin
                if(data_block_idx < block_count(iv_len_bits))
                begin
                ghash_block <= extract_block_1024(iv_data, iv_len_bits, data_block_idx);
                ghash_en    <= 1'b1;
                state       <= ST_J0_WAIT;
                end
                else
                begin
                state <= ST_J0_LEN_PUSH;
                end
            end

            ST_J0_WAIT:
            begin
                if(ghash_done)
                begin
                data_block_idx <= data_block_idx + 4'd1;
                state          <= ST_J0_PUSH;
                end
            end

            ST_J0_LEN_PUSH:
            begin
                ghash_block <= {{53'd0, 11'd0}, {53'd0, iv_len_bits}};
                ghash_en    <= 1'b1;
                state       <= ST_J0_LEN_WAIT;
            end

            ST_J0_LEN_WAIT:
            begin
                if(ghash_done)
                begin
                j0_reg <= ghash_y;
                state  <= ST_DATA_PREP;
                end
            end

            ST_DATA_PREP:
            begin
                pc_out_buf      <= 1024'd0;
                pc_out_len_bits <= mode_reg ? ct_len_bits : pt_len_bits;
                pc_ct_len_bit   <= mode_reg ? ct_len_bits : pt_len_bits;
                tag_out_buf     <= 1024'd0;
                tag_out_len_bits<= tag_len_bits;
                ctr_nonce_reg   <= inc32(j0_reg);
                data_block_idx  <= 4'd0;

                if(block_count(mode_reg ? ct_len_bits : pt_len_bits) == 0)
                    state <= ST_GHASH_INIT;
                else
                    state <= ST_DATA_START;
            end

            ST_DATA_START:
            begin
                data_nonce      <= ctr_nonce_reg;
                data_plaintext  <= mode_reg ? extract_block_1024(ct_data, ct_len_bits, data_block_idx)
                                            : extract_block_1024(pt_data, pt_len_bits, data_block_idx);
                data_valid_bits <= block_valid_count(mode_reg ? ct_len_bits : pt_len_bits, data_block_idx);
                data_key        <= key_reg;
                data_start      <= 1'b1;
                state           <= ST_DATA_WAIT;
            end

            ST_DATA_WAIT:
            begin
                if(data_done)
                begin
                store_block_to_buffer(data_ciphertext, pc_out_len_bits, data_block_idx, pc_out_buf);
                ctr_nonce_reg <= ctr_nonce_reg + 128'd1;

                    if((data_block_idx + 4'd1) < block_count(pc_out_len_bits))
                    begin
                    data_block_idx <= data_block_idx + 4'd1;
                    state          <= ST_DATA_START;
                    end
                    else
                    begin
                    state <= ST_GHASH_INIT;
                    end
                end
            end

            ST_GHASH_INIT:
            begin
                ghash_init    <= 1'b1;
                aad_block_idx <= 4'd0;
                ct_block_idx  <= 4'd0;
                state         <= ST_GHASH_AAD_PUSH;
            end

            ST_GHASH_AAD_PUSH:
            begin
                if(aad_block_idx < block_count(aad_len_bits))
                begin
                ghash_block <= extract_block_1024(aad_data, aad_len_bits, aad_block_idx);
                ghash_en    <= 1'b1;
                state       <= ST_GHASH_AAD_WAIT;
                end
                else
                begin
                state <= ST_GHASH_CT_PUSH;
                end
            end

            ST_GHASH_AAD_WAIT:
            begin
                if(ghash_done)
                begin
                aad_block_idx <= aad_block_idx + 4'd1;
                state         <= ST_GHASH_AAD_PUSH;
                end
            end

            ST_GHASH_CT_PUSH:
            begin
                if(ct_block_idx < block_count(mode_reg ? ct_len_bits : pt_len_bits))
                begin
                ghash_block <= mode_reg ? extract_block_1024(ct_data, ct_len_bits, ct_block_idx)
                                        : extract_block_1024(pc_out_buf, pt_len_bits, ct_block_idx);
                ghash_en    <= 1'b1;
                state       <= ST_GHASH_CT_WAIT;
                end
                else
                begin
                state <= ST_GHASH_LEN_PUSH;
                end
            end

            ST_GHASH_CT_WAIT:
            begin
                if(ghash_done)
                begin
                ct_block_idx <= ct_block_idx + 4'd1;
                state        <= ST_GHASH_CT_PUSH;
                end
            end

            ST_GHASH_LEN_PUSH:
            begin
                ghash_block <= {{53'd0, aad_len_bits}, {53'd0, (mode_reg ? ct_len_bits : pt_len_bits)}};
                ghash_en    <= 1'b1;
                state       <= ST_GHASH_LEN_WAIT;
            end

            ST_GHASH_LEN_WAIT:
            begin
                if(ghash_done)
                begin
                state <= ST_TAG_START;
                end
            end

            ST_TAG_START:
            begin
                tag_nonce          <= j0_reg;
                tag_plaintext      <= ghash_y;
                tag_valid_bits_cfg <= 8'd128;
                tag_key            <= key_reg;
                tag_start          <= 1'b1;
                state              <= ST_TAG_WAIT;
            end

            ST_TAG_WAIT:
            begin
                if(tag_done)
                begin
                tag_out_buf <= {896'd0, compact_block_to_128(tag_ciphertext, {3'd0, tag_len_bits})};
                auth_ok     <= (compact_block_to_128(tag_ciphertext, {3'd0, tag_len_bits}) == tag_data);
                out_byte_idx <= 7'd0;

                    if(mode_reg)
                    begin
                        if(compact_block_to_128(tag_ciphertext, {3'd0, tag_len_bits}) == tag_data)
                        begin
                            if(pc_out_len_bits != 11'd0)
                            begin
                            state <= ST_OUT_PC;
                            end
                            else
                            begin
                            state <= ST_OUT_DEC_STATUS;
                            end
                        end
                        else
                        begin
                        state <= ST_CLEAR;
                        end
                    end
                    else if(pc_out_len_bits != 11'd0)
                    begin
                    state <= ST_OUT_PC;
                    end
                    else if(tag_len_bits != 11'd0)
                    begin
                    state <= ST_OUT_TAG;
                    end
                    else
                    begin
                    state <= ST_CLEAR;
                    end
                end
            end

            ST_OUT_PC:
            begin
                out             <= get_buffer_byte_1024(pc_out_buf, pc_out_len_bits, out_byte_idx);
                pc_ct_valid     <= 1'b1;
                pc_ct_valid_bit <= get_byte_valid_bits(pc_out_len_bits, out_byte_idx);

                if((out_byte_idx + 7'd1) >= ((pc_out_len_bits + 11'd7) / 11'd8))
                begin
                out_byte_idx <= 7'd0;
                    if(mode_reg)
                    begin
                    state <= ST_OUT_DEC_STATUS;
                    end
                    else if(tag_out_len_bits != 11'd0)
                    begin
                    state <= ST_OUT_TAG;
                    end
                    else
                    begin
                    state <= ST_CLEAR;
                    end
                end
                else
                begin
                out_byte_idx <= out_byte_idx + 7'd1;
                end
            end

            ST_OUT_TAG:
            begin
                out       <= get_buffer_byte_1024(tag_out_buf, tag_out_len_bits, out_byte_idx);
                tag_valid <= 1'b1;

                if((out_byte_idx + 7'd1) >= ((tag_out_len_bits + 11'd7) / 11'd8))
                begin
                out_byte_idx <= 7'd0;
                state        <= ST_CLEAR;
                end
                else
                begin
                out_byte_idx <= out_byte_idx + 7'd1;
                end
            end

            ST_OUT_DEC_STATUS:
            begin
                tag_valid <= auth_ok;
                state     <= ST_CLEAR;
            end

            ST_CLEAR:
            begin
                clear_collectors <= 1'b1;
                key_reg          <= 256'd0;
                key_byte_count   <= 6'd0;
                key_ready        <= 1'b0;
                pc_out_buf       <= 1024'd0;
                pc_out_len_bits  <= 11'd0;
                pc_ct_len_bit    <= 11'd0;
                tag_out_buf      <= 1024'd0;
                tag_out_len_bits <= 11'd0;
                auth_ok          <= 1'b0;
                state            <= ST_COLLECT;
            end

            default:
            begin
                state <= ST_COLLECT;
            end
        endcase
    end
end

endmodule
