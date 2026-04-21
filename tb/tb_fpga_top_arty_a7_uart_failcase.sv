`timescale 1ns / 1ps

module tb_fpga_top_arty_a7_uart_failcase;

    localparam [7:0] CMD_MODE = 8'h01;
    localparam [7:0] CMD_KEY  = 8'h02;
    localparam [7:0] CMD_IV   = 8'h03;
    localparam [7:0] CMD_AAD  = 8'h04;
    localparam [7:0] CMD_PT   = 8'h05;
    localparam [7:0] CMD_TAG  = 8'h07;
    localparam [7:0] CMD_RUN  = 8'h08;

    localparam [7:0] RSP_STATUS = 8'h80;
    localparam [7:0] RSP_PC     = 8'h81;
    localparam [7:0] RSP_TAG    = 8'h82;

    localparam [255:0] KEY_VEC =
        256'hd2e1ddf323e2cb9f42d2ff2c6563dd921b4c90d89060555e780a1779297d5182;
    localparam [95:0] IV_VEC =
        96'h4173596cd182835b5f1f4377;
    localparam [719:0] AAD_VEC =
        720'h8a728a9b5182b414dd2a75cedffaccb0dab9732a5b971b878423a0934f2b43eb914f54ebfdee72eb16076cfc0dca25d92161e2c70fef7521a713e08e61f9d23a371ce9b132a2daf296e6cce65b667db9457d0e9af2e6b76a0e82;
    localparam [103:0] PT_VEC =
        104'hd98c22a4bc9be2686fd045d41b;
    localparam [103:0] CT_EXP =
        104'h9848a064352376e5701f1ba9cf;
    localparam [95:0] TAG_EXP =
        96'hd3486ea01dedc7ee39bd61fa;

    localparam integer UART_BIT_TIME_NS  = 8680;
    localparam integer UART_HALF_BIT_NS  = 4340;
    localparam integer UART_WAIT_TIMEOUT_NS = 30000000;

    logic clk;
    logic rst_btn;
    logic uart_txd_in;
    wire  uart_rxd_out;
    wire [3:0] led;

    fpga_top_arty_a7_uart dut (
        .clk(clk),
        .rst_btn(rst_btn),
        .uart_txd_in(uart_txd_in),
        .uart_rxd_out(uart_rxd_out),
        .led(led)
    );

    always #5 clk = ~clk;

    function automatic [7:0] get_buffer_byte_1024(
        input logic [1023:0] data_bits,
        input integer        total_bytes,
        input integer        byte_idx
    );
        integer shift_amt;
    begin
        shift_amt = (total_bytes - 1 - byte_idx) * 8;
        get_buffer_byte_1024 = (data_bits >> shift_amt) & 8'hff;
    end
    endfunction

    function automatic [7:0] get_buffer_byte_720(
        input logic [719:0] data_bits,
        input integer       total_bytes,
        input integer       byte_idx
    );
        integer shift_amt;
    begin
        shift_amt = (total_bytes - 1 - byte_idx) * 8;
        get_buffer_byte_720 = (data_bits >> shift_amt) & 8'hff;
    end
    endfunction

    function automatic [7:0] get_buffer_byte_104(
        input logic [103:0] data_bits,
        input integer       total_bytes,
        input integer       byte_idx
    );
        integer shift_amt;
    begin
        shift_amt = (total_bytes - 1 - byte_idx) * 8;
        get_buffer_byte_104 = (data_bits >> shift_amt) & 8'hff;
    end
    endfunction

    task automatic host_send_byte(input logic [7:0] data_in);
        integer i;
    begin
        uart_txd_in = 1'b0;
        #(UART_BIT_TIME_NS);
        for (i = 0; i < 8; i = i + 1) begin
            uart_txd_in = data_in[i];
            #(UART_BIT_TIME_NS);
        end
        uart_txd_in = 1'b1;
        #(UART_BIT_TIME_NS);
    end
    endtask

    task automatic host_send_packet_1024(
        input logic [7:0]    cmd,
        input integer        bit_len,
        input integer        total_bytes,
        input logic [1023:0] payload
    );
        integer i;
    begin
        host_send_byte(cmd);
        host_send_byte(bit_len[15:8]);
        host_send_byte(bit_len[7:0]);
        for (i = 0; i < total_bytes; i = i + 1)
            host_send_byte(get_buffer_byte_1024(payload, total_bytes, i));
    end
    endtask

    task automatic host_send_packet_720(
        input logic [7:0]   cmd,
        input integer       bit_len,
        input integer       total_bytes,
        input logic [719:0] payload
    );
        integer i;
    begin
        host_send_byte(cmd);
        host_send_byte(bit_len[15:8]);
        host_send_byte(bit_len[7:0]);
        for (i = 0; i < total_bytes; i = i + 1)
            host_send_byte(get_buffer_byte_720(payload, total_bytes, i));
    end
    endtask

    task automatic host_send_packet_104(
        input logic [7:0]   cmd,
        input integer       bit_len,
        input integer       total_bytes,
        input logic [103:0] payload
    );
        integer i;
    begin
        host_send_byte(cmd);
        host_send_byte(bit_len[15:8]);
        host_send_byte(bit_len[7:0]);
        for (i = 0; i < total_bytes; i = i + 1)
            host_send_byte(get_buffer_byte_104(payload, total_bytes, i));
    end
    endtask

    task automatic recv_byte_with_timeout(output logic [7:0] data_out);
        integer i;
        bit got_start;
    begin
        got_start = 1'b0;
        fork
            begin
                wait (uart_rxd_out === 1'b0);
                got_start = 1'b1;
            end
            begin
                #(UART_WAIT_TIMEOUT_NS);
            end
        join_any
        disable fork;

        if (!got_start)
            $fatal(1, "UART receive timeout");
        #(UART_HALF_BIT_NS + UART_BIT_TIME_NS);
        for (i = 0; i < 8; i = i + 1) begin
            data_out[i] = uart_rxd_out;
            #(UART_BIT_TIME_NS);
        end
        #(UART_HALF_BIT_NS);
    end
    endtask

    task automatic recv_frame_header(
        output logic [7:0] frame_type,
        output integer     bit_len,
        output integer     payload_bytes
    );
        logic [7:0] b0, b1, b2;
    begin
        recv_byte_with_timeout(b0);
        recv_byte_with_timeout(b1);
        recv_byte_with_timeout(b2);
        frame_type    = b0;
        bit_len       = {b1, b2};
        payload_bytes = (bit_len + 7) / 8;
    end
    endtask

    initial begin
        logic [7:0] frame_type;
        integer     bit_len;
        integer     payload_bytes;
        logic [7:0] payload_byte;
        integer     i;
        logic [103:0] ct_recv;
        logic [95:0] tag_recv;

        clk         = 1'b0;
        rst_btn     = 1'b0;
        uart_txd_in = 1'b1;
        ct_recv     = '0;
        tag_recv    = '0;

        repeat (20) @(posedge clk);
        rst_btn = 1'b1;
        #10000;

        host_send_packet_1024(CMD_MODE, 8,   1,  {1016'd0, 8'h00});
        host_send_packet_1024(CMD_KEY,  256, 32, {768'd0, KEY_VEC});
        host_send_packet_1024(CMD_IV,   96,  12, {928'd0, IV_VEC});
        host_send_packet_720 (CMD_AAD,  720, 90, AAD_VEC);
        host_send_packet_104 (CMD_PT,   104, 13, PT_VEC);
        host_send_packet_1024(CMD_TAG,  96,  12, 1024'd0);
        host_send_packet_1024(CMD_RUN,  0,   0,  1024'd0);

        recv_frame_header(frame_type, bit_len, payload_bytes);
        if (frame_type !== RSP_STATUS || bit_len !== 8)
            $fatal(1, "Bad STATUS header type=0x%02x bit_len=%0d", frame_type, bit_len);
        recv_byte_with_timeout(payload_byte);
        if (payload_byte !== 8'h00)
            $fatal(1, "Bad STATUS payload 0x%02x", payload_byte);

        recv_frame_header(frame_type, bit_len, payload_bytes);
        if (frame_type !== RSP_PC || bit_len !== 104 || payload_bytes !== 13)
            $fatal(1, "Bad PC header type=0x%02x bit_len=%0d payload=%0d", frame_type, bit_len, payload_bytes);
        for (i = 0; i < 13; i = i + 1) begin
            recv_byte_with_timeout(payload_byte);
            ct_recv = (ct_recv << 8) | payload_byte;
        end
        if (ct_recv !== CT_EXP)
            $fatal(1, "PC mismatch got=%026h expected=%026h", ct_recv, CT_EXP);

        recv_frame_header(frame_type, bit_len, payload_bytes);
        if (frame_type !== RSP_TAG || bit_len !== 96 || payload_bytes !== 12)
            $fatal(1, "Bad TAG header type=0x%02x bit_len=%0d payload=%0d", frame_type, bit_len, payload_bytes);
        for (i = 0; i < 12; i = i + 1) begin
            recv_byte_with_timeout(payload_byte);
            tag_recv = (tag_recv << 8) | payload_byte;
        end
        if (tag_recv !== TAG_EXP)
            $fatal(1, "TAG mismatch got=%024h expected=%024h", tag_recv, TAG_EXP);

        $display("UART failcase protocol test completed.");
        repeat (20) @(posedge clk);
        $finish;
    end

endmodule
