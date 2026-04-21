`timescale 1ns / 1ps

module fpga_top_arty_a7_uart (
    input  wire       clk,
    input  wire       rst_btn,
    input  wire       uart_txd_in,
    output wire       uart_rxd_out,
    output wire [3:0] led
);

localparam [2:0] TYPE_IV   = 3'd0;
localparam [2:0] TYPE_KEY  = 3'd1;
localparam [2:0] TYPE_AAD  = 3'd2;
localparam [2:0] TYPE_PT   = 3'd3;
localparam [2:0] TYPE_CT   = 3'd4;
localparam [2:0] TYPE_TAG  = 3'd5;
localparam [2:0] TYPE_IDLE = 3'd6;

localparam [7:0] CMD_MODE = 8'h01;
localparam [7:0] CMD_KEY  = 8'h02;
localparam [7:0] CMD_IV   = 8'h03;
localparam [7:0] CMD_AAD  = 8'h04;
localparam [7:0] CMD_PT   = 8'h05;
localparam [7:0] CMD_CT   = 8'h06;
localparam [7:0] CMD_TAG  = 8'h07;
localparam [7:0] CMD_RUN  = 8'h08;
localparam [7:0] CMD_DEBUG = 8'h09;

localparam [7:0] RSP_STATUS = 8'h80;
localparam [7:0] RSP_PC     = 8'h81;
localparam [7:0] RSP_TAG    = 8'h82;
localparam [7:0] RSP_DEBUG_HDR  = 8'h90;
localparam [7:0] RSP_DEBUG_IV   = 8'h91;
localparam [7:0] RSP_DEBUG_AAD  = 8'h92;
localparam [7:0] RSP_DEBUG_DATA = 8'h93;
localparam [7:0] RSP_DEBUG_TAG  = 8'h94;

localparam [7:0] STAT_ENC_OK    = 8'h00;
localparam [7:0] STAT_DEC_OK    = 8'h01;
localparam [7:0] STAT_AUTH_FAIL = 8'hff;
localparam [7:0] STAT_BAD_CFG   = 8'hfe;
localparam [7:0] STAT_BUSY      = 8'hfd;

localparam [1:0] RX_ST_CMD     = 2'd0;
localparam [1:0] RX_ST_LEN_HI  = 2'd1;
localparam [1:0] RX_ST_LEN_LO  = 2'd2;
localparam [1:0] RX_ST_PAYLOAD = 2'd3;

localparam [3:0] ENG_IDLE        = 4'd0;
localparam [3:0] ENG_WARMUP      = 4'd1;
localparam [3:0] ENG_SEND_KEY    = 4'd2;
localparam [3:0] ENG_SEND_IV     = 4'd3;
localparam [3:0] ENG_SEND_AAD    = 4'd4;
localparam [3:0] ENG_SEND_DATA   = 4'd5;
localparam [3:0] ENG_SEND_TAG    = 4'd6;
localparam [3:0] ENG_WAIT_RESULT = 4'd7;
localparam [3:0] ENG_RESPOND     = 4'd8;
localparam [3:0] ENG_COOLDOWN    = 4'd9;
localparam [3:0] ENG_CORE_RESET  = 4'd10;
localparam [3:0] ENG_DEBUG_RESPOND = 4'd11;
localparam [3:0] ENG_FIELD_GAP   = 4'd12;

localparam integer UART_CLKS_PER_BIT = 217;
localparam integer UART_TIMEOUT_MAX  = 20'd999999;

wire rst;
wire core_clk;
wire core_clk_mmcm;
wire sys_rst;
wire core_rst;
wire mmcm_clkfb;
wire mmcm_locked;

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

reg  [255:0] key_cfg;
reg          key_loaded;
reg          mode_cfg;
reg          mode_loaded;
reg  [1023:0] iv_cfg;
reg  [10:0]   iv_len_cfg;
reg           iv_loaded;
reg  [1023:0] aad_cfg;
reg  [10:0]   aad_len_cfg;
reg           aad_loaded;
reg  [1023:0] pt_cfg;
reg  [10:0]   pt_len_cfg;
reg           pt_loaded;
reg  [1023:0] ct_cfg;
reg  [10:0]   ct_len_cfg;
reg           ct_loaded;
reg  [127:0]  tag_cfg;
reg  [10:0]   tag_len_cfg;
reg           tag_loaded;

wire [7:0] rx_data;
wire       rx_valid;
wire       rx_busy;

reg        tx_start_reg;
reg [7:0]  tx_data_reg;
wire       tx_busy;
wire       tx_done;

reg  [1:0]  rx_state;
reg  [7:0]  rx_cmd;
reg  [15:0] rx_len_bits;
reg  [7:0]  rx_payload_bytes;
reg  [7:0]  rx_byte_idx;
reg         run_request;
reg         debug_dump_request;

reg  [3:0]  eng_state;
reg  [3:0]  eng_next_state;
reg  [7:0]  eng_send_idx;
reg  [5:0]  warmup_cnt;
reg  [5:0]  core_reset_cnt;
reg  [19:0] wait_watchdog;
reg  [3:0]  cooldown_cnt;
reg         core_reset_reg;

reg  [1023:0] pc_capture_buf;
reg  [10:0]   pc_capture_len_bits;
reg  [7:0]    pc_capture_count;
reg  [3:0]    pc_last_valid_bits;
reg  [127:0]  tag_capture_buf;
reg  [10:0]   tag_capture_len_bits;
reg  [4:0]    tag_capture_count;
reg           auth_pass_seen;
reg  [7:0]    status_code_reg;
reg           result_valid;

reg           frame_active;
reg  [1:0]    frame_phase;
reg  [7:0]    frame_type;
reg  [15:0]   frame_len_bits;
reg  [1023:0] frame_payload_buf;
reg  [7:0]    frame_payload_bytes;
reg  [7:0]    frame_byte_idx;
reg           frame_done;
reg           frame_load_req;
reg  [7:0]    frame_load_type;
reg  [15:0]   frame_load_len_bits;
reg  [1023:0] frame_load_payload;
reg  [7:0]    frame_load_payload_bytes;
reg  [1:0]    resp_stage;
reg           status_only_pending;
reg  [7:0]    status_only_code;
reg           send_status_pending;
reg           send_pc_pending;
reg           send_tag_pending;
reg           send_debug_hdr_pending;
reg           send_debug_iv_pending;
reg           send_debug_aad_pending;
reg           send_debug_data_pending;
reg           send_debug_tag_pending;

reg  [25:0] alive_div = 26'd0;

wire run_fields_ready;

assign rst = ~rst_btn;
assign sys_rst = rst | ~mmcm_locked;
assign core_rst = sys_rst | core_reset_reg;

MMCME2_BASE #(
    .BANDWIDTH("OPTIMIZED"),
    .CLKIN1_PERIOD(10.000),
    .CLKFBOUT_MULT_F(10.0),
    .DIVCLK_DIVIDE(1),
    .CLKOUT0_DIVIDE_F(40.0),
    .CLKOUT0_DUTY_CYCLE(0.5),
    .CLKOUT0_PHASE(0.0),
    .CLKOUT1_DIVIDE(1),
    .CLKOUT2_DIVIDE(1),
    .CLKOUT3_DIVIDE(1),
    .CLKOUT4_DIVIDE(1),
    .CLKOUT5_DIVIDE(1),
    .CLKOUT6_DIVIDE(1),
    .CLKFBOUT_PHASE(0.0),
    .REF_JITTER1(0.010),
    .STARTUP_WAIT("FALSE")
) u_mmcm (
    .CLKIN1   (clk),
    .CLKFBIN  (mmcm_clkfb),
    .RST      (rst),
    .PWRDWN   (1'b0),
    .CLKFBOUT (mmcm_clkfb),
    .CLKOUT0  (core_clk_mmcm),
    .CLKOUT0B (),
    .CLKOUT1  (),
    .CLKOUT1B (),
    .CLKOUT2  (),
    .CLKOUT2B (),
    .CLKOUT3  (),
    .CLKOUT3B (),
    .CLKOUT4  (),
    .CLKOUT5  (),
    .CLKOUT6  (),
    .LOCKED   (mmcm_locked)
);

BUFG u_core_clk_buf (
    .I(core_clk_mmcm),
    .O(core_clk)
);

top u_core (
    .clk            (core_clk),
    .rst            (core_rst),
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

uart_rx #(
    .CLKS_PER_BIT(UART_CLKS_PER_BIT)
) u_uart_rx (
    .clk       (core_clk),
    .rst       (sys_rst),
    .rx        (uart_txd_in),
    .data      (rx_data),
    .data_valid(rx_valid),
    .busy      (rx_busy)
);

uart_tx #(
    .CLKS_PER_BIT(UART_CLKS_PER_BIT)
) u_uart_tx (
    .clk  (core_clk),
    .rst  (sys_rst),
    .start(tx_start_reg),
    .data (tx_data_reg),
    .tx   (uart_rxd_out),
    .busy (tx_busy),
    .done (tx_done)
);

function integer byte_count_from_bits;
input [15:0] total_bits;
begin
    if (total_bits == 16'd0)
        byte_count_from_bits = 0;
    else
        byte_count_from_bits = (total_bits + 16'd7) / 16'd8;
end
endfunction

function [7:0] get_buffer_byte_1024;
input [1023:0] data_bits;
input [15:0]   total_bits;
input integer  byte_idx;
integer total_bytes;
integer shift_amt;
begin
    total_bytes = byte_count_from_bits(total_bits);
    if (byte_idx < total_bytes) begin
        shift_amt = (total_bytes - 1 - byte_idx) * 8;
        get_buffer_byte_1024 = (data_bits >> shift_amt) & 8'hff;
    end
    else begin
        get_buffer_byte_1024 = 8'd0;
    end
end
endfunction

function [7:0] get_buffer_byte_256;
input [255:0] data_bits;
input integer byte_idx;
integer shift_amt;
begin
    shift_amt = (31 - byte_idx) * 8;
    get_buffer_byte_256 = (data_bits >> shift_amt) & 8'hff;
end
endfunction

assign run_fields_ready =
    key_loaded &&
    mode_loaded &&
    iv_loaded  &&
    aad_loaded &&
    tag_loaded &&
    (mode_cfg ? ct_loaded : pt_loaded);

function status_to_led_fail;
input [7:0] status_in;
begin
    if ((status_in == STAT_ENC_OK) || (status_in == STAT_DEC_OK))
        status_to_led_fail = 1'b0;
    else
        status_to_led_fail = 1'b1;
end
endfunction

always @(posedge clk) begin
    if (rst)
        alive_div <= 26'd0;
    else
        alive_div <= alive_div + 26'd1;
end

always @(posedge core_clk) begin
    if (sys_rst) begin
        mode_reg            <= 1'b0;
        in_reg              <= 8'd0;
        in_valid_reg        <= 1'b0;
        in_type_reg         <= TYPE_IDLE;
        in_valid_bit_reg    <= 11'd0;
        last_reg            <= 1'b0;
        key_cfg             <= 256'd0;
        key_loaded          <= 1'b0;
        mode_cfg            <= 1'b0;
        mode_loaded         <= 1'b0;
        iv_cfg              <= 1024'd0;
        iv_len_cfg          <= 11'd0;
        iv_loaded           <= 1'b0;
        aad_cfg             <= 1024'd0;
        aad_len_cfg         <= 11'd0;
        aad_loaded          <= 1'b0;
        pt_cfg              <= 1024'd0;
        pt_len_cfg          <= 11'd0;
        pt_loaded           <= 1'b0;
        ct_cfg              <= 1024'd0;
        ct_len_cfg          <= 11'd0;
        ct_loaded           <= 1'b0;
        tag_cfg             <= 128'd0;
        tag_len_cfg         <= 11'd0;
        tag_loaded          <= 1'b0;
        rx_state            <= RX_ST_CMD;
        rx_cmd              <= 8'd0;
        rx_len_bits         <= 16'd0;
        rx_payload_bytes    <= 8'd0;
        rx_byte_idx         <= 8'd0;
        run_request         <= 1'b0;
        debug_dump_request  <= 1'b0;
        eng_state           <= ENG_IDLE;
        eng_next_state      <= ENG_IDLE;
        eng_send_idx        <= 8'd0;
        warmup_cnt          <= 6'd0;
        core_reset_cnt      <= 6'd0;
        wait_watchdog       <= 20'd0;
        cooldown_cnt        <= 4'd0;
        core_reset_reg      <= 1'b0;
        pc_capture_buf      <= 1024'd0;
        pc_capture_len_bits <= 11'd0;
        pc_capture_count    <= 8'd0;
        pc_last_valid_bits  <= 4'd0;
        tag_capture_buf     <= 128'd0;
        tag_capture_len_bits<= 11'd0;
        tag_capture_count   <= 5'd0;
        auth_pass_seen      <= 1'b0;
        status_code_reg     <= STAT_BAD_CFG;
        result_valid        <= 1'b0;
        tx_start_reg        <= 1'b0;
        tx_data_reg         <= 8'd0;
        frame_active        <= 1'b0;
        frame_phase         <= 2'd0;
        frame_type          <= 8'd0;
        frame_len_bits      <= 16'd0;
        frame_payload_buf   <= 1024'd0;
        frame_payload_bytes <= 8'd0;
        frame_byte_idx      <= 8'd0;
        frame_done          <= 1'b0;
        frame_load_req      <= 1'b0;
        frame_load_type     <= 8'd0;
        frame_load_len_bits <= 16'd0;
        frame_load_payload  <= 1024'd0;
        frame_load_payload_bytes <= 8'd0;
        resp_stage          <= 2'd0;
        status_only_pending <= 1'b0;
        status_only_code    <= STAT_BAD_CFG;
        send_status_pending <= 1'b0;
        send_pc_pending     <= 1'b0;
        send_tag_pending    <= 1'b0;
        send_debug_hdr_pending  <= 1'b0;
        send_debug_iv_pending   <= 1'b0;
        send_debug_aad_pending  <= 1'b0;
        send_debug_data_pending <= 1'b0;
        send_debug_tag_pending  <= 1'b0;
    end
    else begin
        in_valid_reg     <= 1'b0;
        in_type_reg      <= TYPE_IDLE;
        in_valid_bit_reg <= 11'd0;
        last_reg         <= 1'b0;
        tx_start_reg     <= 1'b0;
        frame_done       <= 1'b0;
        frame_load_req   <= 1'b0;

        if (frame_active && !tx_busy && !tx_start_reg) begin
            case (frame_phase)
                2'd0: begin
                    tx_data_reg <= frame_type;
                    tx_start_reg <= 1'b1;
                    frame_phase <= 2'd1;
                end

                2'd1: begin
                    tx_data_reg <= frame_len_bits[15:8];
                    tx_start_reg <= 1'b1;
                    frame_phase <= 2'd2;
                end

                2'd2: begin
                    tx_data_reg <= frame_len_bits[7:0];
                    tx_start_reg <= 1'b1;
                    if (frame_payload_bytes == 8'd0) begin
                        frame_active <= 1'b0;
                        frame_done   <= 1'b1;
                        frame_phase  <= 2'd0;
                        frame_byte_idx <= 8'd0;
                    end
                    else begin
                        frame_phase <= 2'd3;
                    end
                end

                default: begin
                    tx_data_reg <= get_buffer_byte_1024(frame_payload_buf, frame_len_bits, frame_byte_idx);
                    tx_start_reg <= 1'b1;
                    if (frame_byte_idx == (frame_payload_bytes - 1)) begin
                        frame_active   <= 1'b0;
                        frame_done     <= 1'b1;
                        frame_phase    <= 2'd0;
                        frame_byte_idx <= 8'd0;
                    end
                    else begin
                        frame_byte_idx <= frame_byte_idx + 8'd1;
                    end
                end
            endcase
        end

        if (frame_load_req) begin
            frame_active        <= 1'b1;
            frame_phase         <= 2'd0;
            frame_type          <= frame_load_type;
            frame_len_bits      <= frame_load_len_bits;
            frame_payload_buf   <= frame_load_payload;
            frame_payload_bytes <= frame_load_payload_bytes;
            frame_byte_idx      <= 8'd0;
        end

        if (rx_valid) begin
            case (rx_state)
                RX_ST_CMD: begin
                    rx_cmd   <= rx_data;
                    rx_state <= RX_ST_LEN_HI;
                end

                RX_ST_LEN_HI: begin
                    rx_len_bits[15:8] <= rx_data;
                    rx_state          <= RX_ST_LEN_LO;
                end

                RX_ST_LEN_LO: begin
                    rx_len_bits[7:0]  <= rx_data;
                    rx_payload_bytes   <= byte_count_from_bits({rx_len_bits[15:8], rx_data});
                    rx_byte_idx        <= 8'd0;
                    rx_state           <= (byte_count_from_bits({rx_len_bits[15:8], rx_data}) == 0) ? RX_ST_CMD : RX_ST_PAYLOAD;

                    case (rx_cmd)
                        CMD_KEY: key_cfg <= 256'd0;
                        CMD_IV:  iv_cfg  <= 1024'd0;
                        CMD_AAD: aad_cfg <= 1024'd0;
                        CMD_PT:  pt_cfg  <= 1024'd0;
                        CMD_CT:  ct_cfg  <= 1024'd0;
                        CMD_TAG: tag_cfg <= 128'd0;
                        default: begin end
                    endcase

                    if (byte_count_from_bits({rx_len_bits[15:8], rx_data}) == 0) begin
                        case (rx_cmd)
                            CMD_AAD: begin
                                aad_len_cfg <= 11'd0;
                                aad_loaded  <= 1'b1;
                            end
                            CMD_PT: begin
                                pt_len_cfg <= 11'd0;
                                pt_loaded  <= 1'b1;
                            end
                            CMD_CT: begin
                                ct_len_cfg <= 11'd0;
                                ct_loaded  <= 1'b1;
                            end
                            CMD_TAG: begin
                                tag_len_cfg <= 11'd0;
                                tag_loaded  <= 1'b1;
                            end
                            CMD_RUN: begin
                                if ((eng_state == ENG_IDLE) && !frame_active && !tx_busy) begin
                                    if (run_fields_ready)
                                        run_request <= 1'b1;
                                    else begin
                                        status_only_pending <= 1'b1;
                                        status_only_code    <= STAT_BAD_CFG;
                                        result_valid        <= 1'b1;
                                        status_code_reg     <= STAT_BAD_CFG;
                                    end
                                end
                                else begin
                                    status_only_pending <= 1'b1;
                                    status_only_code    <= STAT_BUSY;
                                    result_valid        <= 1'b1;
                                    status_code_reg     <= STAT_BUSY;
                                end
                            end
                            CMD_DEBUG: begin
                                if ((eng_state == ENG_IDLE) && !frame_active && !tx_busy)
                                    debug_dump_request <= 1'b1;
                                else begin
                                    status_only_pending <= 1'b1;
                                    status_only_code    <= STAT_BUSY;
                                    result_valid        <= 1'b1;
                                    status_code_reg     <= STAT_BUSY;
                                end
                            end
                            default: begin end
                        endcase
                    end
                end

                default: begin
                    case (rx_cmd)
                        CMD_MODE: begin
                            if (rx_byte_idx == 8'd0)
                                mode_cfg <= rx_data[0];
                        end
                        CMD_KEY: key_cfg <= {key_cfg[247:0], rx_data};
                        CMD_IV:  iv_cfg  <= {iv_cfg[1015:0], rx_data};
                        CMD_AAD: aad_cfg <= {aad_cfg[1015:0], rx_data};
                        CMD_PT:  pt_cfg  <= {pt_cfg[1015:0], rx_data};
                        CMD_CT:  ct_cfg  <= {ct_cfg[1015:0], rx_data};
                        CMD_TAG: tag_cfg <= {tag_cfg[119:0], rx_data};
                        default: begin end
                    endcase

                    if (rx_byte_idx == (rx_payload_bytes - 1)) begin
                        case (rx_cmd)
                            CMD_MODE: begin
                                mode_loaded <= ({rx_len_bits[15:8], rx_len_bits[7:0]} == 16'd8);
                            end

                            CMD_KEY: begin
                                key_loaded <= ({rx_len_bits[15:8], rx_len_bits[7:0]} == 16'd256);
                            end

                            CMD_IV: begin
                                iv_len_cfg <= rx_len_bits[10:0];
                                iv_loaded  <= 1'b1;
                            end

                            CMD_AAD: begin
                                aad_len_cfg <= rx_len_bits[10:0];
                                aad_loaded  <= 1'b1;
                            end

                            CMD_PT: begin
                                pt_len_cfg <= rx_len_bits[10:0];
                                pt_loaded  <= 1'b1;
                            end

                            CMD_CT: begin
                                ct_len_cfg <= rx_len_bits[10:0];
                                ct_loaded  <= 1'b1;
                            end

                            CMD_TAG: begin
                                tag_len_cfg <= rx_len_bits[10:0];
                                tag_loaded  <= 1'b1;
                            end

                            default: begin end
                        endcase

                        rx_state <= RX_ST_CMD;
                    end
                    else begin
                        rx_byte_idx <= rx_byte_idx + 8'd1;
                    end
                end
            endcase
        end

        case (eng_state)
            ENG_IDLE: begin
                eng_send_idx  <= 8'd0;
                warmup_cnt    <= 6'd0;
                wait_watchdog <= 20'd0;
                cooldown_cnt  <= 4'd0;

                if (status_only_pending && !frame_active && !tx_busy && !frame_load_req && !tx_start_reg) begin
                    frame_load_req         <= 1'b1;
                    frame_load_type        <= RSP_STATUS;
                    frame_load_len_bits    <= 16'd8;
                    frame_load_payload     <= {1016'd0, status_only_code};
                    frame_load_payload_bytes <= 8'd1;
                    status_only_pending    <= 1'b0;
                    eng_state              <= ENG_COOLDOWN;
                    cooldown_cnt           <= 4'd0;
                end
                else if (debug_dump_request && !frame_active && !tx_busy && !frame_load_req && !tx_start_reg) begin
                    debug_dump_request     <= 1'b0;
                    send_debug_hdr_pending <= 1'b1;
                    send_debug_iv_pending  <= iv_loaded  && (iv_len_cfg  != 11'd0);
                    send_debug_aad_pending <= aad_loaded && (aad_len_cfg != 11'd0);
                    send_debug_data_pending <= mode_cfg ? (ct_loaded && (ct_len_cfg != 11'd0))
                                                        : (pt_loaded && (pt_len_cfg != 11'd0));
                    send_debug_tag_pending <= tag_loaded && (tag_len_cfg != 11'd0);
                    eng_state              <= ENG_DEBUG_RESPOND;
                end
                else if (run_request && !frame_active && !tx_busy && !frame_load_req && !tx_start_reg) begin
                    run_request          <= 1'b0;
                    mode_reg             <= mode_cfg;
                    result_valid         <= 1'b0;
                    status_code_reg      <= STAT_BAD_CFG;
                    pc_capture_buf       <= 1024'd0;
                    pc_capture_len_bits  <= 11'd0;
                    pc_capture_count     <= 8'd0;
                    pc_last_valid_bits   <= 4'd0;
                    tag_capture_buf      <= 128'd0;
                    tag_capture_len_bits <= tag_len_cfg;
                    tag_capture_count    <= 5'd0;
                    auth_pass_seen       <= 1'b0;
                    resp_stage           <= 2'd0;
                    send_status_pending  <= 1'b0;
                    send_pc_pending      <= 1'b0;
                    send_tag_pending     <= 1'b0;
                    send_debug_hdr_pending  <= 1'b0;
                    send_debug_iv_pending   <= 1'b0;
                    send_debug_aad_pending  <= 1'b0;
                    send_debug_data_pending <= 1'b0;
                    send_debug_tag_pending  <= 1'b0;
                    core_reset_reg       <= 1'b1;
                    core_reset_cnt       <= 6'd0;
                    eng_state            <= ENG_CORE_RESET;
                end
            end

            ENG_CORE_RESET: begin
                core_reset_reg <= 1'b1;
                if (core_reset_cnt == 6'd31) begin
                    core_reset_reg <= 1'b0;
                    warmup_cnt     <= 6'd0;
                    eng_state      <= ENG_WARMUP;
                end
                else begin
                    core_reset_cnt <= core_reset_cnt + 6'd1;
                end
            end

            ENG_WARMUP: begin
                if (warmup_cnt == 6'd31) begin
                    eng_state   <= ENG_SEND_KEY;
                    eng_send_idx <= 8'd0;
                end
                else begin
                    warmup_cnt <= warmup_cnt + 6'd1;
                end
            end

            ENG_SEND_KEY: begin
                in_reg       <= get_buffer_byte_256(key_cfg, eng_send_idx);
                in_valid_reg <= 1'b1;
                in_type_reg  <= TYPE_KEY;

                if (eng_send_idx == 8'd31) begin
                    last_reg         <= 1'b1;
                    in_valid_bit_reg <= 11'd256;
                    eng_send_idx     <= 8'd0;
                    eng_next_state   <= ENG_SEND_IV;
                    eng_state        <= ENG_FIELD_GAP;
                end
                else begin
                    eng_send_idx <= eng_send_idx + 8'd1;
                end
            end

            ENG_SEND_IV: begin
                if (iv_len_cfg == 11'd0) begin
                    in_reg           <= 8'd0;
                    in_valid_reg     <= 1'b1;
                    in_type_reg      <= TYPE_IV;
                    in_valid_bit_reg <= 11'd0;
                    last_reg         <= 1'b1;
                    eng_next_state   <= ENG_SEND_AAD;
                    eng_state        <= ENG_FIELD_GAP;
                end
                else begin
                    in_reg       <= get_buffer_byte_1024(iv_cfg, {5'd0, iv_len_cfg}, eng_send_idx);
                    in_valid_reg <= 1'b1;
                    in_type_reg  <= TYPE_IV;

                    if (eng_send_idx == (byte_count_from_bits({5'd0, iv_len_cfg}) - 1)) begin
                        last_reg         <= 1'b1;
                        in_valid_bit_reg <= iv_len_cfg;
                        eng_send_idx     <= 8'd0;
                        eng_next_state   <= ENG_SEND_AAD;
                        eng_state        <= ENG_FIELD_GAP;
                    end
                    else begin
                        eng_send_idx <= eng_send_idx + 8'd1;
                    end
                end
            end

            ENG_SEND_AAD: begin
                if (aad_len_cfg == 11'd0) begin
                    in_reg           <= 8'd0;
                    in_valid_reg     <= 1'b1;
                    in_type_reg      <= TYPE_AAD;
                    in_valid_bit_reg <= 11'd0;
                    last_reg         <= 1'b1;
                    eng_next_state   <= ENG_SEND_DATA;
                    eng_state        <= ENG_FIELD_GAP;
                end
                else begin
                    in_reg       <= get_buffer_byte_1024(aad_cfg, {5'd0, aad_len_cfg}, eng_send_idx);
                    in_valid_reg <= 1'b1;
                    in_type_reg  <= TYPE_AAD;

                    if (eng_send_idx == (byte_count_from_bits({5'd0, aad_len_cfg}) - 1)) begin
                        last_reg         <= 1'b1;
                        in_valid_bit_reg <= aad_len_cfg;
                        eng_send_idx     <= 8'd0;
                        eng_next_state   <= ENG_SEND_DATA;
                        eng_state        <= ENG_FIELD_GAP;
                    end
                    else begin
                        eng_send_idx <= eng_send_idx + 8'd1;
                    end
                end
            end

            ENG_SEND_DATA: begin
                if (mode_cfg) begin
                    if (ct_len_cfg == 11'd0) begin
                        in_reg           <= 8'd0;
                        in_valid_reg     <= 1'b1;
                        in_type_reg      <= TYPE_CT;
                        in_valid_bit_reg <= 11'd0;
                        last_reg         <= 1'b1;
                        eng_next_state   <= ENG_SEND_TAG;
                        eng_state        <= ENG_FIELD_GAP;
                    end
                    else begin
                        in_reg       <= get_buffer_byte_1024(ct_cfg, {5'd0, ct_len_cfg}, eng_send_idx);
                        in_valid_reg <= 1'b1;
                        in_type_reg  <= TYPE_CT;

                        if (eng_send_idx == (byte_count_from_bits({5'd0, ct_len_cfg}) - 1)) begin
                            last_reg         <= 1'b1;
                            in_valid_bit_reg <= ct_len_cfg;
                            eng_send_idx     <= 8'd0;
                            eng_next_state   <= ENG_SEND_TAG;
                            eng_state        <= ENG_FIELD_GAP;
                        end
                        else begin
                            eng_send_idx <= eng_send_idx + 8'd1;
                        end
                    end
                end
                else begin
                    if (pt_len_cfg == 11'd0) begin
                        in_reg           <= 8'd0;
                        in_valid_reg     <= 1'b1;
                        in_type_reg      <= TYPE_PT;
                        in_valid_bit_reg <= 11'd0;
                        last_reg         <= 1'b1;
                        eng_next_state   <= ENG_SEND_TAG;
                        eng_state        <= ENG_FIELD_GAP;
                    end
                    else begin
                        in_reg       <= get_buffer_byte_1024(pt_cfg, {5'd0, pt_len_cfg}, eng_send_idx);
                        in_valid_reg <= 1'b1;
                        in_type_reg  <= TYPE_PT;

                        if (eng_send_idx == (byte_count_from_bits({5'd0, pt_len_cfg}) - 1)) begin
                            last_reg         <= 1'b1;
                            in_valid_bit_reg <= pt_len_cfg;
                            eng_send_idx     <= 8'd0;
                            eng_next_state   <= ENG_SEND_TAG;
                            eng_state        <= ENG_FIELD_GAP;
                        end
                        else begin
                            eng_send_idx <= eng_send_idx + 8'd1;
                        end
                    end
                end
            end

            ENG_SEND_TAG: begin
                if (tag_len_cfg == 11'd0) begin
                    in_reg           <= 8'd0;
                    in_valid_reg     <= 1'b1;
                    in_type_reg      <= TYPE_TAG;
                    in_valid_bit_reg <= 11'd0;
                    last_reg         <= 1'b1;
                    eng_next_state   <= ENG_WAIT_RESULT;
                    eng_state        <= ENG_FIELD_GAP;
                end
                else begin
                    in_reg       <= get_buffer_byte_1024({896'd0, tag_cfg}, {5'd0, tag_len_cfg}, eng_send_idx);
                    in_valid_reg <= 1'b1;
                    in_type_reg  <= TYPE_TAG;

                    if (eng_send_idx == (byte_count_from_bits({5'd0, tag_len_cfg}) - 1)) begin
                        last_reg         <= 1'b1;
                        in_valid_bit_reg <= tag_len_cfg;
                        eng_send_idx     <= 8'd0;
                        eng_next_state   <= ENG_WAIT_RESULT;
                        eng_state        <= ENG_FIELD_GAP;
                    end
                    else begin
                        eng_send_idx <= eng_send_idx + 8'd1;
                    end
                end
            end

            ENG_FIELD_GAP: begin
                if (eng_next_state == ENG_WAIT_RESULT)
                    wait_watchdog <= 20'd0;
                eng_state <= eng_next_state;
            end

            ENG_WAIT_RESULT: begin
                wait_watchdog <= wait_watchdog + 20'd1;

                if (pc_ct_valid) begin
                    pc_capture_buf <= {pc_capture_buf[1015:0], out};
                    pc_capture_count <= pc_capture_count + 8'd1;
                    pc_last_valid_bits <= pc_ct_valid_bit;
                    if ((pc_capture_count == 8'd0) && (pc_ct_valid_bit == 4'd0))
                        pc_capture_len_bits <= 11'd8;
                    else if (pc_ct_valid_bit == 4'd0)
                        pc_capture_len_bits <= {3'd0, (pc_capture_count + 8'd1)} << 3;
                    else
                        pc_capture_len_bits <= ({3'd0, pc_capture_count} << 3) + pc_ct_valid_bit;
                    wait_watchdog <= 20'd0;
                end

                if (tag_valid) begin
                    wait_watchdog <= 20'd0;
                    if (mode_cfg) begin
                        auth_pass_seen <= 1'b1;
                        status_code_reg <= STAT_DEC_OK;
                        result_valid <= 1'b1;
                        send_status_pending <= 1'b1;
                        send_pc_pending <= (pc_capture_len_bits != 11'd0);
                        send_tag_pending <= 1'b0;
                        eng_state <= ENG_RESPOND;
                        resp_stage <= 2'd0;
                    end
                    else begin
                        tag_capture_buf <= {tag_capture_buf[119:0], out};
                        tag_capture_count <= tag_capture_count + 5'd1;

                        if ((tag_capture_count + 5'd1) == byte_count_from_bits({5'd0, tag_len_cfg})) begin
                            status_code_reg <= STAT_ENC_OK;
                            result_valid    <= 1'b1;
                            send_status_pending <= 1'b1;
                            send_pc_pending <= (pc_capture_len_bits != 11'd0);
                            send_tag_pending <= (tag_len_cfg != 11'd0);
                            eng_state       <= ENG_RESPOND;
                            resp_stage      <= 2'd0;
                        end
                    end
                end

                if (!mode_cfg) begin
                if ((tag_len_cfg == 11'd0) && (wait_watchdog == UART_TIMEOUT_MAX)) begin
                    status_code_reg <= STAT_ENC_OK;
                    result_valid    <= 1'b1;
                    send_status_pending <= 1'b1;
                    send_pc_pending <= (pc_capture_len_bits != 11'd0);
                    send_tag_pending <= 1'b0;
                    eng_state       <= ENG_RESPOND;
                    resp_stage      <= 2'd0;
                end
            end
            else if (wait_watchdog == UART_TIMEOUT_MAX) begin
                status_code_reg <= STAT_AUTH_FAIL;
                result_valid    <= 1'b1;
                send_status_pending <= 1'b1;
                send_pc_pending <= 1'b0;
                send_tag_pending <= 1'b0;
                eng_state       <= ENG_RESPOND;
                resp_stage      <= 2'd0;
            end
        end

        ENG_RESPOND: begin
            if (!frame_active && !tx_busy && !frame_load_req && !tx_start_reg) begin
                if (send_status_pending) begin
                    frame_load_req           <= 1'b1;
                    frame_load_type          <= RSP_STATUS;
                    frame_load_len_bits      <= 16'd8;
                    frame_load_payload       <= {1016'd0, status_code_reg};
                    frame_load_payload_bytes <= 8'd1;
                    send_status_pending      <= 1'b0;
                end
                else if (send_pc_pending) begin
                    frame_load_req           <= 1'b1;
                    frame_load_type          <= RSP_PC;
                    frame_load_len_bits      <= {5'd0, pc_capture_len_bits};
                    frame_load_payload       <= pc_capture_buf;
                    frame_load_payload_bytes <= byte_count_from_bits({5'd0, pc_capture_len_bits});
                    send_pc_pending          <= 1'b0;
                end
                else if (send_tag_pending) begin
                    frame_load_req           <= 1'b1;
                    frame_load_type          <= RSP_TAG;
                    frame_load_len_bits      <= {5'd0, tag_len_cfg};
                    frame_load_payload       <= {896'd0, tag_capture_buf};
                    frame_load_payload_bytes <= byte_count_from_bits({5'd0, tag_len_cfg});
                    send_tag_pending         <= 1'b0;
                end
                else begin
                    eng_state    <= ENG_COOLDOWN;
                    cooldown_cnt <= 4'd0;
                end
            end
        end

        ENG_DEBUG_RESPOND: begin
            if (!frame_active && !tx_busy && !frame_load_req && !tx_start_reg) begin
                if (send_debug_hdr_pending) begin
                    frame_load_req           <= 1'b1;
                    frame_load_type          <= RSP_DEBUG_HDR;
                    frame_load_len_bits      <= 16'd128;
                    frame_load_payload       <= {
                        8'd0,
                        8'd0,
                        {5'd0, tag_len_cfg[10:8]}, tag_len_cfg[7:0],
                        {5'd0, ct_len_cfg[10:8]},  ct_len_cfg[7:0],
                        {5'd0, pt_len_cfg[10:8]},  pt_len_cfg[7:0],
                        {5'd0, aad_len_cfg[10:8]}, aad_len_cfg[7:0],
                        {5'd0, iv_len_cfg[10:8]},  iv_len_cfg[7:0],
                        {1'b0, tag_loaded, ct_loaded, pt_loaded, aad_loaded, iv_loaded, key_loaded, mode_loaded},
                        {7'd0, mode_cfg}
                    };
                    frame_load_payload_bytes <= 8'd16;
                    send_debug_hdr_pending   <= 1'b0;
                end
                else if (send_debug_iv_pending) begin
                    frame_load_req           <= 1'b1;
                    frame_load_type          <= RSP_DEBUG_IV;
                    frame_load_len_bits      <= {5'd0, iv_len_cfg};
                    frame_load_payload       <= iv_cfg;
                    frame_load_payload_bytes <= byte_count_from_bits({5'd0, iv_len_cfg});
                    send_debug_iv_pending    <= 1'b0;
                end
                else if (send_debug_aad_pending) begin
                    frame_load_req           <= 1'b1;
                    frame_load_type          <= RSP_DEBUG_AAD;
                    frame_load_len_bits      <= {5'd0, aad_len_cfg};
                    frame_load_payload       <= aad_cfg;
                    frame_load_payload_bytes <= byte_count_from_bits({5'd0, aad_len_cfg});
                    send_debug_aad_pending   <= 1'b0;
                end
                else if (send_debug_data_pending) begin
                    frame_load_req           <= 1'b1;
                    frame_load_type          <= RSP_DEBUG_DATA;
                    frame_load_len_bits      <= mode_cfg ? {5'd0, ct_len_cfg} : {5'd0, pt_len_cfg};
                    frame_load_payload       <= mode_cfg ? ct_cfg : pt_cfg;
                    frame_load_payload_bytes <= mode_cfg ? byte_count_from_bits({5'd0, ct_len_cfg})
                                                         : byte_count_from_bits({5'd0, pt_len_cfg});
                    send_debug_data_pending  <= 1'b0;
                end
                else if (send_debug_tag_pending) begin
                    frame_load_req           <= 1'b1;
                    frame_load_type          <= RSP_DEBUG_TAG;
                    frame_load_len_bits      <= {5'd0, tag_len_cfg};
                    frame_load_payload       <= {896'd0, tag_cfg};
                    frame_load_payload_bytes <= byte_count_from_bits({5'd0, tag_len_cfg});
                    send_debug_tag_pending   <= 1'b0;
                end
                else begin
                    eng_state    <= ENG_COOLDOWN;
                    cooldown_cnt <= 4'd0;
                end
            end
        end

            ENG_COOLDOWN: begin
                if (!frame_active && !tx_busy) begin
                    if (cooldown_cnt == 4'd8) begin
                        eng_state <= ENG_IDLE;
                    end
                    else begin
                        cooldown_cnt <= cooldown_cnt + 4'd1;
                    end
                end
                else begin
                    cooldown_cnt <= 4'd0;
                end
            end

            default: begin
                eng_state <= ENG_IDLE;
            end
        endcase
    end
end

assign led[0] = alive_div[25];
assign led[1] = (eng_state != ENG_IDLE) || frame_active || rx_busy;
assign led[2] = result_valid && ((status_code_reg == STAT_ENC_OK) || (status_code_reg == STAT_DEC_OK));
assign led[3] = result_valid && status_to_led_fail(status_code_reg);

endmodule
