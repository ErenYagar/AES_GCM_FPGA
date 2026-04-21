`timescale 1ns / 1ps

module fpga_top_arty_a7_selftest (
    input  wire       clk,
    input  wire       rst_btn,
    output wire [3:0] led
);

localparam [2:0] TYPE_IV   = 3'd0;
localparam [2:0] TYPE_KEY  = 3'd1;
localparam [2:0] TYPE_AAD  = 3'd2;
localparam [2:0] TYPE_PT   = 3'd3;
localparam [2:0] TYPE_TAG  = 3'd5;
localparam [2:0] TYPE_IDLE = 3'd6;

localparam [255:0] KEY_VEC =
    256'hb52c505a37d78eda5dd34f20c22540ea1b58963cf8e5bf8ffa85f9f2492505b4;
localparam [95:0] IV_VEC   =
    96'h516c33929df5a3284ff463d7;
localparam [127:0] TAG_EXP =
    128'hbdc1ac884d332457a1d2664f168c76f0;

localparam integer KEY_BYTES = 32;
localparam integer IV_BYTES  = 12;
localparam integer TAG_BYTES = 16;

localparam [2:0] ST_WAIT     = 3'd0;
localparam [2:0] ST_KEY      = 3'd1;
localparam [2:0] ST_IV       = 3'd2;
localparam [2:0] ST_AAD_ZERO = 3'd3;
localparam [2:0] ST_PT_ZERO  = 3'd4;
localparam [2:0] ST_TAG      = 3'd5;
localparam [2:0] ST_DONE     = 3'd6;

wire rst;
wire core_clk;
wire core_clk_raw;

reg         mode_reg;
reg  [7:0]  in_reg;
reg         in_valid_reg;
reg  [2:0]  in_type_reg;
reg  [10:0] in_valid_bit_reg;
reg         last_reg;

wire        pc_ct_valid;
wire        tag_valid;
wire [10:0] pc_ct_len_bit;
wire [3:0]  pc_ct_valid_bit;
wire [7:0]  out;

reg  [2:0]  send_state;
reg  [5:0]  send_idx;
reg  [3:0]  warmup_cnt;
reg         test_started;
reg         pass_latched;
reg         fail_latched;
reg  [4:0]  tag_idx;
reg  [19:0] watchdog_cnt;
reg  [25:0] alive_div;
(* KEEP = "TRUE" *) reg [1:0] core_clk_div;

assign rst = ~rst_btn;
assign core_clk_raw = core_clk_div[1];

BUFG u_core_clk_buf (
    .I(core_clk_raw),
    .O(core_clk)
);

top u_core (
    .clk            (core_clk),
    .rst            (rst),
    .mode           (mode_reg),
    .in             (in_reg),
    .in_valid       (in_valid_reg),
    .in_type        (in_type_reg),
    .in_valid_bit   (in_valid_bit_reg),
    .last           (last_reg),
    .pc_ct_valid    (pc_ct_valid),
    .tag_valid      (tag_valid),
    .pc_ct_len_bit  (pc_ct_len_bit),
    .pc_ct_valid_bit(pc_ct_valid_bit),
    .out            (out)
);

function [7:0] get_byte_256;
input [255:0] data_bits;
input integer byte_idx;
integer shift_amt;
begin
    shift_amt = (31 - byte_idx) * 8;
    get_byte_256 = (data_bits >> shift_amt) & 8'hff;
end
endfunction

function [7:0] get_byte_96;
input [95:0] data_bits;
input integer byte_idx;
integer shift_amt;
begin
    shift_amt = (11 - byte_idx) * 8;
    get_byte_96 = (data_bits >> shift_amt) & 8'hff;
end
endfunction

function [7:0] get_byte_128;
input [127:0] data_bits;
input integer byte_idx;
integer shift_amt;
begin
    shift_amt = (15 - byte_idx) * 8;
    get_byte_128 = (data_bits >> shift_amt) & 8'hff;
end
endfunction

always @(posedge clk) begin
    if (rst) begin
        alive_div <= 26'd0;
        core_clk_div <= 2'd0;
    end
    else begin
        alive_div <= alive_div + 26'd1;
        core_clk_div <= core_clk_div + 2'd1;
    end
end

always @(posedge core_clk) begin
    if (rst) begin
        mode_reg         <= 1'b0;
        in_reg           <= 8'd0;
        in_valid_reg     <= 1'b0;
        in_type_reg      <= TYPE_IDLE;
        in_valid_bit_reg <= 11'd0;
        last_reg         <= 1'b0;
        send_state       <= ST_WAIT;
        send_idx         <= 6'd0;
        warmup_cnt       <= 4'd0;
        test_started     <= 1'b0;
        pass_latched     <= 1'b0;
        fail_latched     <= 1'b0;
        tag_idx          <= 5'd0;
        watchdog_cnt     <= 20'd0;
    end
    else begin
        in_valid_reg     <= 1'b0;
        in_type_reg      <= TYPE_IDLE;
        in_valid_bit_reg <= 11'd0;
        last_reg         <= 1'b0;

        if (pc_ct_valid)
            fail_latched <= 1'b1;

        if (tag_valid && !pass_latched && !fail_latched) begin
            if (tag_idx >= 5'd16) begin
                fail_latched <= 1'b1;
            end
            else begin
                if (out != get_byte_128(TAG_EXP, tag_idx))
                    fail_latched <= 1'b1;

                if (tag_idx == (TAG_BYTES - 1)) begin
                    if (out == get_byte_128(TAG_EXP, tag_idx))
                        pass_latched <= 1'b1;
                end
                else begin
                    tag_idx <= tag_idx + 5'd1;
                end
            end
        end

        if (send_state == ST_DONE && !pass_latched && !fail_latched) begin
            watchdog_cnt <= watchdog_cnt + 20'd1;
            if (watchdog_cnt == 20'd999999)
                fail_latched <= 1'b1;
        end
        else begin
            watchdog_cnt <= 20'd0;
        end

        case (send_state)
            ST_WAIT: begin
                if (warmup_cnt == 4'd8) begin
                    test_started <= 1'b1;
                    send_state   <= ST_KEY;
                    send_idx     <= 6'd0;
                end
                else begin
                    warmup_cnt <= warmup_cnt + 4'd1;
                end
            end

            ST_KEY: begin
                in_reg       <= get_byte_256(KEY_VEC, send_idx);
                in_valid_reg <= 1'b1;
                in_type_reg  <= TYPE_KEY;

                if (send_idx == (KEY_BYTES - 1)) begin
                    last_reg         <= 1'b1;
                    in_valid_bit_reg <= 11'd256;
                    send_idx         <= 6'd0;
                    send_state       <= ST_IV;
                end
                else begin
                    send_idx <= send_idx + 6'd1;
                end
            end

            ST_IV: begin
                in_reg       <= get_byte_96(IV_VEC, send_idx);
                in_valid_reg <= 1'b1;
                in_type_reg  <= TYPE_IV;

                if (send_idx == (IV_BYTES - 1)) begin
                    last_reg         <= 1'b1;
                    in_valid_bit_reg <= 11'd96;
                    send_idx         <= 6'd0;
                    send_state       <= ST_AAD_ZERO;
                end
                else begin
                    send_idx <= send_idx + 6'd1;
                end
            end

            ST_AAD_ZERO: begin
                in_reg           <= 8'd0;
                in_valid_reg     <= 1'b1;
                in_type_reg      <= TYPE_AAD;
                in_valid_bit_reg <= 11'd0;
                last_reg         <= 1'b1;
                send_state       <= ST_PT_ZERO;
            end

            ST_PT_ZERO: begin
                in_reg           <= 8'd0;
                in_valid_reg     <= 1'b1;
                in_type_reg      <= TYPE_PT;
                in_valid_bit_reg <= 11'd0;
                last_reg         <= 1'b1;
                send_state       <= ST_TAG;
                send_idx         <= 6'd0;
            end

            ST_TAG: begin
                in_reg       <= 8'd0;
                in_valid_reg <= 1'b1;
                in_type_reg  <= TYPE_TAG;

                if (send_idx == (TAG_BYTES - 1)) begin
                    last_reg         <= 1'b1;
                    in_valid_bit_reg <= 11'd128;
                    send_idx         <= 6'd0;
                    send_state       <= ST_DONE;
                end
                else begin
                    send_idx <= send_idx + 6'd1;
                end
            end

            ST_DONE: begin
            end

            default: begin
                send_state <= ST_WAIT;
            end
        endcase
    end
end

assign led[0] = alive_div[25];
assign led[1] = test_started && !pass_latched && !fail_latched;
assign led[2] = pass_latched;
assign led[3] = fail_latched;

endmodule
