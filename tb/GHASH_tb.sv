`timescale 1ns / 1ps

module tb_GHASH;

    logic         clk;
    logic         rst;
    logic         init;
    logic         en;
    logic [127:0] H;
    logic [127:0] X;
    logic [127:0] Y;
    logic         Y_valid;

    GHASH dut (
        .clk    (clk),
        .rst    (rst),
        .init   (init),
        .en     (en),
        .H      (H),
        .X      (X),
        .Y      (Y),
        .Y_valid(Y_valid)
    );

    always #5 clk = ~clk;

    task automatic drive_block(
        input logic [127:0] h_in,
        input logic [127:0] x_in
    );
    begin
        @(posedge clk);
        H    <= h_in;
        X    <= x_in;
        en   <= 1'b1;
        init <= 1'b0;

        @(posedge clk);
        en <= 1'b0;
        X  <= 128'd0;
    end
    endtask

    initial begin
        clk  = 1'b0;
        rst  = 1'b0;
        init = 1'b0;
        en   = 1'b0;
        H    = 128'd0;
        X    = 128'd0;

        repeat (2) @(posedge clk);
        rst = 1'b1;

        @(posedge clk);
        init <= 1'b1;
        @(posedge clk);
        init <= 1'b0;

        if (Y !== 128'd0) begin
            $error("Init should clear GHASH state. got=%032h", Y);
        end

        drive_block(
            128'h66e94bd4ef8a2c3b884cfa59ca342b2e,
            128'h0388dace60b6a392f328c2b971b2fe78
        );

        if (!Y_valid) begin
            $error("Y_valid should pulse when en is asserted.");
        end

        if (Y !== 128'h5e2ec746917062882c85b0685353deb7) begin
            $error("Known GHASH vector mismatch. got=%032h expected=%032h",
                   Y, 128'h5e2ec746917062882c85b0685353deb7);
        end

        @(posedge clk);
        init <= 1'b1;
        @(posedge clk);
        init <= 1'b0;

        drive_block(
            128'h00000000000000000000000000000000,
            128'h1234567890abcdef1234567890abcdef
        );

        if (Y !== 128'd0) begin
            $error("H=0 must force GHASH result to 0. got=%032h", Y);
        end

        @(posedge clk);
        if (Y_valid) begin
            $error("Y_valid should be a one-cycle pulse.");
        end

        $display("GHASH testbench completed.");
        #20;
        $finish;
    end

endmodule
