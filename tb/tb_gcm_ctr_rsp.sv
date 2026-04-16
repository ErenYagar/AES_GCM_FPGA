`timescale 1ns / 1ps

module tb_gcm_ctr_rsp;

    logic         clk;
    logic         rst_n;
    logic         start;
    logic [127:0] nonce;
    logic [127:0] plaintext;
    logic [7:0]   valid_bits;
    logic [255:0] key;
    logic [127:0] ciphertext;
    logic         done;
    logic         hcalc_start;
    logic [255:0] hcalc_key;
    logic [127:0] hcalc_word;
    logic         hcalc_busy;
    logic         hcalc_done;
    logic [127:0] hcalc_wordout;

    integer total_cases;
    integer checked_cases;
    integer passed_cases;
    integer failed_cases;
    integer skipped_cases;
    integer skipped_unsupported_iv_cases;
    integer checked_blocks;
    integer passed_blocks;
    integer block_failures;
    integer stat_idx;

    integer pt_total_cases   [0:4];
    integer pt_checked_cases [0:4];
    integer pt_passed_cases  [0:4];
    integer pt_skipped_cases [0:4];
    integer pt_checked_blocks[0:4];
    integer pt_passed_blocks [0:4];

    integer cur_count;
    integer cur_ivlen;
    integer cur_ptlen;
    integer cur_aadlen;
    integer cur_taglen;

    logic [255:0] cur_key;
    logic [1023:0] cur_iv;
    logic [1023:0] cur_pt;
    logic [1023:0] cur_ct;
    logic [127:0] dummy_tag;

    integer rsp_fd;
    integer rc;
    string  line;

    aes_ctr_wrapper dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .nonce     (nonce),
        .plaintext (plaintext),
        .valid_bits(valid_bits),
        .key       (key),
        .ciphertext(ciphertext),
        .done      (done)
    );

    AES_e hcalc (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (hcalc_start),
        .Key    (hcalc_key),
        .word   (hcalc_word),
        .busy   (hcalc_busy),
        .finish (hcalc_done),
        .wordout(hcalc_wordout)
    );

    always #5 clk = ~clk;

    localparam logic [127:0] GF_R = 128'he1000000000000000000000000000000;

    function automatic [127:0] inc32(input logic [127:0] counter_in);
    begin
        inc32 = {counter_in[127:32], counter_in[31:0] + 32'd1};
    end
    endfunction

    function automatic integer pt_bucket_idx(input integer ptlen_bits);
    begin
        case (ptlen_bits)
            0   : pt_bucket_idx = 0;
            104 : pt_bucket_idx = 1;
            128 : pt_bucket_idx = 2;
            256 : pt_bucket_idx = 3;
            408 : pt_bucket_idx = 4;
            default: pt_bucket_idx = -1;
        endcase
    end
    endfunction

    function automatic integer pt_bucket_len(input integer idx);
    begin
        case (idx)
            0: pt_bucket_len = 0;
            1: pt_bucket_len = 104;
            2: pt_bucket_len = 128;
            3: pt_bucket_len = 256;
            default: pt_bucket_len = 408;
        endcase
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

    function automatic [127:0] gf128_mul(
        input logic [127:0] x,
        input logic [127:0] h
    );
        logic [127:0] z;
        logic [127:0] v;
        integer i;
    begin
        z = 128'd0;
        v = h;

        for (i = 0; i < 128; i = i + 1) begin
            if (x[127 - i])
                z = z ^ v;

            if (v[0])
                v = (v >> 1) ^ GF_R;
            else
                v = (v >> 1);
        end

        gf128_mul = z;
    end
    endfunction

    function automatic [127:0] ghash_step(
        input logic [127:0] y_prev,
        input logic [127:0] x_in,
        input logic [127:0] h
    );
    begin
        ghash_step = gf128_mul(y_prev ^ x_in, h);
    end
    endfunction

    function automatic [7:0] block_valid_count(
        input integer total_bits,
        input integer block_idx
    );
        integer bits_left;
    begin
        bits_left = total_bits - (block_idx * 128);
        if (bits_left >= 128)
            block_valid_count = 8'd128;
        else
            block_valid_count = bits_left[7:0];
    end
    endfunction

    function automatic [127:0] extract_block(
        input logic [1023:0] data_bits,
        input integer       total_bits,
        input integer       block_idx
    );
        integer total_bytes;
        integer block_byte_start;
        integer bytes_left;
        integer block_bytes;
        integer byte_idx;
        integer src_byte_idx;
        reg [127:0] tmp;
    begin
        tmp = 128'd0;

        if ((total_bits % 8) != 0) begin
            $fatal(1, "Only byte-aligned PT/CT lengths are supported. total_bits=%0d", total_bits);
        end

        total_bytes      = total_bits / 8;
        block_byte_start = block_idx * 16;
        bytes_left       = total_bytes - block_byte_start;

        if (bytes_left < 0)
            bytes_left = 0;

        if (bytes_left > 16)
            block_bytes = 16;
        else
            block_bytes = bytes_left;

        for (byte_idx = 0; byte_idx < block_bytes; byte_idx = byte_idx + 1) begin
            src_byte_idx = block_byte_start + byte_idx;
            tmp[127 - (byte_idx * 8) -: 8] = data_bits[total_bits - 1 - (src_byte_idx * 8) -: 8];
        end

        extract_block = tmp;
    end
    endfunction

    function automatic [127:0] build_j0_from_iv(
        input logic [1023:0] iv_bits,
        input integer        ivlen_bits,
        input logic [127:0]  hash_subkey
    );
        integer block_count;
        integer block_idx;
        logic [127:0] y;
        logic [127:0] iv_block;
        logic [63:0]  iv_len64;
    begin
        if (ivlen_bits == 96) begin
            build_j0_from_iv = {iv_bits[95:0], 32'h00000001};
        end
        else begin
            y = 128'd0;
            block_count = (ivlen_bits + 127) / 128;
            iv_len64 = ivlen_bits;

            for (block_idx = 0; block_idx < block_count; block_idx = block_idx + 1) begin
                iv_block = extract_block(iv_bits, ivlen_bits, block_idx);
                y = ghash_step(y, iv_block, hash_subkey);
            end

            y = ghash_step(y, {64'd0, iv_len64}, hash_subkey);
            build_j0_from_iv = y;
        end
    end
    endfunction

    task automatic reset_dut;
    begin
        @(posedge clk);
        rst_n      <= 1'b0;
        start      <= 1'b0;
        nonce      <= 128'd0;
        plaintext  <= 128'd0;
        valid_bits <= 8'd128;
        key        <= 256'd0;
        hcalc_start <= 1'b0;
        hcalc_key   <= 256'd0;
        hcalc_word  <= 128'd0;

        @(posedge clk);
        rst_n <= 1'b1;

        repeat (4) @(posedge clk);
    end
    endtask

    task automatic aes_encrypt_block(
        input  logic [255:0] key_in,
        input  logic [127:0] word_in,
        output logic [127:0] word_out
    );
        integer wait_cycles;
    begin
        @(posedge clk);
        hcalc_key   <= key_in;
        hcalc_word  <= word_in;
        hcalc_start <= 1'b1;

        @(posedge clk);
        hcalc_start <= 1'b0;

        wait_cycles = 0;
        while ((hcalc_done !== 1'b1) && (wait_cycles < 4000)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (hcalc_done !== 1'b1) begin
            $fatal(1, "AES helper timeout while deriving H.");
        end

        word_out = hcalc_wordout;
    end
    endtask

    task automatic run_rsp_case(
        input integer       count_idx,
        input integer       ivlen_bits,
        input integer       ptlen_bits,
        input integer       aadlen_bits,
        input integer       taglen_bits,
        input logic [255:0] key_in,
        input logic [1023:0] iv_in,
        input logic [1023:0] pt_in,
        input logic [1023:0] ct_exp_in
    );
        integer block_count;
        integer block_idx;
        integer wait_cycles;
        integer pt_idx;
        integer case_mismatch;
        logic [127:0] pt_block;
        logic [127:0] ct_block_exp;
        logic [7:0]   vb;
        logic [127:0] hash_subkey;
        logic [127:0] j0;
        logic [127:0] start_counter;
    begin
        total_cases = total_cases + 1;
        pt_idx      = pt_bucket_idx(ptlen_bits);

        if (pt_idx >= 0)
            pt_total_cases[pt_idx] = pt_total_cases[pt_idx] + 1;

        if ((ivlen_bits != 8) && (ivlen_bits != 96) && (ivlen_bits != 1024)) begin
            skipped_cases = skipped_cases + 1;
            skipped_unsupported_iv_cases = skipped_unsupported_iv_cases + 1;
            if (pt_idx >= 0)
                pt_skipped_cases[pt_idx] = pt_skipped_cases[pt_idx] + 1;
            return;
        end

        if ((ptlen_bits % 8) != 0) begin
            $fatal(1, "Count=%0d has non-byte-aligned PTlen=%0d. Current checker only supports byte-aligned PT.",
                   count_idx, ptlen_bits);
        end

        checked_cases = checked_cases + 1;
        if (pt_idx >= 0)
            pt_checked_cases[pt_idx] = pt_checked_cases[pt_idx] + 1;

        if (ptlen_bits == 0) begin
            passed_cases = passed_cases + 1;
            if (pt_idx >= 0)
                pt_passed_cases[pt_idx] = pt_passed_cases[pt_idx] + 1;
            return;
        end

        block_count = (ptlen_bits + 127) / 128;
        checked_blocks = checked_blocks + block_count;
        if (pt_idx >= 0)
            pt_checked_blocks[pt_idx] = pt_checked_blocks[pt_idx] + block_count;
        case_mismatch = 0;

        reset_dut();

        if (ivlen_bits == 96) begin
            j0 = build_j0_from_iv(iv_in, ivlen_bits, 128'd0);
        end
        else begin
            aes_encrypt_block(key_in, 128'd0, hash_subkey);
            j0 = build_j0_from_iv(iv_in, ivlen_bits, hash_subkey);
        end
        start_counter = inc32(j0);

        @(posedge clk);
        key   <= key_in;
        nonce <= start_counter;

        for (block_idx = 0; block_idx < block_count; block_idx = block_idx + 1) begin
            pt_block   = extract_block(pt_in, ptlen_bits, block_idx);
            ct_block_exp = extract_block(ct_exp_in, ptlen_bits, block_idx);
            vb         = block_valid_count(ptlen_bits, block_idx);

            @(posedge clk);
            plaintext  <= pt_block;
            valid_bits <= vb;
            start      <= 1'b1;

            @(posedge clk);
            start <= 1'b0;

            wait_cycles = 0;
            while ((done !== 1'b1) && (wait_cycles < 4000)) begin
                @(posedge clk);
                wait_cycles = wait_cycles + 1;
            end

            if (done !== 1'b1) begin
                $fatal(1, "Count=%0d block=%0d timeout.", count_idx, block_idx);
            end

            if (ciphertext !== ct_block_exp) begin
                block_failures = block_failures + 1;
                case_mismatch  = 1;
                $error("Count=%0d block=%0d mismatch. got=%032h expected=%032h valid_bits=%0d",
                       count_idx, block_idx, ciphertext, ct_block_exp, vb);
            end
            else begin
                passed_blocks = passed_blocks + 1;
                if (pt_idx >= 0)
                    pt_passed_blocks[pt_idx] = pt_passed_blocks[pt_idx] + 1;
            end
        end

        if (case_mismatch == 0) begin
            passed_cases = passed_cases + 1;
            if (pt_idx >= 0)
                pt_passed_cases[pt_idx] = pt_passed_cases[pt_idx] + 1;
        end
        else begin
            failed_cases = failed_cases + 1;
        end
    end
    endtask

    initial begin
        clk           = 1'b0;
        rst_n         = 1'b0;
        start         = 1'b0;
        nonce         = 128'd0;
        plaintext     = 128'd0;
        valid_bits    = 8'd128;
        key           = 256'd0;
        total_cases   = 0;
        checked_cases = 0;
        passed_cases  = 0;
        failed_cases  = 0;
        skipped_cases = 0;
        skipped_unsupported_iv_cases = 0;
        checked_blocks = 0;
        passed_blocks = 0;
        block_failures = 0;
        hcalc_start = 1'b0;
        hcalc_key   = 256'd0;
        hcalc_word  = 128'd0;

        cur_count  = -1;
        cur_ivlen  = 0;
        cur_ptlen  = 0;
        cur_aadlen = 0;
        cur_taglen = 0;
        cur_key    = '0;
        cur_iv     = '0;
        cur_pt     = '0;
        cur_ct     = '0;
        dummy_tag  = '0;

        for (stat_idx = 0; stat_idx < 5; stat_idx = stat_idx + 1) begin
            pt_total_cases[stat_idx]    = 0;
            pt_checked_cases[stat_idx]  = 0;
            pt_passed_cases[stat_idx]   = 0;
            pt_skipped_cases[stat_idx]  = 0;
            pt_checked_blocks[stat_idx] = 0;
            pt_passed_blocks[stat_idx]  = 0;
        end

        rsp_fd = $fopen("C:/project/FPGA/txt/gcmEncryptExtIV256.rsp", "r");
        if (rsp_fd == 0) begin
            $fatal(1, "Cannot open rsp file: C:/project/FPGA/txt/gcmEncryptExtIV256.rsp");
        end

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
                cur_key   = '0;
                cur_iv    = '0;
                cur_pt    = '0;
                cur_ct    = '0;
                dummy_tag = '0;
            end
            else if ($sscanf(line, "Key = %h", cur_key) == 1) begin
            end
            else if ($sscanf(line, "IV = %h", cur_iv) == 1) begin
            end
            else if ($sscanf(line, "PT = %h", cur_pt) == 1) begin
            end
            else if ($sscanf(line, "CT = %h", cur_ct) == 1) begin
            end
            else if ($sscanf(line, "Tag = %h", dummy_tag) == 1) begin
                run_rsp_case(cur_count, cur_ivlen, cur_ptlen, cur_aadlen, cur_taglen,
                             cur_key, cur_iv, cur_pt, cur_ct);
            end
        end

        $fclose(rsp_fd);

        $display("======================================================");
        $display("GCM CTR RSP Summary");
        $display("Checked condition : IVlen=8/96/1024");
        $display("Total cases       : %0d", total_cases);
        $display("Checked cases     : %0d", checked_cases);
        $display("Matched cases     : %0d", passed_cases);
        $display("Failed cases      : %0d", failed_cases);
        $display("Case match rate   : %0.2f%%", pct_ratio(passed_cases, checked_cases));
        $display("Checked blocks    : %0d", checked_blocks);
        $display("Matched blocks    : %0d", passed_blocks);
        $display("Block match rate  : %0.2f%%", pct_ratio(passed_blocks, checked_blocks));
        $display("Skipped cases     : %0d", skipped_cases);
        $display("  IV unsupported  : %0d", skipped_unsupported_iv_cases);
        $display("------------------------------------------------------");
        $display("By PT length:");
        $display("PTlen=%0d  total=%0d checked=%0d matched_cases=%0d case_match=%0.2f%% skipped=%0d",
                 pt_bucket_len(0), pt_total_cases[0], pt_checked_cases[0], pt_passed_cases[0],
                 pct_ratio(pt_passed_cases[0], pt_checked_cases[0]), pt_skipped_cases[0]);
        $display("PTlen=%0d checked_blocks=%0d matched_blocks=%0d block_match=%0.2f%%",
                 pt_bucket_len(0), pt_checked_blocks[0], pt_passed_blocks[0],
                 pct_ratio(pt_passed_blocks[0], pt_checked_blocks[0]));
        $display("PTlen=%0d total=%0d checked=%0d matched_cases=%0d case_match=%0.2f%% skipped=%0d",
                 pt_bucket_len(1), pt_total_cases[1], pt_checked_cases[1], pt_passed_cases[1],
                 pct_ratio(pt_passed_cases[1], pt_checked_cases[1]), pt_skipped_cases[1]);
        $display("PTlen=%0d checked_blocks=%0d matched_blocks=%0d block_match=%0.2f%%",
                 pt_bucket_len(1), pt_checked_blocks[1], pt_passed_blocks[1],
                 pct_ratio(pt_passed_blocks[1], pt_checked_blocks[1]));
        $display("PTlen=%0d total=%0d checked=%0d matched_cases=%0d case_match=%0.2f%% skipped=%0d",
                 pt_bucket_len(2), pt_total_cases[2], pt_checked_cases[2], pt_passed_cases[2],
                 pct_ratio(pt_passed_cases[2], pt_checked_cases[2]), pt_skipped_cases[2]);
        $display("PTlen=%0d checked_blocks=%0d matched_blocks=%0d block_match=%0.2f%%",
                 pt_bucket_len(2), pt_checked_blocks[2], pt_passed_blocks[2],
                 pct_ratio(pt_passed_blocks[2], pt_checked_blocks[2]));
        $display("PTlen=%0d total=%0d checked=%0d matched_cases=%0d case_match=%0.2f%% skipped=%0d",
                 pt_bucket_len(3), pt_total_cases[3], pt_checked_cases[3], pt_passed_cases[3],
                 pct_ratio(pt_passed_cases[3], pt_checked_cases[3]), pt_skipped_cases[3]);
        $display("PTlen=%0d checked_blocks=%0d matched_blocks=%0d block_match=%0.2f%%",
                 pt_bucket_len(3), pt_checked_blocks[3], pt_passed_blocks[3],
                 pct_ratio(pt_passed_blocks[3], pt_checked_blocks[3]));
        $display("PTlen=%0d total=%0d checked=%0d matched_cases=%0d case_match=%0.2f%% skipped=%0d",
                 pt_bucket_len(4), pt_total_cases[4], pt_checked_cases[4], pt_passed_cases[4],
                 pct_ratio(pt_passed_cases[4], pt_checked_cases[4]), pt_skipped_cases[4]);
        $display("PTlen=%0d checked_blocks=%0d matched_blocks=%0d block_match=%0.2f%%",
                 pt_bucket_len(4), pt_checked_blocks[4], pt_passed_blocks[4],
                 pct_ratio(pt_passed_blocks[4], pt_checked_blocks[4]));

        if (block_failures != 0) begin
            $fatal(1, "GCM CTR verification failed. block_failures=%0d", block_failures);
        end

        $display("GCM CTR verification completed.");
        #20;
        $finish;
    end

endmodule
