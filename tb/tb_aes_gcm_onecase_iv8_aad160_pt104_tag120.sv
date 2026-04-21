`timescale 1ns / 1ps

module tb_aes_gcm_onecase_iv8_aad160_pt104_tag120;

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

    localparam logic [255:0] KEY =
        256'hebcc5c17f68cca7905cf35e367a0849c35a235c62086e5561f0d21e578b1320f;
    localparam logic [1023:0] IV =
        1024'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000092;
    localparam integer IV_BITS = 8;
    localparam logic [1023:0] AAD =
        1024'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007c28bc90f03815a3de332ec1293c387b4a57ea48;
    localparam integer AAD_BITS = 160;
    localparam logic [1023:0] PT =
        1024'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000933d66540bb404e6c4acf8abc0;
    localparam integer PT_BITS = 104;
    localparam logic [127:0] TAG_EXP =
        128'h00d15bb6760c980ac216977bb5abc666;
    localparam integer TAG_BITS = 120;
    localparam logic [127:0] CT_EXP =
        128'h009bb4f163f3db35e3a3eb9d6e4c;

    top dut (
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .in(in),
        .in_valid(in_valid),
        .in_type(in_type),
        .in_valid_bit(in_valid_bit),
        .last(last),
        .pc_ct_valid(pc_ct_valid),
        .tag_valid(tag_valid),
        .pc_ct_len_bit(pc_ct_len_bit),
        .pc_ct_valid_bit(pc_ct_valid_bit),
        .out(out)
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
        end
        else begin
            for (byte_idx = 0; byte_idx < total_bytes; byte_idx = byte_idx + 1) begin
                @(posedge clk);
                in           <= get_buffer_byte_1024(data_bits, total_bits, byte_idx);
                in_valid     <= 1'b1;
                in_type      <= field_type;
                in_valid_bit <= (byte_idx == (total_bytes - 1)) ? total_bits[10:0] : 11'd0;
                last         <= (byte_idx == (total_bytes - 1));
            end
        end

        @(posedge clk);
        in_valid     <= 1'b0;
        in_type      <= 3'd6;
        in_valid_bit <= 11'd0;
        last         <= 1'b0;
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
            in           <= get_buffer_byte_256(data_bits, total_bits, byte_idx);
            in_valid     <= 1'b1;
            in_type      <= field_type;
            in_valid_bit <= (byte_idx == (total_bytes - 1)) ? total_bits[10:0] : 11'd0;
            last         <= (byte_idx == (total_bytes - 1));
        end

        @(posedge clk);
        in_valid     <= 1'b0;
        in_type      <= 3'd6;
        in_valid_bit <= 11'd0;
        last         <= 1'b0;
    end
    endtask

    initial begin
        integer ct_seen;
        integer tag_seen;
        integer wait_cycles;

        clk          = 1'b0;
        rst          = 1'b0;
        mode         = 1'b0;
        in           = 8'd0;
        in_valid     = 1'b0;
        in_type      = 3'd6;
        in_valid_bit = 11'd0;
        last         = 1'b0;

        reset_case_env();
        send_field_256(3'd1, KEY, 256);
        send_field_1024(3'd0, IV, IV_BITS);
        send_field_1024(3'd2, AAD, AAD_BITS);
        send_field_1024(3'd3, PT, PT_BITS);
        send_field_1024(3'd5, {896'd0, TAG_EXP}, TAG_BITS);

        ct_seen = 0;
        tag_seen = 0;
        wait_cycles = 0;

        while (wait_cycles < 40000) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;

            if (pc_ct_valid) begin
                if (pc_ct_len_bit !== PT_BITS[10:0])
                    $fatal(1, "pc_ct_len_bit mismatch. got=%0d expected=%0d", pc_ct_len_bit, PT_BITS);
                if (out !== get_buffer_byte_1024({896'd0, CT_EXP}, PT_BITS, ct_seen))
                    $fatal(1, "CT mismatch at byte %0d. got=%02h expected=%02h", ct_seen, out, get_buffer_byte_1024({896'd0, CT_EXP}, PT_BITS, ct_seen));
                ct_seen = ct_seen + 1;
            end

            if (tag_valid) begin
                if (out !== get_buffer_byte_1024({896'd0, TAG_EXP}, TAG_BITS, tag_seen))
                    $fatal(1, "TAG mismatch at byte %0d. got=%02h expected=%02h", tag_seen, out, get_buffer_byte_1024({896'd0, TAG_EXP}, TAG_BITS, tag_seen));
                tag_seen = tag_seen + 1;
            end

            if ((ct_seen == ((PT_BITS + 7) / 8)) && (tag_seen == ((TAG_BITS + 7) / 8))) begin
                $display("One-case regression completed.");
                #20;
                $finish;
            end
        end

        $fatal(1, "Timeout waiting for one-case regression.");
    end

endmodule
