`timescale 1ns / 1ps

module tb_aes_gcm_top_rsp;

    logic         clk;
    logic         rst;
    logic         mode;
    logic [7:0]   in;
    logic         in_valid;
    logic [2:0]   in_type;
    logic [10:0]  in_valid_bit;
    logic         last;
    logic         pc_ct_valid;
    logic         tag_valid;
    logic [10:0]  pc_ct_len_bit;
    logic [3:0]   pc_ct_valid_bit;
    logic [7:0]   out;

    integer total_enc_cases;
    integer passed_enc_cases;
    integer failed_enc_cases;
    integer total_dec_cases;
    integer passed_dec_cases;
    integer failed_dec_cases;
    integer passed_ct_bytes;
    integer failed_ct_bytes;
    integer passed_tag_bytes;
    integer failed_tag_bytes;
    integer passed_pt_bytes;
    integer failed_pt_bytes;
    integer passed_fail_cases;
    integer failed_fail_cases;

    integer cur_count;
    integer cur_ivlen;
    integer cur_ptlen;
    integer cur_aadlen;
    integer cur_taglen;
    logic [255:0]  cur_key;
    logic [1023:0] cur_iv;
    logic [1023:0] cur_aad;
    logic [1023:0] cur_pt;
    logic [1023:0] cur_ct;
    logic [127:0]  cur_tag;
    bit            cur_have_tag;
    bit            cur_case_done;

    integer rsp_fd;
    integer rc;
    string  line;

    top dut (
        .clk            (clk),
        .rst            (rst),
        .mode           (mode),
        .in             (in),
        .in_valid       (in_valid),
        .in_type        (in_type),
        .in_valid_bit   (in_valid_bit),
        .last           (last),
        .pc_ct_valid    (pc_ct_valid),
        .tag_valid      (tag_valid),
        .pc_ct_len_bit  (pc_ct_len_bit),
        .pc_ct_valid_bit(pc_ct_valid_bit),
        .out            (out)
    );

    always #5 clk = ~clk;

    function automatic [7:0] get_buffer_byte_1024(
        input logic [1023:0] data_bits,
        input integer        total_bits,
        input integer        byte_idx
    );
        integer total_bytes;
    begin
        total_bytes = (total_bits + 7) / 8;
        if (byte_idx < total_bytes)
            get_buffer_byte_1024 = data_bits[((total_bytes - 1 - byte_idx) * 8) +: 8];
        else
            get_buffer_byte_1024 = 8'd0;
    end
    endfunction

    function automatic [7:0] get_buffer_byte_256(
        input logic [255:0] data_bits,
        input integer       total_bits,
        input integer       byte_idx
    );
        integer total_bytes;
    begin
        total_bytes = (total_bits + 7) / 8;
        if (byte_idx < total_bytes)
            get_buffer_byte_256 = data_bits[((total_bytes - 1 - byte_idx) * 8) +: 8];
        else
            get_buffer_byte_256 = 8'd0;
    end
    endfunction

    function automatic [3:0] get_last_byte_bits(input integer total_bits);
        integer rem_bits;
    begin
        rem_bits = total_bits % 8;
        if (total_bits == 0)
            get_last_byte_bits = 4'd0;
        else if (rem_bits == 0)
            get_last_byte_bits = 4'd8;
        else
            get_last_byte_bits = rem_bits[3:0];
    end
    endfunction

    function automatic real pct_ratio(
        input integer numerator,
        input integer denominator
    );
    begin
        if (denominator == 0)
            pct_ratio = 0.0;
        else
            pct_ratio = (100.0 * numerator) / denominator;
    end
    endfunction

    function automatic bit is_fail_line(input string s);
        integer n;
    begin
        n = s.len();
        if ((n >= 4) && (s.substr(0,3) == "FAIL"))
            is_fail_line = 1'b1;
        else
            is_fail_line = 1'b0;
    end
    endfunction

    function automatic bit is_pt_line(input string s);
        integer n;
    begin
        n = s.len();
        if ((n >= 4) && (s.substr(0,3) == "PT ="))
            is_pt_line = 1'b1;
        else
            is_pt_line = 1'b0;
    end
    endfunction

    task automatic reset_case_env;
    begin
        @(posedge clk);
        rst          <= 1'b1;
        mode         <= 1'b0;
        in           <= 8'd0;
        in_valid     <= 1'b0;
        in_type      <= 3'd6;
        in_valid_bit <= 11'd0;
        last         <= 1'b0;

        @(posedge clk);
        rst <= 1'b0;

        repeat (3) @(posedge clk);
    end
    endtask

    task automatic send_field_1024(
        input logic [2:0]    field_type,
        input logic [1023:0] data_bits,
        input integer        total_bits
    );
        integer total_bytes;
        integer byte_idx;
    begin
        total_bytes = (total_bits + 7) / 8;

        if (total_bits == 0) begin
            @(posedge clk);
            in           <= 8'd0;
            in_valid     <= 1'b1;
            in_type      <= field_type;
            in_valid_bit <= 11'd0;
            last         <= 1'b1;

            @(posedge clk);
            in_valid     <= 1'b0;
            last         <= 1'b0;
            in_type      <= 3'd6;
            in_valid_bit <= 11'd0;
        end
        else begin
            for (byte_idx = 0; byte_idx < total_bytes; byte_idx = byte_idx + 1) begin
                @(posedge clk);
                in       <= get_buffer_byte_1024(data_bits, total_bits, byte_idx);
                in_valid <= 1'b1;
                in_type  <= field_type;
                last     <= (byte_idx == (total_bytes - 1));

                if (byte_idx == (total_bytes - 1))
                    in_valid_bit <= total_bits[10:0];
                else
                    in_valid_bit <= 11'd0;
            end

            @(posedge clk);
            in_valid     <= 1'b0;
            last         <= 1'b0;
            in_type      <= 3'd6;
            in_valid_bit <= 11'd0;
        end
    end
    endtask

    task automatic send_field_256(
        input logic [2:0]   field_type,
        input logic [255:0] data_bits,
        input integer       total_bits
    );
        integer total_bytes;
        integer byte_idx;
    begin
        total_bytes = (total_bits + 7) / 8;

        for (byte_idx = 0; byte_idx < total_bytes; byte_idx = byte_idx + 1) begin
            @(posedge clk);
            in       <= get_buffer_byte_256(data_bits, total_bits, byte_idx);
            in_valid <= 1'b1;
            in_type  <= field_type;
            last     <= (byte_idx == (total_bytes - 1));

            if (byte_idx == (total_bytes - 1))
                in_valid_bit <= total_bits[10:0];
            else
                in_valid_bit <= 11'd0;
        end

        @(posedge clk);
        in_valid     <= 1'b0;
        last         <= 1'b0;
        in_type      <= 3'd6;
        in_valid_bit <= 11'd0;
    end
    endtask

    task automatic wait_for_case_to_finish;
        integer wait_cycles;
        bit     left_collect;
    begin
        wait_cycles  = 0;
        left_collect = 1'b0;

        while (wait_cycles < 40000) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;

            if (dut.state != 5'd0)
                left_collect = 1'b1;

            if (left_collect && (dut.state == 5'd0))
                disable wait_for_case_to_finish;
        end

        $fatal(1, "top case timeout waiting for return to collect state.");
    end
    endtask

    task automatic run_encrypt_case(
        input integer        count_idx,
        input integer        ivlen_bits,
        input integer        aadlen_bits,
        input integer        ptlen_bits,
        input integer        taglen_bits,
        input logic [255:0]  key_in,
        input logic [1023:0] iv_in,
        input logic [1023:0] aad_in,
        input logic [1023:0] pt_in,
        input logic [1023:0] ct_exp_in,
        input logic [127:0]  tag_exp_in
    );
        integer ct_total_bytes;
        integer tag_total_bytes;
        integer ct_seen;
        integer tag_seen;
        integer case_mismatch;
        integer wait_cycles;
        bit finished;
    begin
        total_enc_cases = total_enc_cases + 1;
        case_mismatch   = 0;
        ct_total_bytes  = (ptlen_bits + 7) / 8;
        tag_total_bytes = (taglen_bits + 7) / 8;
        ct_seen         = 0;
        tag_seen        = 0;
        finished        = 1'b0;

        reset_case_env();
        mode <= 1'b0;

        send_field_256 (3'd1, key_in, 256);
        send_field_1024(3'd0, iv_in, ivlen_bits);
        send_field_1024(3'd2, aad_in, aadlen_bits);
        send_field_1024(3'd3, pt_in, ptlen_bits);
        send_field_1024(3'd5, {896'd0, tag_exp_in}, taglen_bits);

        wait_cycles = 0;
        while ((wait_cycles < 40000) && !finished) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;

            if (pc_ct_valid) begin
                if (pc_ct_len_bit !== ptlen_bits[10:0]) begin
                    case_mismatch = 1;
                    $error("ENC Count=%0d pc_ct_len_bit mismatch. got=%0d expected=%0d",
                           count_idx, pc_ct_len_bit, ptlen_bits);
                end

                if (out !== get_buffer_byte_1024(ct_exp_in, ptlen_bits, ct_seen)) begin
                    failed_ct_bytes = failed_ct_bytes + 1;
                    case_mismatch   = 1;
                    $error("ENC Count=%0d CT byte=%0d mismatch. got=%02h expected=%02h",
                           count_idx, ct_seen, out, get_buffer_byte_1024(ct_exp_in, ptlen_bits, ct_seen));
                end
                else begin
                    passed_ct_bytes = passed_ct_bytes + 1;
                end

                if (ct_seen == (ct_total_bytes - 1)) begin
                    if (pc_ct_valid_bit !== get_last_byte_bits(ptlen_bits)) begin
                        case_mismatch = 1;
                        $error("ENC Count=%0d CT last valid_bit mismatch. got=%0d expected=%0d",
                               count_idx, pc_ct_valid_bit, get_last_byte_bits(ptlen_bits));
                    end
                end
                else if (pc_ct_valid_bit !== 4'd8) begin
                    case_mismatch = 1;
                    $error("ENC Count=%0d CT byte=%0d valid_bit mismatch. got=%0d expected=8",
                           count_idx, ct_seen, pc_ct_valid_bit);
                end

                ct_seen = ct_seen + 1;
            end

            if (tag_valid) begin
                if (out !== get_buffer_byte_1024({896'd0, tag_exp_in}, taglen_bits, tag_seen)) begin
                    failed_tag_bytes = failed_tag_bytes + 1;
                    case_mismatch    = 1;
                    $error("ENC Count=%0d TAG byte=%0d mismatch. got=%02h expected=%02h",
                           count_idx, tag_seen, out, get_buffer_byte_1024({896'd0, tag_exp_in}, taglen_bits, tag_seen));
                end
                else begin
                    passed_tag_bytes = passed_tag_bytes + 1;
                end

                tag_seen = tag_seen + 1;
            end

            if ((dut.state == 5'd0) && (ct_seen == ct_total_bytes) && (tag_seen == tag_total_bytes))
                finished = 1'b1;
        end

        if (!finished) begin
            $fatal(1, "ENC Count=%0d timeout. ct_seen=%0d/%0d tag_seen=%0d/%0d",
                   count_idx, ct_seen, ct_total_bytes, tag_seen, tag_total_bytes);
        end

        if (case_mismatch == 0)
            passed_enc_cases = passed_enc_cases + 1;
        else
            failed_enc_cases = failed_enc_cases + 1;
    end
    endtask

    task automatic run_decrypt_case(
        input integer        count_idx,
        input integer        ivlen_bits,
        input integer        aadlen_bits,
        input integer        ptlen_bits,
        input integer        taglen_bits,
        input logic [255:0]  key_in,
        input logic [1023:0] iv_in,
        input logic [1023:0] aad_in,
        input logic [1023:0] ct_in,
        input logic [127:0]  tag_in,
        input logic [1023:0] pt_exp_in,
        input bit            expect_fail
    );
        integer pt_total_bytes;
        integer pt_seen;
        integer auth_seen;
        integer case_mismatch;
        integer wait_cycles;
        bit finished;
        bit left_collect;
    begin
        total_dec_cases = total_dec_cases + 1;
        pt_total_bytes  = expect_fail ? 0 : ((ptlen_bits + 7) / 8);
        pt_seen         = 0;
        auth_seen       = 0;
        case_mismatch   = 0;
        finished        = 1'b0;
        left_collect    = 1'b0;

        reset_case_env();
        mode <= 1'b1;

        send_field_256 (3'd1, key_in, 256);
        send_field_1024(3'd0, iv_in, ivlen_bits);
        send_field_1024(3'd2, aad_in, aadlen_bits);
        send_field_1024(3'd4, ct_in, ptlen_bits);
        send_field_1024(3'd5, {896'd0, tag_in}, taglen_bits);

        wait_cycles = 0;
        while ((wait_cycles < 40000) && !finished) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;

            if (dut.state != 5'd0)
                left_collect = 1'b1;

            if (pc_ct_valid) begin
                if (pc_ct_len_bit !== ptlen_bits[10:0]) begin
                    case_mismatch = 1;
                    $error("DEC Count=%0d pc_ct_len_bit mismatch. got=%0d expected=%0d",
                           count_idx, pc_ct_len_bit, ptlen_bits);
                end

                if (expect_fail) begin
                    failed_pt_bytes = failed_pt_bytes + 1;
                    case_mismatch   = 1;
                    $error("DEC Count=%0d unexpected plaintext byte=%0d out=%02h on FAIL case",
                           count_idx, pt_seen, out);
                end
                else begin
                    if (out !== get_buffer_byte_1024(pt_exp_in, ptlen_bits, pt_seen)) begin
                        failed_pt_bytes = failed_pt_bytes + 1;
                        case_mismatch   = 1;
                        $error("DEC Count=%0d PT byte=%0d mismatch. got=%02h expected=%02h",
                               count_idx, pt_seen, out, get_buffer_byte_1024(pt_exp_in, ptlen_bits, pt_seen));
                    end
                    else begin
                        passed_pt_bytes = passed_pt_bytes + 1;
                    end

                    if (pt_seen == (pt_total_bytes - 1)) begin
                        if (pc_ct_valid_bit !== get_last_byte_bits(ptlen_bits)) begin
                            case_mismatch = 1;
                            $error("DEC Count=%0d PT last valid_bit mismatch. got=%0d expected=%0d",
                                   count_idx, pc_ct_valid_bit, get_last_byte_bits(ptlen_bits));
                        end
                    end
                    else if (pc_ct_valid_bit !== 4'd8) begin
                        case_mismatch = 1;
                        $error("DEC Count=%0d PT byte=%0d valid_bit mismatch. got=%0d expected=8",
                               count_idx, pt_seen, pc_ct_valid_bit);
                    end
                end

                pt_seen = pt_seen + 1;
            end

            if (tag_valid)
                auth_seen = auth_seen + 1;

            if (left_collect && (dut.state == 5'd0))
                finished = 1'b1;
        end

        if (!finished) begin
            $fatal(1, "DEC Count=%0d timeout waiting for completion.", count_idx);
        end

        if (expect_fail) begin
            if ((auth_seen == 0) && (pt_seen == 0)) begin
                passed_fail_cases = passed_fail_cases + 1;
                passed_dec_cases  = passed_dec_cases + 1;
            end
            else begin
                failed_fail_cases = failed_fail_cases + 1;
                failed_dec_cases  = failed_dec_cases + 1;
            end
        end
        else begin
            if ((case_mismatch == 0) && (auth_seen == 1) && (pt_seen == pt_total_bytes))
                passed_dec_cases = passed_dec_cases + 1;
            else
                failed_dec_cases = failed_dec_cases + 1;
        end

        repeat (3) @(posedge clk);
    end
    endtask

    task automatic run_encrypt_file;
    begin
        cur_count     = -1;
        cur_ivlen     = 0;
        cur_ptlen     = 0;
        cur_aadlen    = 0;
        cur_taglen    = 0;
        cur_key       = '0;
        cur_iv        = '0;
        cur_aad       = '0;
        cur_pt        = '0;
        cur_ct        = '0;
        cur_tag       = '0;

        rsp_fd = $fopen("C:/project/FPGA/txt/gcmEncryptExtIV256.rsp", "r");
        if (rsp_fd == 0)
            $fatal(1, "Cannot open encrypt rsp file.");

        while (!$feof(rsp_fd)) begin
            line = "";
            rc   = $fgets(line, rsp_fd);

            if ($sscanf(line, "[IVlen = %d]", cur_ivlen) == 1) begin
            end
            else if ($sscanf(line, "[PTlen = %d]", cur_ptlen) == 1) begin
            end
            else if ($sscanf(line, "[AADlen = %d]", cur_aadlen) == 1) begin
            end
            else if ($sscanf(line, "[Taglen = %d]", cur_taglen) == 1) begin
            end
            else if ($sscanf(line, "Count = %d", cur_count) == 1) begin
                cur_key = '0;
                cur_iv  = '0;
                cur_aad = '0;
                cur_pt  = '0;
                cur_ct  = '0;
                cur_tag = '0;
            end
            else if ($sscanf(line, "Key = %h", cur_key) == 1) begin
            end
            else if ($sscanf(line, "IV = %h", cur_iv) == 1) begin
            end
            else if ($sscanf(line, "AAD = %h", cur_aad) == 1) begin
            end
            else if ($sscanf(line, "PT = %h", cur_pt) == 1) begin
            end
            else if ($sscanf(line, "CT = %h", cur_ct) == 1) begin
            end
            else if ($sscanf(line, "Tag = %h", cur_tag) == 1) begin
                run_encrypt_case(cur_count, cur_ivlen, cur_aadlen, cur_ptlen, cur_taglen,
                                 cur_key, cur_iv, cur_aad, cur_pt, cur_ct, cur_tag);
            end
        end

        $fclose(rsp_fd);
    end
    endtask

    task automatic run_decrypt_file;
        integer next_count;
        integer next_ivlen;
    begin
        cur_count     = -1;
        cur_ivlen     = 0;
        cur_ptlen     = 0;
        cur_aadlen    = 0;
        cur_taglen    = 0;
        cur_key       = '0;
        cur_iv        = '0;
        cur_aad       = '0;
        cur_pt        = '0;
        cur_ct        = '0;
        cur_tag       = '0;
        cur_have_tag  = 1'b0;
        cur_case_done = 1'b0;

        rsp_fd = $fopen("C:/project/FPGA/txt/gcmDecrypt256.rsp", "r");
        if (rsp_fd == 0)
            $fatal(1, "Cannot open decrypt rsp file.");

        while (!$feof(rsp_fd)) begin
            line = "";
            rc   = $fgets(line, rsp_fd);

            if ($sscanf(line, "Count = %d", next_count) == 1) begin
                if (cur_have_tag && !cur_case_done) begin
                    run_decrypt_case(cur_count, cur_ivlen, cur_aadlen, cur_ptlen, cur_taglen,
                                     cur_key, cur_iv, cur_aad, cur_ct, cur_tag, cur_pt, 1'b0);
                end

                cur_count     = next_count;
                cur_key       = '0;
                cur_iv        = '0;
                cur_aad       = '0;
                cur_pt        = '0;
                cur_ct        = '0;
                cur_tag       = '0;
                cur_have_tag  = 1'b0;
                cur_case_done = 1'b0;
            end
            else if ($sscanf(line, "[IVlen = %d]", next_ivlen) == 1) begin
                if (cur_have_tag && !cur_case_done) begin
                    run_decrypt_case(cur_count, cur_ivlen, cur_aadlen, cur_ptlen, cur_taglen,
                                     cur_key, cur_iv, cur_aad, cur_ct, cur_tag, cur_pt, 1'b0);
                end

                cur_ivlen     = next_ivlen;
                cur_have_tag  = 1'b0;
                cur_case_done = 1'b0;
            end
            else if ($sscanf(line, "[PTlen = %d]", cur_ptlen) == 1) begin
            end
            else if ($sscanf(line, "[AADlen = %d]", cur_aadlen) == 1) begin
            end
            else if ($sscanf(line, "[Taglen = %d]", cur_taglen) == 1) begin
            end
            else if ($sscanf(line, "Key = %h", cur_key) == 1) begin
            end
            else if ($sscanf(line, "IV = %h", cur_iv) == 1) begin
            end
            else if ($sscanf(line, "AAD = %h", cur_aad) == 1) begin
            end
            else if ($sscanf(line, "CT = %h", cur_ct) == 1) begin
            end
            else if ($sscanf(line, "Tag = %h", cur_tag) == 1) begin
                cur_have_tag  = 1'b1;
                cur_case_done = 1'b0;
            end
            else if (is_fail_line(line)) begin
                run_decrypt_case(cur_count, cur_ivlen, cur_aadlen, cur_ptlen, cur_taglen,
                                 cur_key, cur_iv, cur_aad, cur_ct, cur_tag, 1024'd0, 1'b1);
                cur_case_done = 1'b1;
            end
            else if (is_pt_line(line)) begin
                if ($sscanf(line, "PT = %h", cur_pt) < 0) begin
                end
                run_decrypt_case(cur_count, cur_ivlen, cur_aadlen, cur_ptlen, cur_taglen,
                                 cur_key, cur_iv, cur_aad, cur_ct, cur_tag, cur_pt, 1'b0);
                cur_case_done = 1'b1;
            end
        end

        if (cur_have_tag && !cur_case_done) begin
            run_decrypt_case(cur_count, cur_ivlen, cur_aadlen, cur_ptlen, cur_taglen,
                             cur_key, cur_iv, cur_aad, cur_ct, cur_tag, cur_pt, 1'b0);
        end

        $fclose(rsp_fd);
    end
    endtask

    initial begin
        clk              = 1'b0;
        rst              = 1'b0;
        mode             = 1'b0;
        in               = 8'd0;
        in_valid         = 1'b0;
        in_type          = 3'd6;
        in_valid_bit     = 11'd0;
        last             = 1'b0;
        total_enc_cases  = 0;
        passed_enc_cases = 0;
        failed_enc_cases = 0;
        total_dec_cases  = 0;
        passed_dec_cases = 0;
        failed_dec_cases = 0;
        passed_ct_bytes  = 0;
        failed_ct_bytes  = 0;
        passed_tag_bytes = 0;
        failed_tag_bytes = 0;
        passed_pt_bytes  = 0;
        failed_pt_bytes  = 0;
        passed_fail_cases= 0;
        failed_fail_cases= 0;

        run_encrypt_file();
        run_decrypt_file();

        $display("======================================================");
        $display("AES-GCM TOP Combined Summary");
        $display("Encrypt cases     : total=%0d pass=%0d fail=%0d pass_rate=%0.2f%%",
                 total_enc_cases, passed_enc_cases, failed_enc_cases,
                 pct_ratio(passed_enc_cases, total_enc_cases));
        $display("Decrypt cases     : total=%0d pass=%0d fail=%0d pass_rate=%0.2f%%",
                 total_dec_cases, passed_dec_cases, failed_dec_cases,
                 pct_ratio(passed_dec_cases, total_dec_cases));
        $display("Passed CT bytes   : %0d", passed_ct_bytes);
        $display("Failed CT bytes   : %0d", failed_ct_bytes);
        $display("Passed TAG bytes  : %0d", passed_tag_bytes);
        $display("Failed TAG bytes  : %0d", failed_tag_bytes);
        $display("Passed PT bytes   : %0d", passed_pt_bytes);
        $display("Failed PT bytes   : %0d", failed_pt_bytes);
        $display("Passed FAIL cases : %0d", passed_fail_cases);
        $display("Failed FAIL cases : %0d", failed_fail_cases);

        if ((failed_enc_cases != 0) || (failed_dec_cases != 0) ||
            (failed_ct_bytes != 0) || (failed_tag_bytes != 0) ||
            (failed_pt_bytes != 0) || (failed_fail_cases != 0))
            $fatal(1, "AES-GCM top combined verification failed.");

        $display("AES-GCM top combined verification completed.");
        #20;
        $finish;
    end

endmodule
