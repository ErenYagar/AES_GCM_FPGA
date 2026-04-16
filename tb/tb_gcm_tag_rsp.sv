`timescale 1ns / 1ps

module tb_gcm_tag_rsp;

    logic         clk;
    logic         rst_n;

    logic         data_start;
    logic [127:0] data_nonce;
    logic [127:0] data_plaintext;
    logic [7:0]   data_valid_bits;
    logic [255:0] data_key;
    logic [127:0] data_ciphertext;
    logic         data_done;

    logic         tag_start;
    logic [127:0] tag_nonce;
    logic [127:0] tag_plaintext;
    logic [7:0]   tag_valid_bits;
    logic [255:0] tag_key;
    logic [127:0] tag_ciphertext;
    logic         tag_done;

    logic         hcalc_start;
    logic [255:0] hcalc_key;
    logic [127:0] hcalc_word;
    logic         hcalc_busy;
    logic         hcalc_done;
    logic [127:0] hcalc_wordout;

    logic         ghash_init;
    logic [127:0] ghash_block;
    logic         ghash_en;
    logic [127:0] ghash_h;
    logic         ghash_h_done;
    logic         ghash_busy;
    logic         ghash_done;
    logic [127:0] ghash_y;

    integer total_cases;
    integer checked_cases;
    integer passed_cases;
    integer failed_cases;
    integer passed_ct_cases;
    integer passed_tag_cases;
    integer passed_blocks;
    integer block_failures;
    integer tag_failures;

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

    integer rsp_fd;
    integer rc;
    string  line;

    aes_ctr_wrapper data_ctr (
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

    aes_ctr_wrapper tag_ctr (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (tag_start),
        .nonce     (tag_nonce),
        .plaintext (tag_plaintext),
        .valid_bits(tag_valid_bits),
        .key       (tag_key),
        .ciphertext(tag_ciphertext),
        .done      (tag_done)
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

    GHASH ghash_dut (
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

    always #5 clk = ~clk;

    function automatic [127:0] inc32(input logic [127:0] counter_in);
    begin
        inc32 = {counter_in[127:32], counter_in[31:0] + 32'd1};
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
            $fatal(1, "Only byte-aligned data lengths are supported. total_bits=%0d", total_bits);
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

    function automatic [127:0] align_tag_to_msb(
        input logic [127:0] tag_lsb_aligned,
        input integer       taglen_bits
    );
        integer bit_idx;
        reg [127:0] tmp;
    begin
        tmp = 128'd0;
        for (bit_idx = 0; bit_idx < taglen_bits; bit_idx = bit_idx + 1)
            tmp[127 - bit_idx] = tag_lsb_aligned[taglen_bits - 1 - bit_idx];
        align_tag_to_msb = tmp;
    end
    endfunction

    function automatic [127:0] keep_msb_bits_128(
        input logic [127:0] data_in,
        input integer       bit_count
    );
        integer bit_idx;
        reg [127:0] tmp;
    begin
        tmp = 128'd0;
        for (bit_idx = 0; bit_idx < bit_count; bit_idx = bit_idx + 1)
            tmp[127 - bit_idx] = data_in[127 - bit_idx];
        keep_msb_bits_128 = tmp;
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

    task automatic store_block(
        input      [127:0] blk_in,
        input      integer total_bits,
        input      integer block_idx,
        inout reg [1023:0] data_bits
    );
        integer total_bytes;
        integer block_byte_start;
        integer bytes_left;
        integer block_bytes;
        integer byte_idx;
        integer dst_byte_idx;
    begin
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
            dst_byte_idx = block_byte_start + byte_idx;
            data_bits[total_bits - 1 - (dst_byte_idx * 8) -: 8] = blk_in[127 - (byte_idx * 8) -: 8];
        end
    end
    endtask

    task automatic reset_case_env;
    begin
        @(posedge clk);
        rst_n           <= 1'b0;
        data_start      <= 1'b0;
        data_nonce      <= 128'd0;
        data_plaintext  <= 128'd0;
        data_valid_bits <= 8'd128;
        data_key        <= 256'd0;
        tag_start       <= 1'b0;
        tag_nonce       <= 128'd0;
        tag_plaintext   <= 128'd0;
        tag_valid_bits  <= 8'd128;
        tag_key         <= 256'd0;
        hcalc_start     <= 1'b0;
        hcalc_key       <= 256'd0;
        hcalc_word      <= 128'd0;
        ghash_init      <= 1'b0;
        ghash_block     <= 128'd0;
        ghash_en        <= 1'b0;
        ghash_h         <= 128'd0;
        ghash_h_done    <= 1'b0;

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

        if (hcalc_done !== 1'b1)
            $fatal(1, "AES helper timeout.");

        word_out = hcalc_wordout;
    end
    endtask

    task automatic ghash_load_h(input logic [127:0] h_in);
    begin
        @(posedge clk);
        ghash_h      <= h_in;
        ghash_h_done <= 1'b1;

        @(posedge clk);
        ghash_h_done <= 1'b0;
    end
    endtask

    task automatic ghash_session_init;
    begin
        @(posedge clk);
        ghash_init <= 1'b1;

        @(posedge clk);
        ghash_init <= 1'b0;
    end
    endtask

    task automatic ghash_push_block(input logic [127:0] blk_in);
        integer wait_cycles;
    begin
        @(posedge clk);
        ghash_block <= blk_in;
        ghash_en    <= 1'b1;

        @(posedge clk);
        ghash_en <= 1'b0;

        wait_cycles = 0;
        while ((ghash_done !== 1'b1) && (wait_cycles < 300)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (ghash_done !== 1'b1)
            $fatal(1, "GHASH block timeout.");
    end
    endtask

    task automatic ctr_push_data_block(
        input  logic [255:0] key_in,
        input  logic [127:0] nonce_in,
        input  logic [127:0] block_in,
        input  logic [7:0]   valid_bits_in,
        output logic [127:0] block_out
    );
        integer wait_cycles;
    begin
        @(posedge clk);
        data_key        <= key_in;
        data_nonce      <= nonce_in;
        data_plaintext  <= block_in;
        data_valid_bits <= valid_bits_in;
        data_start      <= 1'b1;

        @(posedge clk);
        data_start <= 1'b0;

        wait_cycles = 0;
        while ((data_done !== 1'b1) && (wait_cycles < 4000)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (data_done !== 1'b1)
            $fatal(1, "Data CTR block timeout.");

        block_out = data_ciphertext;
    end
    endtask

    task automatic ctr_push_tag_block(
        input  logic [255:0] key_in,
        input  logic [127:0] nonce_in,
        input  logic [127:0] block_in,
        output logic [127:0] block_out
    );
        integer wait_cycles;
    begin
        @(posedge clk);
        tag_key        <= key_in;
        tag_nonce      <= nonce_in;
        tag_plaintext  <= block_in;
        tag_valid_bits <= 8'd128;
        tag_start      <= 1'b1;

        @(posedge clk);
        tag_start <= 1'b0;

        wait_cycles = 0;
        while ((tag_done !== 1'b1) && (wait_cycles < 4000)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (tag_done !== 1'b1)
            $fatal(1, "Tag CTR block timeout.");

        block_out = tag_ciphertext;
    end
    endtask

    task automatic run_rsp_case(
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
        integer iv_block_count;
        integer aad_block_count;
        integer ct_block_count;
        integer block_idx;
        integer case_mismatch;
        integer tag_mismatch;
        logic [127:0] h_subkey;
        logic [127:0] j0;
        logic [127:0] start_counter;
        logic [127:0] data_block;
        logic [127:0] ct_block;
        logic [127:0] ct_exp_block;
        logic [127:0] s_block;
        logic [127:0] full_tag;
        logic [127:0] exp_tag_aligned;
        logic [127:0] got_tag_aligned;
        logic [7:0]   vb;
        logic [63:0]  ivlen64;
        logic [63:0]  aadlen64;
        logic [63:0]  ptlen64;
        reg   [1023:0] ct_calc;
    begin
        total_cases = total_cases + 1;

        if ((ivlen_bits != 8) && (ivlen_bits != 96) && (ivlen_bits != 1024))
            return;

        if (((ivlen_bits % 8) != 0) || ((aadlen_bits % 8) != 0) || ((ptlen_bits % 8) != 0))
            $fatal(1, "Count=%0d has non-byte-aligned lengths.", count_idx);

        checked_cases = checked_cases + 1;
        case_mismatch = 0;
        tag_mismatch  = 0;
        ct_calc       = '0;
        ivlen64       = ivlen_bits;
        aadlen64      = aadlen_bits;
        ptlen64       = ptlen_bits;

        reset_case_env();
        aes_encrypt_block(key_in, 128'd0, h_subkey);
        ghash_load_h(h_subkey);

        if (ivlen_bits == 96) begin
            j0 = {iv_in[95:0], 32'h00000001};
        end
        else begin
            iv_block_count = (ivlen_bits + 127) / 128;
            ghash_session_init();

            for (block_idx = 0; block_idx < iv_block_count; block_idx = block_idx + 1)
                ghash_push_block(extract_block(iv_in, ivlen_bits, block_idx));

            ghash_push_block({64'd0, ivlen64});
            j0 = ghash_y;
        end

        start_counter = inc32(j0);
        ct_block_count = (ptlen_bits + 127) / 128;

        for (block_idx = 0; block_idx < ct_block_count; block_idx = block_idx + 1) begin
            data_block   = extract_block(pt_in, ptlen_bits, block_idx);
            ct_exp_block = extract_block(ct_exp_in, ptlen_bits, block_idx);
            vb           = block_valid_count(ptlen_bits, block_idx);

            ctr_push_data_block(key_in, start_counter, data_block, vb, ct_block);

            if (ct_block !== ct_exp_block) begin
                block_failures = block_failures + 1;
                case_mismatch  = 1;
                $error("Count=%0d CT block=%0d mismatch. got=%032h expected=%032h valid_bits=%0d",
                       count_idx, block_idx, ct_block, ct_exp_block, vb);
            end
            else begin
                passed_blocks = passed_blocks + 1;
            end

            store_block(ct_block, ptlen_bits, block_idx, ct_calc);
            start_counter = start_counter + 128'd1;
        end

        if (case_mismatch == 0)
            passed_ct_cases = passed_ct_cases + 1;

        aad_block_count = (aadlen_bits + 127) / 128;
        ghash_session_init();

        for (block_idx = 0; block_idx < aad_block_count; block_idx = block_idx + 1)
            ghash_push_block(extract_block(aad_in, aadlen_bits, block_idx));

        for (block_idx = 0; block_idx < ct_block_count; block_idx = block_idx + 1)
            ghash_push_block(extract_block(ct_calc, ptlen_bits, block_idx));

        ghash_push_block({aadlen64, ptlen64});
        s_block = ghash_y;

        ctr_push_tag_block(key_in, j0, s_block, full_tag);

        exp_tag_aligned = align_tag_to_msb(tag_exp_in, taglen_bits);
        got_tag_aligned = keep_msb_bits_128(full_tag, taglen_bits);

        if (got_tag_aligned !== exp_tag_aligned) begin
            tag_failures = tag_failures + 1;
            tag_mismatch = 1;
            $error("Count=%0d TAG mismatch. got=%032h expected=%032h taglen=%0d",
                   count_idx, got_tag_aligned, exp_tag_aligned, taglen_bits);
        end
        else begin
            passed_tag_cases = passed_tag_cases + 1;
        end

        if ((case_mismatch == 0) && (tag_mismatch == 0))
            passed_cases = passed_cases + 1;
        else
            failed_cases = failed_cases + 1;
    end
    endtask

    initial begin
        clk            = 1'b0;
        rst_n          = 1'b0;
        data_start     = 1'b0;
        data_nonce     = 128'd0;
        data_plaintext = 128'd0;
        data_valid_bits= 8'd128;
        data_key       = 256'd0;
        tag_start      = 1'b0;
        tag_nonce      = 128'd0;
        tag_plaintext  = 128'd0;
        tag_valid_bits = 8'd128;
        tag_key        = 256'd0;
        hcalc_start    = 1'b0;
        hcalc_key      = 256'd0;
        hcalc_word     = 128'd0;
        ghash_init     = 1'b0;
        ghash_block    = 128'd0;
        ghash_en       = 1'b0;
        ghash_h        = 128'd0;
        ghash_h_done   = 1'b0;

        total_cases    = 0;
        checked_cases  = 0;
        passed_cases   = 0;
        failed_cases   = 0;
        passed_ct_cases = 0;
        passed_tag_cases = 0;
        passed_blocks  = 0;
        block_failures = 0;
        tag_failures   = 0;

        cur_count  = -1;
        cur_ivlen  = 0;
        cur_ptlen  = 0;
        cur_aadlen = 0;
        cur_taglen = 0;
        cur_key    = '0;
        cur_iv     = '0;
        cur_aad    = '0;
        cur_pt     = '0;
        cur_ct     = '0;
        cur_tag    = '0;

        rsp_fd = $fopen("C:/project/FPGA/txt/gcmEncryptExtIV256.rsp", "r");
        if (rsp_fd == 0)
            $fatal(1, "Cannot open rsp file: C:/project/FPGA/txt/gcmEncryptExtIV256.rsp");

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
                run_rsp_case(cur_count, cur_ivlen, cur_aadlen, cur_ptlen, cur_taglen,
                             cur_key, cur_iv, cur_aad, cur_pt, cur_ct, cur_tag);
            end
        end

        $fclose(rsp_fd);

        $display("======================================================");
        $display("GCM TAG RSP Summary");
        $display("Checked condition : IVlen=8/96/1024");
        $display("Total cases       : %0d", total_cases);
        $display("Checked cases     : %0d", checked_cases);
        $display("Matched CT cases  : %0d", passed_ct_cases);
        $display("Matched TAG cases : %0d", passed_tag_cases);
        $display("Matched full cases: %0d", passed_cases);
        $display("Failed cases      : %0d", failed_cases);
        $display("Case match rate   : %0.2f%%", pct_ratio(passed_cases, checked_cases));
        $display("Passed blocks     : %0d", passed_blocks);
        $display("Block failures    : %0d", block_failures);
        $display("Tag failures      : %0d", tag_failures);

        if ((failed_cases != 0) || (block_failures != 0) || (tag_failures != 0))
            $fatal(1, "GCM TAG verification failed.");

        $display("GCM TAG verification completed.");
        #20;
        $finish;
    end

endmodule
