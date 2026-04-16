`timescale 1ns / 1ps

module tb_GHASH;

    logic         clk;
    logic         rst_n;
    logic         init;
    logic [127:0] GHASH_block;
    logic         GHASH_en;
    logic [127:0] H;
    logic         H_done;
    logic         busy;
    logic         done;
    logic [127:0] Y;

    localparam [127:0] GF_R = 128'he1000000000000000000000000000000;

    GHASH dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .init       (init),
        .GHASH_block(GHASH_block),
        .GHASH_en   (GHASH_en),
        .H          (H),
        .H_done     (H_done),
        .busy       (busy),
        .done       (done),
        .Y          (Y)
    );

    always #5 clk = ~clk;

    function automatic [127:0] gf128_mul;
        input [127:0] x;
        input [127:0] h;
        reg   [127:0] z;
        reg   [127:0] v;
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

    function automatic [127:0] ghash_step;
        input [127:0] y_prev;
        input [127:0] x_in;
        input [127:0] h_in;
    begin
        ghash_step = gf128_mul(y_prev ^ x_in, h_in);
    end
    endfunction

    task automatic pulse_h_done(input [127:0] h_in);
    begin
        @(posedge clk);
        H      <= h_in;
        H_done <= 1'b1;

        @(posedge clk);
        H_done <= 1'b0;
    end
    endtask

    task automatic pulse_init;
    begin
        @(posedge clk);
        init <= 1'b1;

        @(posedge clk);
        init <= 1'b0;
    end
    endtask

    task automatic push_block(input [127:0] blk_in);
        integer wait_cycles;
    begin
        @(posedge clk);
        GHASH_block <= blk_in;
        GHASH_en    <= 1'b1;

        @(posedge clk);
        GHASH_en <= 1'b0;

        wait_cycles = 0;
        while ((done !== 1'b1) && (wait_cycles < 300)) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end

        if (done !== 1'b1)
            $fatal(1, "GHASH block timeout.");
    end
    endtask

    initial begin
        logic [127:0] exp_y;

        clk         = 1'b0;
        rst_n       = 1'b0;
        init        = 1'b0;
        GHASH_block = 128'd0;
        GHASH_en    = 1'b0;
        H           = 128'd0;
        H_done      = 1'b0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        pulse_h_done(128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
        pulse_init();

        exp_y = ghash_step(128'd0, 128'hfeedfacedeadbeeffeedfacedeadbeef,
                           128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
        push_block(128'hfeedfacedeadbeeffeedfacedeadbeef);
        if (Y !== exp_y)
            $error("GHASH block 0 mismatch. got=%032h expected=%032h", Y, exp_y);

        exp_y = ghash_step(exp_y, 128'h42831ec2217774244b7221b784d0d49c,
                           128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
        push_block(128'h42831ec2217774244b7221b784d0d49c);
        if (Y !== exp_y)
            $error("GHASH block 1 mismatch. got=%032h expected=%032h", Y, exp_y);

        exp_y = ghash_step(exp_y, {64'd128, 64'd128},
                           128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
        push_block({64'd128, 64'd128});
        if (Y !== exp_y)
            $error("GHASH len block mismatch. got=%032h expected=%032h", Y, exp_y);

        pulse_h_done(128'hb83b533708bf535d0aa6e52980d53b78);
        pulse_init();

        exp_y = ghash_step(128'd0, 128'h00112233445566778899aabbccddeeff,
                           128'hb83b533708bf535d0aa6e52980d53b78);
        push_block(128'h00112233445566778899aabbccddeeff);
        if (Y !== exp_y)
            $error("Session 2 block 0 mismatch. got=%032h expected=%032h", Y, exp_y);

        exp_y = ghash_step(exp_y, 128'h102132435465768798a9babcbddcedfe,
                           128'hb83b533708bf535d0aa6e52980d53b78);
        push_block(128'h102132435465768798a9babcbddcedfe);
        if (Y !== exp_y)
            $error("Session 2 block 1 mismatch. got=%032h expected=%032h", Y, exp_y);

        $display("GHASH streaming testbench completed.");
        #20;
        $finish;
    end

endmodule
