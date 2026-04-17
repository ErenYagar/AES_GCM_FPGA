`timescale 1ns / 1ps

module GHASH (
    input          clk,
    input          rst_n,
    input          init,
    input  [127:0] GHASH_block,
    input          GHASH_en,
    input  [127:0] H,
    input          H_done,
    output         busy,
    output         done,
    output [127:0] Y
);

localparam [1:0] ST_IDLE = 2'd0;
localparam [1:0] ST_MUL  = 2'd1;

localparam [127:0] GF_R = 128'he1000000000000000000000000000000;

reg  [1:0]   state;
reg  [6:0]   bit_cnt;
reg          busy_r;
reg          done_r;

reg          h_valid;
reg  [127:0] h_reg;
reg  [127:0] y_reg;
reg  [127:0] x_work;
reg  [127:0] v_work;
reg  [127:0] z_work;

reg  [127:0] z_next;
reg  [127:0] v_next;

always @(*) begin
    if (x_work[127])
        z_next = z_work ^ v_work;
    else
        z_next = z_work;

    if (v_work[0])
        v_next = (v_work >> 1) ^ GF_R;
    else
        v_next = (v_work >> 1);
end

always @(posedge clk) begin
    if (!rst_n) begin
        state   <= ST_IDLE;
        bit_cnt <= 7'd0;
        busy_r  <= 1'b0;
        done_r  <= 1'b0;
        h_valid <= 1'b0;
        h_reg   <= 128'd0;
        y_reg   <= 128'd0;
        x_work  <= 128'd0;
        v_work  <= 128'd0;
        z_work  <= 128'd0;
    end
    else begin
        done_r <= 1'b0;

        if (H_done) begin
            h_reg   <= H;
            h_valid <= 1'b1;
        end

        if (init) begin
            y_reg <= 128'd0;
        end

        case (state)
            ST_IDLE: begin
                busy_r <= 1'b0;

                if (GHASH_en && h_valid) begin
                    busy_r  <= 1'b1;
                    bit_cnt <= 7'd127;
                    x_work  <= (init ? 128'd0 : y_reg) ^ GHASH_block;
                    v_work  <= H_done ? H : h_reg;
                    z_work  <= 128'd0;
                    state   <= ST_MUL;
                end
            end

            ST_MUL: begin
                busy_r <= 1'b1;

                if (bit_cnt == 7'd0) begin
                    y_reg  <= z_next;
                    busy_r <= 1'b0;
                    done_r <= 1'b1;
                    state  <= ST_IDLE;
                end
                else begin
                    z_work  <= z_next;
                    v_work  <= v_next;
                    x_work  <= {x_work[126:0], 1'b0};
                    bit_cnt <= bit_cnt - 7'd1;
                end
            end

            default: begin
                state <= ST_IDLE;
            end
        endcase
    end
end

assign busy = busy_r;
assign done = done_r;
assign Y    = y_reg;

endmodule
