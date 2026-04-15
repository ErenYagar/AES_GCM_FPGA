`timescale 1ns / 1ps

module GHASH (
    input          clk,
    input          rst_n,
    input [127:0] GHASH_block,
    input         GHASH_en,
    
    input [127:0] H,
    input          H_done,
    output         busy,
    output         done,
    output [127:0] Y
);

localparam [2:0] ST_IDLE   = 3'd0;
localparam [2:0] ST_WAIT_H = 3'd1;
localparam [2:0] ST_LOAD   = 3'd2;
localparam [2:0] ST_MUL    = 3'd3;
localparam [2:0] ST_DONE   = 3'd4;

localparam [127:0] GF_R          = 128'he1000000000000000000000000000000;
localparam [63:0]  LEN_A_BITS    = 64'd128;
localparam [63:0]  LEN_C_BITS    = 64'd128;
localparam [127:0] LEN_AC_CONCAT = {LEN_A_BITS, LEN_C_BITS};

reg  [2:0]   state;
reg  [1:0]   block_idx;
reg  [6:0]   bit_cnt;
reg          busy_r;
reg          done_r;

reg          h_valid;
reg  [127:0] h_shadow;
reg  [127:0] h_active;
reg  [127:0] a_reg;
reg  [127:0] c_reg;

reg  [127:0] y_reg;
reg  [127:0] x_work;
reg  [127:0] v_work;
reg  [127:0] z_work;

reg  [127:0] x_block;
reg  [127:0] z_next;
reg  [127:0] v_next;

always @(*) begin
    case (block_idx)
        2'd0: x_block = a_reg;
        2'd1: x_block = c_reg;
        default: x_block = LEN_AC_CONCAT;
    endcase
end

always @(*) begin
    z_next = z_work;
    if (x_work[127])
        z_next = z_work ^ v_work;

    if (v_work[0])
        v_next = (v_work >> 1) ^ GF_R;
    else
        v_next = (v_work >> 1);
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state        <= ST_IDLE;
        block_idx    <= 2'd0;
        bit_cnt      <= 7'd0;
        busy_r       <= 1'b0;
        done_r       <= 1'b0;
        h_valid      <= 1'b0;
        h_shadow     <= 128'd0;
        h_active     <= 128'd0;
        a_reg        <= 128'd0;
        c_reg        <= 128'd0;
        y_reg        <= 128'd0;
        x_work       <= 128'd0;
        v_work       <= 128'd0;
        z_work       <= 128'd0;
    end
    else begin
        done_r <= 1'b0;

        // GHASH uses H = AES_K(0^128), which should be produced by AES first.
        // This core consumes one H value per GHASH operation.
        if (H_done) begin
            h_shadow <= H;
            h_valid  <= 1'b1;
        end

        case (state)
            ST_IDLE: begin
                busy_r <= 1'b0;

                if (start) begin
                    a_reg     <= A;
                    c_reg     <= C;
                    y_reg     <= 128'd0;
                    block_idx <= 2'd0;
                    busy_r    <= 1'b1;

                    if (H_done) begin
                        h_active <= H;
                        h_valid  <= 1'b0;
                        state    <= ST_LOAD;
                    end
                    else if (h_valid) begin
                        h_active <= h_shadow;
                        h_valid  <= 1'b0;
                        state    <= ST_LOAD;
                    end
                    else begin
                        state <= ST_WAIT_H;
                    end
                end
            end

            ST_WAIT_H: begin
                busy_r <= 1'b1;

                if (H_done) begin
                    h_active <= H;
                    h_valid  <= 1'b0;
                    state    <= ST_LOAD;
                end
            end

            ST_LOAD: begin
                busy_r <= 1'b1;
                x_work <= y_reg ^ x_block;
                v_work <= h_active;
                z_work <= 128'd0;
                bit_cnt <= 7'd127;
                state  <= ST_MUL;
            end

            ST_MUL: begin
                busy_r <= 1'b1;

                if (bit_cnt == 7'd0) begin
                    y_reg <= z_next;

                    if (block_idx == 2'd2) begin
                        state <= ST_DONE;
                    end
                    else begin
                        block_idx <= block_idx + 2'd1;
                        state     <= ST_LOAD;
                    end
                end
                else begin
                    z_work  <= z_next;
                    v_work  <= v_next;
                    x_work  <= {x_work[126:0], 1'b0};
                    bit_cnt <= bit_cnt - 7'd1;
                end
            end

            ST_DONE: begin
                busy_r <= 1'b0;
                done_r <= 1'b1;
                state  <= ST_IDLE;
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