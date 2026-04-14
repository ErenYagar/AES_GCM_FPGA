`timescale 1ns / 1ps

module tb_top_25cases;

    logic        clk;
    logic        rst;
    logic [7:0]  in;
    logic        in_valid;
    logic [2:0]  in_type;
    logic [10:0] in_valid_bit;
    logic        last;

    logic [7:0]   out;
    logic [127:0] dbg_GHASH_in;
    logic [127:0] dbg_GHASH_block;
    logic         dbg_GHASH_en;
    logic [127:0] dbg_lenbit;
    logic [7:0]   dbg_byte_num;

    localparam logic [2:0] TYPE_CT_DATA   = 3'd0;
    localparam logic [2:0] TYPE_AAD_DATA  = 3'd1;
    localparam logic [2:0] TYPE_CT_LEN    = 3'd2;
    localparam logic [2:0] TYPE_AAD_LEN   = 3'd3;
    localparam logic [2:0] TYPE_LEN_BLOCK = 3'd5;

    localparam int NUM_CASES = 25;

    top dut (
        .clk            (clk),
        .rst            (rst),
        .in             (in),
        .in_valid       (in_valid),
        .in_type        (in_type),
        .in_valid_bit   (in_valid_bit),
        .last           (last),
        .out            (out),
        .dbg_GHASH_in   (dbg_GHASH_in),
        .dbg_GHASH_block(dbg_GHASH_block),
        .dbg_GHASH_en   (dbg_GHASH_en),
        .dbg_lenbit     (dbg_lenbit),
        .dbg_byte_num   (dbg_byte_num)
    );

    always #5 clk = ~clk;

    logic [10:0] ptlen_arr  [0:NUM_CASES-1];
    logic [10:0] aadlen_arr [0:NUM_CASES-1];
    logic [407:0] pt_arr    [0:NUM_CASES-1];
    logic [719:0] aad_arr   [0:NUM_CASES-1];

    integer i;
    integer current_case_idx;
    integer case_ghash_evt_count;

    task automatic send_len(input logic [2:0] t, input logic [10:0] len_bits);
    begin
        @(posedge clk);
        in           <= 8'h00;
        in_valid     <= 1'b1;
        in_type      <= t;
        in_valid_bit <= len_bits;
        last         <= 1'b0;

        @(posedge clk);
        in           <= 8'h00;
        in_valid     <= 1'b0;
        in_type      <= 3'd0;
        in_valid_bit <= 11'd0;
        last         <= 1'b0;
    end
    endtask

task automatic send_aad(input logic [719:0] data, input int num_bytes);
    int k;
begin
    if (num_bytes == 0) return;

    for (k = 0; k < num_bytes; k++) begin
        @(posedge clk);
        in           <= data[(num_bytes-k)*8-1 -: 8];
        in_valid     <= 1'b1;
        in_type      <= TYPE_AAD_DATA;
        in_valid_bit <= 11'd8;
        last         <= (k == num_bytes-1);
    end

    @(posedge clk);
    in           <= 8'h00;
    in_valid     <= 1'b0;
    in_type      <= 3'd0;
    in_valid_bit <= 11'd0;
    last         <= 1'b0;
end
endtask

task automatic send_pt(input logic [407:0] data, input int num_bytes);
    int k;
begin
    if (num_bytes == 0) return;

    for (k = 0; k < num_bytes; k++) begin
        @(posedge clk);
        in           <= data[(num_bytes-k)*8-1 -: 8];
        in_valid     <= 1'b1;
        in_type      <= TYPE_CT_DATA;
        in_valid_bit <= 11'd8;
        last         <= (k == num_bytes-1);
    end

    @(posedge clk);
    in           <= 8'h00;
    in_valid     <= 1'b0;
    in_type      <= 3'd0;
    in_valid_bit <= 11'd0;
    last         <= 1'b0;
end
endtask

    task automatic send_len_block();
    begin
        @(posedge clk);
        in           <= 8'h00;
        in_valid     <= 1'b1;
        in_type      <= TYPE_LEN_BLOCK;
        in_valid_bit <= 11'd0;
        last         <= 1'b0;

        @(posedge clk);
        in           <= 8'h00;
        in_valid     <= 1'b0;
        in_type      <= 3'd0;
        in_valid_bit <= 11'd0;
        last         <= 1'b0;
    end
    endtask

    task automatic run_one_case(input int idx);
    begin
        current_case_idx     = idx;
        case_ghash_evt_count = 0;

        $display("======================================================");
        $display("CASE %0d", idx+1);
        $display("PTlen  = %0d", ptlen_arr[idx]);
        $display("AADlen = %0d", aadlen_arr[idx]);
        $display("PT     = %h", pt_arr[idx]);
        $display("AAD    = %h", aad_arr[idx]);

        send_len(TYPE_AAD_LEN, aadlen_arr[idx]);
        send_len(TYPE_CT_LEN , ptlen_arr[idx]);

        send_aad(aad_arr[idx], aadlen_arr[idx]/8);
        send_pt (pt_arr[idx] , ptlen_arr[idx]/8);

        send_len_block();

        repeat (8) @(posedge clk);
    end
    endtask

    initial begin
        clk          = 1'b0;
        rst          = 1'b0;
        in           = 8'h00;
        in_valid     = 1'b0;
        in_type      = 3'd0;
        in_valid_bit = 11'd0;
        last         = 1'b0;

        for (i = 0; i < NUM_CASES; i = i + 1) begin
            ptlen_arr[i]  = '0;
            aadlen_arr[i] = '0;
            pt_arr[i]     = '0;
            aad_arr[i]    = '0;
        end

        // 1
        ptlen_arr[0]  = 11'd0;
        aadlen_arr[0] = 11'd0;

        // 2
        ptlen_arr[1]  = 11'd0;
        aadlen_arr[1] = 11'd128;
        aad_arr[1]    = 720'h6749daeea367d0e9809e2dc2f309e6e3;

        // 3
        ptlen_arr[2]  = 11'd0;
        aadlen_arr[2] = 11'd160;
        aad_arr[2]    = 720'head961939a33dd578f8e93db8b28a1c85362905f;

        // 4
        ptlen_arr[3]  = 11'd0;
        aadlen_arr[3] = 11'd384;
        aad_arr[3]    = 720'hb28d1621ee110f4c9d709fad764bba2dd6d291bc003748faac6d901937120d41c1b7ce67633763e99e05c71363fceca8;

        // 5
        ptlen_arr[4]  = 11'd0;
        aadlen_arr[4] = 11'd720;
        aad_arr[4]    = 720'h09c8f445ce5b71465695f838c4bb2b00624a1c9185a3d552546d9d2ee4870007aaf3007008f8ae9affb7588b88d09a90e58b457f88f1e3752e3fb949ce378670b67a95f8cf7f5c7ceb650efd735dbc652cae06e546a5dbd861bd;

        // 6
        ptlen_arr[5]  = 11'd128;
        aadlen_arr[5] = 11'd0;
        pt_arr[5]     = 408'h99e4e926ffe927f691893fb79a96b067;

        // 7
        ptlen_arr[6]  = 11'd128;
        aadlen_arr[6] = 11'd128;
        pt_arr[6]     = 408'hfd671cab1ee21f0df6bb610bf94f0e69;
        aad_arr[6]    = 720'hfec0311013202e4ffdc4204926ae0ddf;

        // 8
        ptlen_arr[7]  = 11'd128;
        aadlen_arr[7] = 11'd160;
        pt_arr[7]     = 408'h79490d4d233ba594ece1142e310a9857;
        aad_arr[7]    = 720'hb5fe530a5bafce7ae79b3c15471fa68334ab378e;

        // 9
        ptlen_arr[8]  = 11'd128;
        aadlen_arr[8] = 11'd384;
        pt_arr[8]     = 408'hb6de1699931f2252efc98d491d22ee12;
        aad_arr[8]    = 720'h76f43d5664c7ac1b4de43f2e2c4bc71f6918e0762f40e5dd5597ef4ff215855a4fd26d3ea6ccbd4e10789948fa692433;

        // 10
        ptlen_arr[9]  = 11'd128;
        aadlen_arr[9] = 11'd720;
        pt_arr[9]     = 408'h6fa9b08176e9963927afba1e5f969a42;
        aad_arr[9]    = 720'hcb5114a001989339657427eb88329d6ce9c69694dc91a69b7557d62184e57832ec76d162fc9c47490bb3d78e5899445cecf85d36cb1f07fed5a3d82aaf7e9590f3ed74ad13b13c8adbfc7f29d7b151448d6f29d11d0bd3d03b76;

        // 11
        ptlen_arr[10]  = 11'd104;
        aadlen_arr[10] = 11'd0;
        pt_arr[10]     = 408'h8ddb3397bd42853193cb0f80c9;

        // 12
        ptlen_arr[11]  = 11'd104;
        aadlen_arr[11] = 11'd128;
        pt_arr[11]     = 408'h5e2103eb3e739298c9f5c6ba0e;
        aad_arr[11]    = 720'h825cc713bb41c789c1ace0f2d0dd3377;

        // 13
        ptlen_arr[12]  = 11'd104;
        aadlen_arr[12] = 11'd160;
        pt_arr[12]     = 408'he21629cc973fbe40176e621d9d;
        aad_arr[12]    = 720'h78e7374da7c77be5938de8dd76cf0308618306a9;

        // 14
        ptlen_arr[13]  = 11'd104;
        aadlen_arr[13] = 11'd384;
        pt_arr[13]     = 408'hcdd251d449551fec080425d565;
        aad_arr[13]    = 720'h6330d16002a8fd51762043f2df06ecc9c535c96ebe33526d8faf767c2c2af3cd01f4e02fa102f15ce0236d9c9cef26de;

        // 15
        ptlen_arr[14]  = 11'd104;
        aadlen_arr[14] = 11'd720;
        pt_arr[14]     = 408'h8adb36d2c2358e505b5d214ad0;
        aad_arr[14]    = 720'hb78e31b1793c2b758494e9c8ae7d3cee6e3697d40ffba04d3c6cbe25e12eeea365d5a2e7b46c4245771b7b2eb2062a640e6090d9f81caf63207865bb4f2c4cf6af81898560e3aeaa521dcd2c336e0ec57faffef58683a72710b9;

        // 16
        ptlen_arr[15]  = 11'd256;
        aadlen_arr[15] = 11'd0;
        pt_arr[15]     = 408'h7f13fcaf0db79d792823a9271b1213a98d116eff7e8e3c86ddeb6a0a03f13afa;

        // 17
        ptlen_arr[16]  = 11'd256;
        aadlen_arr[16] = 11'd128;
        pt_arr[16]     = 408'h3b3186a02475f536d80d8bd326ecc8b33dd04f66f8ba1d20917952410b05c2ed;
        aad_arr[16]    = 720'h05d29369922fdac1a7b37f07953fe175;

        // 18
        ptlen_arr[17]  = 11'd256;
        aadlen_arr[17] = 11'd160;
        pt_arr[17]     = 408'h4349221f6647a906a47e64b5a7a1deb2f7caf5c3fef16f0b968d625bca363dca;
        aad_arr[17]    = 720'h953bcbd731a139c5de3a2b75e9ffa4f48018266a;

        // 19
        ptlen_arr[18]  = 11'd256;
        aadlen_arr[18] = 11'd384;
        pt_arr[18]     = 408'h4835d489828325a0cb38a59fc29cfeedccae25f2e9c399281d9b7641fb609765;
        aad_arr[18]    = 720'hd51cedf9a30e476de37c90b2f60882193630c7497a921ab01590a26bce8cb247e3b5590e7b07b955956ca89c7a041988;

        // 20
        ptlen_arr[19]  = 11'd256;
        aadlen_arr[19] = 11'd720;
        pt_arr[19]     = 408'h7a133385ead593c3907806bec12240943f00a8c3c1b0ac73b8b81af2d3192c6f;
        aad_arr[19]    = 720'hf00847f848d758494afd90b6c49375e0e76e26dcba284e9a608eae33b87ad2deac28ccf40d2db154bbe10dc0fd69b09c9b8920f0f74ea62dd68df275074e288e76a290336b3bf6b485c0159525c362092408f51167c8e59e218f;

        // 21
        ptlen_arr[20]  = 11'd408;
        aadlen_arr[20] = 11'd0;
        pt_arr[20]     = 408'hab4fd35bef66addfd2856b3881ff2c74fdc09c82abe339f49736d69b2bd0a71a6b4fe8fc53f50f8b7d6d6d6138ab442c7f653f;

        // 22
        ptlen_arr[21]  = 11'd408;
        aadlen_arr[21] = 11'd128;
        pt_arr[21]     = 408'h427ec568ad8367c202f5d9999240f9994cc113500154f7f49e9ca27cc8154143b855238bca5c7bd6d9852b4eebd41e4eb98f16;
        aad_arr[21]    = 720'h2e8bdde32258a5fcd8cd21037d0545eb;

        // 23
        ptlen_arr[22]  = 11'd408;
        aadlen_arr[22] = 11'd160;
        pt_arr[22]     = 408'h34b797bb82250e23c5e796db2c37e488b3b99d1b981cea5e5b0c61a0b39adb6bd6ef1f50722e2e4f81115cfcf53f842e2a6c08;
        aad_arr[22]    = 720'h98f8ae1735c39f732e2cbee1156dabeb854ec7a2;

        // 24
        ptlen_arr[23]  = 11'd408;
        aadlen_arr[23] = 11'd384;
        pt_arr[23]     = 408'haf6b17fd67bc1173b063fc6f0941483cee9cbbbbed3a4dcff55a74b0c9535b977efa640e5b1a30faa859fd3daa8dd780cc94a0;
        aad_arr[23]    = 720'hbac1ddefd111d471e75f0efb0f8127b4da923ecc788a5c91e3e2f65e2943e4caf42f54896604af19ed0b4d8697d45ab9;

        // 25
        ptlen_arr[24]  = 11'd408;
        aadlen_arr[24] = 11'd720;
        pt_arr[24]     = 408'h461cd0caf7427a3d44408d825ed719237272ecd503b9094d1f62c97d63ed83a0b50bdc804ffdd7991da7a5b6dcf48d4bcd2cbc;
        aad_arr[24]    = 720'h19a9a1cfc647346781bef51ed9070d05f99a0e0192a223c5cd2522dbdf97d9739dd39fb178ade3339e68774b058aa03e9a20a9a205bc05f32381df4d63396ef691fefd5a71b49a2ad82d5ea428778ca47ee1398792762413cff4;

        #20;
        rst = 1'b1;

        for (i = 0; i < NUM_CASES; i = i + 1) begin
            run_one_case(i);
        end

        $display("======================================================");
        $display("All cases done. Total case count = %0d", NUM_CASES);

        #100;
        $finish;
    end

    always_ff @(posedge clk) begin
        if (dbg_GHASH_en) begin
            if ((current_case_idx == 1) && (case_ghash_evt_count == 0)) begin
                if (dbg_GHASH_block !== 128'h6749daeea367d0e9809e2dc2f309e6e3) begin
                    $error("CASE 2 first GHASH block mismatch. got=%032h expected=%032h",
                           dbg_GHASH_block, 128'h6749daeea367d0e9809e2dc2f309e6e3);
                end
            end

            $display("[%0t] GHASH_en = 1", $time);
            $display("    case           = %0d", current_case_idx + 1);
            $display("    ghash_evt_idx  = %0d", case_ghash_evt_count);
            $display("    dbg_byte_num    = %0d", dbg_byte_num);
            $display("    dbg_GHASH_block = %032h", dbg_GHASH_block);
            $display("    dbg_lenbit      = %032h", dbg_lenbit);
            case_ghash_evt_count <= case_ghash_evt_count + 1;
        end
    end

endmodule
