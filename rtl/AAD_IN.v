`timescale 1ns / 1ps
module top (
    input         clk,
    input         rst,
    input  [7:0]  in,
    input         in_valid,
    input  [2:0]  in_type,
    input  [10:0] in_valid_bit,
    input         last,

    output [7:0]   out,
    output [127:0] dbg_GHASH_in,
    output [127:0] dbg_GHASH_block,
    output         dbg_GHASH_en,
    output [127:0] dbg_lenbit,
    output [7:0]   dbg_byte_num
);

reg  [127:0] GHASH_in;
reg  [127:0] GHASH_block;
reg  [63:0]  AADlen;
reg  [63:0]  CTlen;
reg  [7:0]   byte_num;
reg          GHASH_en;

wire [127:0] lenbit;
assign lenbit = {AADlen, CTlen};

assign out             = in;
assign dbg_GHASH_in    = GHASH_in;
assign dbg_GHASH_block = GHASH_block;
assign dbg_GHASH_en    = GHASH_en;
assign dbg_lenbit      = lenbit;
assign dbg_byte_num    = byte_num;

localparam TYPE_CT_DATA   = 3'd0;
localparam TYPE_AAD_DATA  = 3'd1;
localparam TYPE_CT_LEN    = 3'd2;
localparam TYPE_AAD_LEN   = 3'd3;
localparam TYPE_LEN_BLOCK = 3'd5;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        GHASH_in    <= 128'd0;
        GHASH_block <= 128'd0;
        AADlen      <= 64'd0;
        CTlen       <= 64'd0;
        byte_num    <= 8'd0;
        GHASH_en    <= 1'b0;
    end
    else begin
        GHASH_en <= 1'b0;

        if (in_valid) begin
            case (in_type)

                TYPE_AAD_LEN: begin
                    AADlen <= {53'd0, in_valid_bit};
                end

                TYPE_CT_LEN: begin
                    CTlen <= {53'd0, in_valid_bit};
                end

                TYPE_AAD_DATA,
                TYPE_CT_DATA: begin
                    if (last) begin
                        if (byte_num == 8'd15)
                            GHASH_block <= {GHASH_in[119:0], in};
                        else
                            GHASH_block <= ({GHASH_in[119:0], in} << ((16 - (byte_num + 8'd1)) * 8));

                        GHASH_en <= 1'b1;
                        GHASH_in <= 128'd0;
                        byte_num <= 8'd0;
                    end
                    else if (byte_num == 8'd15) begin
                        GHASH_block <= {GHASH_in[119:0], in};
                        GHASH_en    <= 1'b1;
                        GHASH_in    <= 128'd0;
                        byte_num    <= 8'd0;
                    end
                    else begin
                        GHASH_in <= {GHASH_in[119:0], in};
                        byte_num <= byte_num + 8'd1;
                    end
                end

                TYPE_LEN_BLOCK: begin
                    GHASH_block <= lenbit;
                    GHASH_en    <= 1'b1;
                end

                default: begin
                end
            endcase
        end
    end
end

endmodule