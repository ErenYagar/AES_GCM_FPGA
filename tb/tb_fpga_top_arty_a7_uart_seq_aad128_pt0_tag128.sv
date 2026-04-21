`timescale 1ns / 1ps

module tb_fpga_top_arty_a7_uart_seq_aad128_pt0_tag128;

    localparam [7:0] CMD_MODE = 8'h01;
    localparam [7:0] CMD_KEY  = 8'h02;
    localparam [7:0] CMD_IV   = 8'h03;
    localparam [7:0] CMD_AAD  = 8'h04;
    localparam [7:0] CMD_PT   = 8'h05;
    localparam [7:0] CMD_TAG  = 8'h07;
    localparam [7:0] CMD_RUN  = 8'h08;

    localparam [7:0] RSP_STATUS = 8'h80;
    localparam [7:0] RSP_TAG    = 8'h82;

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

    function automatic [255:0] case_key(input integer idx);
    begin
        case (idx)
            0: case_key = 256'h78dc4e0aaf52d935c3c01eea57428f00ca1fd475f5da86a49c8dd73d68c8e223;
            1: case_key = 256'h4457ff33683cca6ca493878bdc00373893a9763412eef8cddb54f91318e0da88;
            2: case_key = 256'h4d01c96ef9d98d4fb4e9b61be5efa772c9788545b3eac39eb1cacb997a5f0792;
            3: case_key = 256'h8378193a4ce64180814bd60591d1054a04dbc4da02afde453799cd6888ee0c6c;
            4: case_key = 256'h22fc82db5b606998ad45099b7978b5b4f9dd4ea6017e57370ac56141caaabd12;
            5: case_key = 256'hfc00960ddd698d35728c5ac607596b51b3f89741d14c25b8badac91976120d99;
            6: case_key = 256'h69749943092f5605bf971e185c191c618261b2c7cc1693cda1080ca2fd8d5111;
            7: case_key = 256'hfc4875db84819834b1cb43828d2f0ae3473aa380111c2737e82a9ab11fea1f19;
            default: case_key = 256'd0;
        endcase
    end
    endfunction

    function automatic [95:0] case_iv(input integer idx);
    begin
        case (idx)
            0: case_iv = 96'hd79cf22d504cc793c3fb6c8a;
            1: case_iv = 96'h699d1f29d7b8c55300bb1fd2;
            2: case_iv = 96'h32124a4d9e576aea2589f238;
            3: case_iv = 96'hbd8b4e352c7f69878a475435;
            4: case_iv = 96'h880d05c5ee599e5f151e302f;
            5: case_iv = 96'ha424a32a237f0df530f05e30;
            6: case_iv = 96'hbd0d62c02ee682069bd1e128;
            7: case_iv = 96'hda6a684d3ff63a2d109decd6;
            default: case_iv = 96'd0;
        endcase
    end
    endfunction

    function automatic [127:0] case_aad(input integer idx);
    begin
        case (idx)
            0: case_aad = 128'hb96baa8c1c75a671bfb2d08d06be5f36;
            1: case_aad = 128'h6749daeea367d0e9809e2dc2f309e6e3;
            2: case_aad = 128'hd72bad0c38495eda50d55811945ee205;
            3: case_aad = 128'h1c6b343c4d045cbba562bae3e5ff1b18;
            4: case_aad = 128'h3e3eb5747e390f7bc80e748233484ffc;
            5: case_aad = 128'hcfb7e05e3157f0c90549d5c786506311;
            6: case_aad = 128'h6967dce878f03b643bf5cdba596a7af3;
            7: case_aad = 128'h91b6fa2ab4de44282ffc86c8cde6e7f5;
            default: case_aad = 128'd0;
        endcase
    end
    endfunction

    function automatic [127:0] case_tag(input integer idx);
    begin
        case (idx)
            0: case_tag = 128'h3e5d486aa2e30b22e040b85723a06e76;
            1: case_tag = 128'hd60c74d2517fde4a74e0cd4709ed43a9;
            2: case_tag = 128'h6d6397c9e2030f5b8053bfe510f3f2cf;
            3: case_tag = 128'h0833967a6a53ba24e75c0372a6a17bda;
            4: case_tag = 128'h2e122a478e64463286f8b489dcdd09c8;
            5: case_tag = 128'hdcdcb9e4004b852a0da12bdf255b4ddd;
            6: case_tag = 128'h378f796ae543e1b29115cc18acd193f4;
            7: case_tag = 128'h504e81d2e7877e4dad6f31cdeb07bdbd;
            default: case_tag = 128'd0;
        endcase
    end
    endfunction

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

    task automatic run_case(input integer idx);
        logic [7:0] frame_type;
        integer     bit_len;
        integer     payload_bytes;
        logic [7:0] payload_byte;
        integer     i;
        logic [127:0] exp_tag;
    begin
        exp_tag = case_tag(idx);

        host_send_packet(CMD_MODE, 8,   1,  {1016'd0, 8'h00});
        host_send_packet(CMD_KEY,  256, 32, {768'd0, case_key(idx)});
        host_send_packet(CMD_IV,   96,  12, {928'd0, case_iv(idx)});
        host_send_packet(CMD_AAD,  128, 16, {896'd0, case_aad(idx)});
        host_send_packet(CMD_PT,   0,   0,  1024'd0);
        host_send_packet(CMD_TAG,  128, 16, 1024'd0);
        host_send_packet(CMD_RUN,  0,   0,  1024'd0);

        recv_frame_header(frame_type, bit_len, payload_bytes);
        if (frame_type !== RSP_STATUS) $fatal(1, "case %0d expected STATUS frame, got 0x%02x", idx, frame_type);
        if (bit_len !== 8) $fatal(1, "case %0d STATUS bit_len mismatch: %0d", idx, bit_len);
        recv_byte_with_timeout(payload_byte);
        if (payload_byte !== 8'h00) $fatal(1, "case %0d STATUS payload mismatch: 0x%02x", idx, payload_byte);

        recv_frame_header(frame_type, bit_len, payload_bytes);
        if (frame_type !== RSP_TAG) $fatal(1, "case %0d expected TAG frame, got 0x%02x", idx, frame_type);
        if (bit_len !== 128) $fatal(1, "case %0d TAG bit_len mismatch: %0d", idx, bit_len);
        if (payload_bytes !== 16) $fatal(1, "case %0d TAG payload byte count mismatch: %0d", idx, payload_bytes);
        for (i = 0; i < 16; i = i + 1) begin
            recv_byte_with_timeout(payload_byte);
            if (payload_byte !== get_buffer_byte_128(exp_tag, 16, i))
                $fatal(1, "case %0d TAG byte mismatch at %0d got=%02h expected=%02h",
                       idx, i, payload_byte, get_buffer_byte_128(exp_tag, 16, i));
        end

        $display("SEQ PASS case=%0d", idx);
    end
    endtask

    integer case_idx;
    initial begin
        clk         = 1'b0;
        rst_btn     = 1'b0;
        uart_txd_in = 1'b1;

        repeat (20) @(posedge clk);
        rst_btn = 1'b1;
        #10000;

        for (case_idx = 0; case_idx < 8; case_idx = case_idx + 1)
            run_case(case_idx);

        $display("UART wrapper sequential aad128/pt0/tag128 cases 0..7 completed.");
        repeat (20) @(posedge clk);
        $finish;
    end

endmodule
