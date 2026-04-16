`timescale 1ns / 1ps

module tb_aes_ctr_synth_impl;

    logic         clk;
    logic         rst_n;
    logic         start;
    logic [127:0] nonce;
    logic [127:0] plaintext;
    logic [7:0]   valid_bits;
    logic [255:0] key;
    logic [127:0] ciphertext;
    logic         done;

    integer case_passed;
    integer case_failed;
    integer block_passed;
    integer block_failed;

    localparam logic [255:0] KEY_96_104 =
        256'h82c4f12eeec3b2d3d157b0f992d292b237478d2cecc1d5f161389b97f999057a;
    localparam logic [1023:0] IV_96_104  = 1024'h7b40b20f5f397177990ef2d1;
    localparam integer        IVLEN_96_104 = 96;
    localparam logic [127:0]  NONCE_96_104 = 128'h7b40b20f5f397177990ef2d100000002;
    localparam logic [1023:0] PT_96_104  = 1024'h982a296ee1cd7086afad976945;
    localparam logic [1023:0] CT_96_104  = 1024'hec8e05a0471d6b43a59ca5335f;
    localparam integer        PTLEN_96_104 = 104;

    localparam logic [255:0] KEY_96_256 =
        256'h268ed1b5d7c9c7304f9cae5fc437b4cd3aebe2ec65f0d85c3918d3d3b5bba89b;
    localparam logic [1023:0] IV_96_256  = 1024'h9ed9d8180564e0e945f5e5d4;
    localparam integer        IVLEN_96_256 = 96;
    localparam logic [127:0]  NONCE_96_256 = 128'h9ed9d8180564e0e945f5e5d400000002;
    localparam logic [1023:0] PT_96_256  =
        1024'hfe29a40d8ebf57262bdb87191d01843f4ca4b2de97d88273154a0b7d9e2fdb80;
    localparam logic [1023:0] CT_96_256  =
        1024'h791a4a026f16f3a5ea06274bf02baab469860abde5e645f3dd473a5acddeecfc;
    localparam integer        PTLEN_96_256 = 256;

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

    always #5 clk = ~clk;

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

    task automatic reset_env;
    begin
        @(posedge clk);
        rst_n       <= 1'b0;
        start       <= 1'b0;
        nonce       <= 128'd0;
        plaintext   <= 128'd0;
        valid_bits  <= 8'd128;
        key         <= 256'd0;

        @(posedge clk);
        rst_n <= 1'b1;
        repeat (4) @(posedge clk);
    end
    endtask

    task automatic run_case(
        input integer        case_idx,
        input integer        ivlen_bits,
        input integer        ptlen_bits,
        input logic [127:0]  nonce_in,
        input logic [255:0]  key_in,
        input logic [1023:0] iv_in,
        input logic [1023:0] pt_in,
        input logic [1023:0] ct_exp_in
    );
        integer block_count;
        integer block_idx;
        integer wait_cycles;
        logic [127:0] pt_block;
        logic [127:0] ct_block_exp;
        logic [7:0]   vb;
        integer case_error;
    begin
        block_count = (ptlen_bits + 127) / 128;
        case_error  = 0;

        reset_env();

        @(posedge clk);
        key   <= key_in;
        nonce <= nonce_in;

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

            if (done !== 1'b1)
                $fatal(1, "Smoke case %0d block %0d timeout.", case_idx, block_idx);

            if (ciphertext !== ct_block_exp) begin
                block_failed = block_failed + 1;
                case_error   = 1;
                $error("Smoke case %0d block %0d mismatch. got=%032h expected=%032h valid_bits=%0d",
                       case_idx, block_idx, ciphertext, ct_block_exp, vb);
            end
            else begin
                block_passed = block_passed + 1;
            end
        end

        if (case_error != 0) begin
            case_failed = case_failed + 1;
        end
        else begin
            case_passed = case_passed + 1;
            $display("Smoke case %0d PASS. IVlen=%0d PTlen=%0d blocks=%0d",
                     case_idx, ivlen_bits, ptlen_bits, block_count);
        end
    end
    endtask

    initial begin
        clk         = 1'b0;
        rst_n       = 1'b0;
        start       = 1'b0;
        nonce       = 128'd0;
        plaintext   = 128'd0;
        valid_bits  = 8'd128;
        key         = 256'd0;
        case_passed = 0;
        case_failed = 0;
        block_passed = 0;
        block_failed = 0;

        // Xilinx post-synth/post-impl netlist simulation keeps GSR active
        // during the initial startup window. Delay stimulus until after that.
        #200;

        run_case(0, IVLEN_96_104, PTLEN_96_104, NONCE_96_104, KEY_96_104, IV_96_104, PT_96_104, CT_96_104);
        run_case(1, IVLEN_96_256, PTLEN_96_256, NONCE_96_256, KEY_96_256, IV_96_256, PT_96_256, CT_96_256);

        $display("======================================================");
        $display("AES-CTR Netlist Smoke Summary");
        $display("Cases passed  : %0d", case_passed);
        $display("Cases failed  : %0d", case_failed);
        $display("Blocks passed : %0d", block_passed);
        $display("Blocks failed : %0d", block_failed);

        if ((case_failed != 0) || (block_failed != 0))
            $fatal(1, "Netlist smoke verification failed.");

        $display("Netlist smoke verification completed.");
        #20;
        $finish;
    end

endmodule
