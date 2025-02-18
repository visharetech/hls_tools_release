`include "vcap.vh"
import mru_pkg::*;

module mruCache#(
    parameter int AXI_LEN_W = 8,
    parameter int DW = 32,
    parameter int AW = 32,
    parameter int CACHE_BYTE = 16*1024,
    parameter int CACHE_WAY = 2,
    parameter int CACHE_WORD_BYTE = DW / 8,
    parameter int CACHE_LINE_LEN = 8,
    parameter int ROLLBACK = 1
)(
    input                           clk,
    input                           rstn,

    output                          ready,
    input                           user_re,
    input                           user_we,
    input  [CACHE_WORD_BYTE-1:0]    user_we_mask,
    input  [AW-1:0]                 user_adr,
    input  [DW-1:0]                 user_wdat,
    input                           csr_flush,
    output [DW-1:0]                 user_rdat,
    output                          user_rdat_vld,
    output                          rollback,

    // read address channel
    input                           axi4_ar_ready,
    output [AW-1:0]                 axi4_ar_addr,
    output                          axi4_ar_valid,
    output [AXI_LEN_W-1:0]          axi4_ar_len,

    // read data channel
    input                           axi4_r_last,
    input                           axi4_r_valid,
    input  [DW-1:0]                 axi4_r_data,
    output                          axi4_r_ready,

    // write address channel
    input                           axi4_aw_ready,
    output [AW-1:0]                 axi4_aw_addr,
    output                          axi4_aw_valid,
    output [AXI_LEN_W-1:0]          axi4_aw_len,

    // write data channel
    input                           axi4_w_ready,
    output [DW-1:0]                 axi4_w_data,
    output [DW/8-1:0]               axi4_w_strb,
    output                          axi4_w_valid,
    output                          axi4_w_last,

    // write response channel
    input                           axi4_b_valid,
    input                           axi4_b_resp,
    output                          axi4_b_ready
);

    localparam int WSTRB_W = DW / 8;
    localparam int LOG2_CACHE_WAY = $clog2(CACHE_WAY);
    localparam int CACHE_SET = (CACHE_BYTE/CACHE_WORD_BYTE/CACHE_LINE_LEN/CACHE_WAY);
    localparam int CACHE_TAG_BITS = AW-$clog2(CACHE_BYTE/CACHE_WAY);
    localparam int ADBITS = $clog2(CACHE_SET*CACHE_LINE_LEN);
    localparam int LOG2_CACHE_BYTE = $clog2(CACHE_BYTE);
    localparam int LOG2_CACHE_SET = $clog2(CACHE_SET);
    localparam int NLM_BYTE = 32; //256 bit
    localparam int DATA_ADR_W = LOG2_CACHE_BYTE - 2 - LOG2_CACHE_WAY;
    localparam int CACHE_INIT_NUM = CACHE_BYTE / (CACHE_WAY * CACHE_LINE_LEN * CACHE_WORD_BYTE);
    localparam int LOG2_CACHE_WORD_BYTE = $clog2(CACHE_WORD_BYTE);
    localparam int LOG2_CACHE_LINE_LEN = $clog2(CACHE_LINE_LEN);
    localparam int SET_NUM = (CACHE_BYTE / CACHE_LINE_LEN / CACHE_WORD_BYTE / CACHE_WAY);

    wire                        back_re;
    wire                        back_we;
    wire                        back_init;
    wire                        back_flush;
    wire [AW-1:0]               back_adr;
    wire [DW-1:0]               back_wdat;
    wire [DW-1:0]               back_rdat;

    wire [LOG2_CACHE_WAY-1:0]   back_inway;
    wire [LOG2_CACHE_WAY-1:0]   mru_replaceWay;
    wire                        mru_writeback;
    wire [AW-1:0]               mru_wb_byte_ptr, mru_refill_byte_ptr;
    wire                        mru_refill;
    wire [AW-1:0]               refill_set;
    wire                        back_resume;
    wire                        init_ready;

    speculative_mru #(
        .AXI_LEN_W          (AXI_LEN_W),
        .DW                 (DW),
        .AW                 (AW),
        .CACHE_BYTE         (CACHE_BYTE),
        .CACHE_WAY          (CACHE_WAY),
        .CACHE_WORD_BYTE    (CACHE_WORD_BYTE),
        .CACHE_LINE_LEN     (CACHE_LINE_LEN),
        .ROLLBACK           (ROLLBACK)
    )inst_mruHit (
        .clk                (clk),
        .rstn               (rstn),
        .ready              (ready),
        .user_re            (user_re),
        .user_we            (user_we),
        .user_we_mask       (user_we_mask),
        .user_adr           (user_adr),
        .user_wdat          (user_wdat),
        .user_rdat_o        (user_rdat),
        .user_rdat_vld_o    (user_rdat_vld),
        .back_re            (back_re),
        .back_we            (back_we),
        .back_init          (back_init),
        .back_flush         (csr_flush),
        .back_adr           (back_adr),
        .back_wdat          (back_wdat),
        .back_rdat          (back_rdat),
        .back_inway         (back_inway),
        .replaceWay         (mru_replaceWay),
        .writeback          (mru_writeback),
        .writeback_set      (mru_wb_byte_ptr),
        .refill             (mru_refill),
        .refill_set         (mru_refill_byte_ptr),
        .rollback           (rollback),//used for speculative_mru
        .resume             (back_resume)
    );

    backend #(
        .AXI_LEN_W          (AXI_LEN_W),
        .DW                 (DW),
        .AW                 (AW),
        .CACHE_BYTE         (CACHE_BYTE),
        .CACHE_WAY          (CACHE_WAY),
        .CACHE_WORD_BYTE    (CACHE_WORD_BYTE),
        .CACHE_LINE_LEN     (CACHE_LINE_LEN)
    )inst_backend (
        .clk                (clk),
        .rstn               (rstn),
        .init_done_pulse_r  (back_init),
        .writeback          (mru_writeback),
        .wb_byte_ptr        (mru_wb_byte_ptr),
        .refill             (mru_refill),
        .refill_byte_ptr    (mru_refill_byte_ptr),
        .replaceWay         (mru_replaceWay),
        .resume_r           (back_resume),
        .back_we_r          (back_we),
        .back_re_r          (back_re),
        .back_adr_r         (back_adr),
        .back_wdat_r        (back_wdat),
        .back_rdat          (back_rdat),
        .back_inway         (back_inway),
        .axi4_aw_addr       (axi4_aw_addr),
        .axi4_aw_valid      (axi4_aw_valid),
        .axi4_aw_ready      (axi4_aw_ready),
        .axi4_aw_len        (axi4_aw_len),
        .axi4_w_data        (axi4_w_data),
        .axi4_w_strb        (axi4_w_strb),
        .axi4_w_valid       (axi4_w_valid),
        .axi4_w_ready       (axi4_w_ready),
        .axi4_w_last        (axi4_w_last),
        .axi4_b_valid       (axi4_b_valid),
        .axi4_b_ready       (axi4_b_ready),
        .axi4_b_resp        (axi4_b_resp),
        .axi4_ar_addr       (axi4_ar_addr),
        .axi4_ar_valid      (axi4_ar_valid),
        .axi4_ar_ready      (axi4_ar_ready),
        .axi4_ar_len        (axi4_ar_len),
        .axi4_r_last        (axi4_r_last),
        .axi4_r_valid       (axi4_r_valid),
        .axi4_r_ready       (axi4_r_ready),
        .axi4_r_data        (axi4_r_data)
    );

endmodule