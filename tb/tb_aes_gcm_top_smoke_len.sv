`timescale 1ns / 1ps

module tb_aes_gcm_top_smoke_len;

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
        256'h603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4;
    localparam logic [1023:0] IV =
        1024'h000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0f1f2f3f4f5f6f7f8f9fafb;
    localparam integer IV_BITS = 96;
    localparam logic [1023:0] AAD =
        1024'h00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
    localparam integer AAD_BITS = 0;
    localparam logic [1023:0] PT =
        1024'h0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006bc1bee22e409f96e93d7e11739317;
    localparam integer PT_BITS = 120;
    localparam logic [127:0] TAG_EXP =
        128'h00000000000000000000000000000000;
    localparam integer TAG_BITS = 128;

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

    task automatic reset_env;
    begin
        // Gate-level/timing netlist simulation often needs extra startup time
        // to let global initialization and internal reset release settle.
        repeat (20) @(posedge clk);

        @(posedge clk);
        rst <= 1'b1;
        mode <= 1'b0;
        in <= 8'd0;
        in_valid <= 1'b0;
        in_type <= 3'd6;
        in_valid_bit <= 11'd0;
        last <= 1'b0;

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
            in <= 8'd0;
            in_valid <= 1'b1;
            in_type <= field_type;
            in_valid_bit <= 11'd0;
            last <= 1'b1;
        end
        else begin
            for (byte_idx = 0; byte_idx < total_bytes; byte_idx = byte_idx + 1) begin
                @(posedge clk);
                in <= get_buffer_byte_1024(data_bits, total_bits, byte_idx);
                in_valid <= 1'b1;
                in_type <= field_type;
                in_valid_bit <= (byte_idx == (total_bytes - 1)) ? total_bits[10:0] : 11'd0;
                last <= (byte_idx == (total_bytes - 1));
            end
        end

        @(posedge clk);
        in_valid <= 1'b0;
        in_type <= 3'd6;
        in_valid_bit <= 11'd0;
        last <= 1'b0;
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
            in <= data_bits[((total_bytes - 1 - byte_idx) * 8) +: 8];
            in_valid <= 1'b1;
            in_type <= field_type;
            in_valid_bit <= (byte_idx == (total_bytes - 1)) ? total_bits[10:0] : 11'd0;
            last <= (byte_idx == (total_bytes - 1));
        end

        @(posedge clk);
        in_valid <= 1'b0;
        in_type <= 3'd6;
        in_valid_bit <= 11'd0;
        last <= 1'b0;
    end
    endtask

    initial begin
        integer byte_seen;
        integer tag_byte_seen;
        integer wait_cycles;
        bit finished;

        clk = 1'b0;
        rst = 1'b0;
        mode = 1'b0;
        in = 8'd0;
        in_valid = 1'b0;
        in_type = 3'd6;
        in_valid_bit = 11'd0;
        last = 1'b0;

        reset_env();
        send_field_256(3'd1, KEY, 256);
        send_field_1024(3'd0, IV, IV_BITS);
        send_field_1024(3'd2, AAD, AAD_BITS);
        send_field_1024(3'd3, PT, PT_BITS);
        send_field_1024(3'd5, {896'd0, TAG_EXP}, TAG_BITS);

        byte_seen = 0;
        tag_byte_seen = 0;
        wait_cycles = 0;
        finished = 1'b0;
        while ((wait_cycles < 50000) && !finished) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
            if (pc_ct_valid) begin
                if (pc_ct_len_bit !== PT_BITS[10:0]) begin
                    $fatal(1, "pc_ct_len_bit mismatch. got=%0d expected=%0d", pc_ct_len_bit, PT_BITS);
                end
                if (byte_seen < ((PT_BITS + 7) / 8) - 1) begin
                    if (pc_ct_valid_bit !== 4'd8)
                        $fatal(1, "mid-byte valid mismatch. got=%0d", pc_ct_valid_bit);
                end
                else begin
                    if (pc_ct_valid_bit !== 4'd8)
                        $fatal(1, "last-byte valid mismatch. got=%0d", pc_ct_valid_bit);
                end
                byte_seen = byte_seen + 1;
            end

            if (tag_valid)
                tag_byte_seen = tag_byte_seen + 1;

            if ((byte_seen == ((PT_BITS + 7) / 8)) &&
                (tag_byte_seen == ((TAG_BITS + 7) / 8)))
                finished = 1'b1;
        end

        if (!finished)
            $fatal(1, "smoke timeout");

        $display("Smoke length check completed.");
        #20;
        $finish;
    end

endmodule
