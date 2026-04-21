`timescale 1ns / 1ps

module tb_core_g10519_dec;

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
        256'hbb0c22762ef1d89b9f5d32829c10ae53a715773c4cd71debc17af80ede2374ea;
    localparam logic [1023:0] IV =
        1024'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d8;
    localparam integer IV_BITS = 8;
    localparam logic [1023:0] AAD = 1024'd0;
    localparam integer AAD_BITS = 0;
    localparam logic [1023:0] CT = 1024'd0;
    localparam integer PT_BITS = 0;
    localparam logic [127:0] TAG =
        128'h00345a886233369f643b406f7b481cbb;
    localparam integer TAG_BITS = 120;

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
        integer pt_seen;
        integer auth_seen;
        integer wait_cycles;
        bit finished;
        bit left_collect;

        clk          = 1'b0;
        rst          = 1'b0;
        mode         = 1'b0;
        in           = 8'd0;
        in_valid     = 1'b0;
        in_type      = 3'd6;
        in_valid_bit = 11'd0;
        last         = 1'b0;

        reset_case_env();
        mode <= 1'b1;

        send_field_256(3'd1, KEY, 256);
        send_field_1024(3'd0, IV, IV_BITS);
        send_field_1024(3'd2, AAD, AAD_BITS);
        send_field_1024(3'd4, CT, PT_BITS);
        send_field_1024(3'd5, {896'd0, TAG}, TAG_BITS);

        pt_seen     = 0;
        auth_seen   = 0;
        wait_cycles = 0;
        finished    = 1'b0;
        left_collect = 1'b0;

        while ((wait_cycles < 40000) && !finished) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;

            if (dut.state != 5'd0)
                left_collect = 1'b1;

            if (pc_ct_valid) begin
                $fatal(1, "Unexpected plaintext byte for g10519. out=%02h", out);
            end

            if (tag_valid)
                auth_seen = auth_seen + 1;

            if (left_collect && (dut.state == 5'd0))
                finished = 1'b1;
        end

        if (!finished)
            $fatal(1, "Timeout waiting for g10519 decrypt completion.");

        if (auth_seen != 1)
            $fatal(1, "Expected exactly one auth pulse, got %0d", auth_seen);

        if (pt_seen != 0)
            $fatal(1, "Expected zero plaintext bytes, got %0d", pt_seen);

        $display("g10519 core-only decrypt completed.");
        #20;
        $finish;
    end

endmodule
