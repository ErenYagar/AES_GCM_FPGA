`timescale 1ns / 1ps

module tb_GHASH;

    logic          clk;
    logic          rst_n;
    logic [127:0] GHASH_block;
    logic         GHASH_en;
    
    logic [127:0] H;
    logic          H_done;
    logic         busy;
    logic         done;
    logic [127:0] Y;
    
    logic [127:0] exp_block_y;
    integer       block_seen;

    localparam [127:0] GF_R = 128'he1000000000000000000000000000000;
    
    
    ///tb/g0/H 61f4a8f56754c7437513e305fefd7777
     // /tb/key   92e11dcdaa866f5ce790fd24501f92509aacf4cb8b1339d50c9c1240935dd08b

    GHASH dut (
        .clk   (clk),
        .rst_n (rst_n),
        .start (start),
        .A     (A),
        .C     (C),
        .H     (H),
        .H_done(H_done),
        .busy  (busy),
        .done  (done),
        .Y     (Y)
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

    function automatic [127:0] ghash_ref;
        input [127:0] a_in;
        input [127:0] c_in;
        input [127:0] h_in;
        reg   [127:0] y0;
        reg   [127:0] y1;
        reg   [127:0] y2;
    begin
        y0 = gf128_mul(a_in, h_in);
        y1 = gf128_mul(y0 ^ c_in, h_in);
        y2 = gf128_mul(y1 ^ {64'd128, 64'd128}, h_in);
        ghash_ref = y2;
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

    task automatic pulse_start(
        input [127:0] a_in,
        input [127:0] c_in
    );
    begin
        @(posedge clk);
        A     <= a_in;
        C     <= c_in;
        start <= 1'b1;

        @(posedge clk);
        start <= 1'b0;
    end
    endtask

    initial begin
        logic [127:0] exp_y_0;
        logic [127:0] exp_y_1;

        clk    = 1'b0;
        rst_n  = 1'b0;
        start  = 1'b0;

        H      = 128'd61f4a8f56754c7437513e305fefd7777;
        H_done = 1'b0;
        exp_block_y = 128'd0;
        block_seen  = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        exp_y_0 = ghash_ref(
            128'hfeedfacedeadbeeffeedfacedeadbeef,
            128'h42831ec2217774244b7221b784d0d49c,
            128'h66e94bd4ef8a2c3b884cfa59ca342b2e
        );

        pulse_h_done(128'h66e94bd4ef8a2c3b884cfa59ca342b2e);
        pulse_start(
            128'hfeedfacedeadbeeffeedfacedeadbeef,
            128'h42831ec2217774244b7221b784d0d49c
        );

        wait(done);
        @(posedge clk);
        if (Y !== exp_y_0) begin
            $error("GHASH mismatch when H_done happens before start. got=%032h expected=%032h",
                   Y, exp_y_0);
        end

        exp_y_1 = ghash_ref(
            128'h00112233445566778899aabbccddeeff,
            128'h102132435465768798a9babcbddcedfe,
            128'hb83b533708bf535d0aa6e52980d53b78
        );

        pulse_start(
            128'h00112233445566778899aabbccddeeff,
            128'h102132435465768798a9babcbddcedfe
        );
        pulse_h_done(128'hb83b533708bf535d0aa6e52980d53b78);

        wait(done);
        @(posedge clk);
        if (Y !== exp_y_1) begin
            $error("GHASH mismatch when start happens before H_done. got=%032h expected=%032h",
                   Y, exp_y_1);
        end

        $display("GHASH testbench completed.");
        #20;
        $finish;
    end

    always @(posedge clk) begin
        reg [127:0] expected_step;

        if (!rst_n) begin
            block_seen  <= 0;
            exp_block_y <= 128'd0;
        end
        else begin
            if (start) begin
                block_seen  <= 0;
                exp_block_y <= 128'd0;
                $display("[%0t] start GHASH", $time);
            end

            if ((dut.state == dut.ST_MUL) && (dut.bit_cnt == 7'd0)) begin
                case (block_seen)
                    0: begin
                        expected_step = ghash_step(128'd0, A, H);
                        if (dut.z_next !== expected_step) begin
                            $error("Block 0 mismatch. got=%032h expected=%032h",
                                   dut.z_next, expected_step);
                        end
                        $display("[%0t] block 0 A      Y = %032h", $time, dut.z_next);
                    end
                    1: begin
                        expected_step = ghash_step(exp_block_y, C, H);
                        if (dut.z_next !== expected_step) begin
                            $error("Block 1 mismatch. got=%032h expected=%032h",
                                   dut.z_next, expected_step);
                        end
                        $display("[%0t] block 1 C      Y = %032h", $time, dut.z_next);
                    end
                    default: begin
                        expected_step = ghash_step(exp_block_y, {64'd128, 64'd128}, H);
                        if (dut.z_next !== expected_step) begin
                            $error("Block 2 len mismatch. got=%032h expected=%032h",
                                   dut.z_next, expected_step);
                        end
                        $display("[%0t] block 2 LEN    Y = %032h", $time, dut.z_next);
                    end
                endcase

                exp_block_y <= expected_step;
                block_seen  <= block_seen + 1;
            end

            if ((dut.state == dut.ST_DONE) && done) begin
                $display("[%0t] final Y   = %032h", $time, Y);
            end
        end
    end

endmodule