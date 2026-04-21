`timescale 1ns / 1ps

module tb_fpga_top_arty_a7_uart_case_iv96_aad128_pt0_tag128_newfail;

    localparam [7:0] CMD_MODE = 8'h01;
    localparam [7:0] CMD_KEY  = 8'h02;
    localparam [7:0] CMD_IV   = 8'h03;
    localparam [7:0] CMD_AAD  = 8'h04;
    localparam [7:0] CMD_PT   = 8'h05;
    localparam [7:0] CMD_TAG  = 8'h07;
    localparam [7:0] CMD_RUN  = 8'h08;

    localparam [7:0] RSP_STATUS = 8'h80;
    localparam [7:0] RSP_TAG    = 8'h82;

    localparam [255:0] KEY_VEC =
        256'hfc4875db84819834b1cb43828d2f0ae3473aa380111c2737e82a9ab11fea1f19;
    localparam [95:0] IV_VEC =
        96'hda6a684d3ff63a2d109decd6;
    localparam [127:0] AAD_VEC =
        128'h91b6fa2ab4de44282ffc86c8cde6e7f5;
    localparam [127:0] TAG_EXP =
        128'h504e81d2e7877e4dad6f31cdeb07bdbd;

    localparam integer UART_BIT_TIME_NS     = 8680;
    localparam integer UART_HALF_BIT_NS     = 4340;
    localparam integer UART_WAIT_TIMEOUT_NS = 50000000;

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

    function automatic [7:0] get_buffer_byte_128(
        input logic [127:0] data_bits,
        input integer       total_bytes,
        input integer       byte_idx
    );
        integer shift_amt;
    begin
        shift_amt = (total_bytes - 1 - byte_idx) * 8;
        get_buffer_byte_128 = (data_bits >> shift_amt) & 8'hff;
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

    task automatic host_send_packet(
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

        if (!got_start) begin
            $display("DEBUG eng_state=%0d rx_state=%0d run_request=%0b result_valid=%0b status=0x%02h wait_watchdog=%0d tag_count=%0d pc_count=%0d",
                     dut.eng_state, dut.rx_state, dut.run_request, dut.result_valid, dut.status_code_reg,
                     dut.wait_watchdog, dut.tag_capture_count, dut.pc_capture_count);
            $display("DEBUG loaded mode=%0b key=%0b iv=%0b aad=%0b pt=%0b ct=%0b tag=%0b lens iv=%0d aad=%0d pt=%0d ct=%0d tag=%0d",
                     dut.mode_loaded, dut.key_loaded, dut.iv_loaded, dut.aad_loaded, dut.pt_loaded,
                     dut.ct_loaded, dut.tag_loaded, dut.iv_len_cfg, dut.aad_len_cfg, dut.pt_len_cfg,
                     dut.ct_len_cfg, dut.tag_len_cfg);
            $fatal(1, "UART receive timeout");
        end

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

        clk         = 1'b0;
        rst_btn     = 1'b0;
        uart_txd_in = 1'b1;

        repeat (20) @(posedge clk);
        rst_btn = 1'b1;

        #10000;

        host_send_packet(CMD_MODE, 8,   1,  {1016'd0, 8'h00});
        host_send_packet(CMD_KEY,  256, 32, {768'd0, KEY_VEC});
        host_send_packet(CMD_IV,   96,  12, {928'd0, IV_VEC});
        host_send_packet(CMD_AAD,  128, 16, {896'd0, AAD_VEC});
        host_send_packet(CMD_PT,   0,   0,  1024'd0);
        host_send_packet(CMD_TAG,  128, 16, 1024'd0);
        host_send_packet(CMD_RUN,  0,   0,  1024'd0);

        recv_frame_header(frame_type, bit_len, payload_bytes);
        if (frame_type !== RSP_STATUS) $fatal(1, "Expected STATUS frame, got 0x%02x", frame_type);
        if (bit_len !== 8) $fatal(1, "STATUS bit_len mismatch: %0d", bit_len);
        recv_byte_with_timeout(payload_byte);
        if (payload_byte !== 8'h00) $fatal(1, "STATUS payload mismatch: 0x%02x", payload_byte);

        recv_frame_header(frame_type, bit_len, payload_bytes);
        if (frame_type !== RSP_TAG) $fatal(1, "Expected TAG frame, got 0x%02x", frame_type);
        if (bit_len !== 128) $fatal(1, "TAG bit_len mismatch: %0d", bit_len);
        if (payload_bytes !== 16) $fatal(1, "TAG payload byte count mismatch: %0d", payload_bytes);
        for (i = 0; i < 16; i = i + 1) begin
            recv_byte_with_timeout(payload_byte);
            if (payload_byte !== get_buffer_byte_128(TAG_EXP, 16, i))
                $fatal(1, "TAG byte mismatch at %0d got=%02h expected=%02h",
                       i, payload_byte, get_buffer_byte_128(TAG_EXP, 16, i));
        end

        $display("UART wrapper one-case iv96/aad128/pt0/tag128 Count7 completed.");
        repeat (20) @(posedge clk);
        $finish;
    end

endmodule
