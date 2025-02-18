//`timescale 1ns / 1ps
package mru_pkg;
    // user defined param
    //localparam int AXI_LEN_W = 8;
    //localparam int DW = 32;
    //localparam int AW = 32;
//
    //localparam int CACHE_BYTE = 16*1024;
    //localparam int CACHE_WAY = 2;
    //localparam int CACHE_WORD_BYTE = DW / 8;
    //localparam int CACHE_LINE_LEN = 8;
    //localparam int M_CORES = 2;

    // derived param
    //localparam int WSTRB_W = DW / 8;
    //localparam int LOG2_CACHE_WAY = $clog2(CACHE_WAY);
    //localparam int CACHE_SET = (CACHE_BYTE/CACHE_WORD_BYTE/CACHE_LINE_LEN/CACHE_WAY);
    //localparam int CACHE_TAG_BITS = 32-$clog2(CACHE_BYTE/CACHE_WAY);
    //localparam int ADBITS = $clog2(CACHE_SET*CACHE_LINE_LEN);
    //localparam int LOG2_CACHE_BYTE = $clog2(CACHE_BYTE);
    //localparam int LOG2_CACHE_SET = $clog2(CACHE_SET);
    //localparam int NLM_BYTE = 32; //256 bit
    //localparam int DATA_ADR_W = LOG2_CACHE_BYTE - 2 - LOG2_CACHE_WAY;
    //localparam int CACHE_INIT_NUM = CACHE_BYTE / (CACHE_WAY * CACHE_LINE_LEN * CACHE_WORD_BYTE);
    //localparam int LOG2_CACHE_WORD_BYTE = $clog2(CACHE_WORD_BYTE);
    //localparam int LOG2_CACHE_LINE_LEN = $clog2(CACHE_LINE_LEN);
    //localparam int LOG2_M_CORES = $clog2(M_CORES);
//
    //localparam int SET_NUM = (CACHE_BYTE / CACHE_LINE_LEN / CACHE_WORD_BYTE / CACHE_WAY);

    typedef enum logic [1:0]
    {
        MESI_STATE_INVALID     = 'd0,
        MESI_STATE_MODIFIED    = 'd1,
        MESI_STATE_EXCLUSIVE   = 'd2,
        MESI_STATE_SHARED      = 'd3
    } mesi_state_t;

    typedef enum logic [1:0]
    {
        MESI_REQ_NULL                = 'd0,
        MESI_REQ_HANDLE_WRITE_SHARE  = 'd1,
        MESI_REQ_HANDLE_WRITE_MISS   = 'd2,
        MESI_REQ_HANDLE_READ_MISS    = 'd3
    } mesi_req_t;

    typedef enum logic [1:0]
    {
        MESI_ACT_NULL    = 'd0,
        MESI_ACT_REFILL  = 'd1,
        MESI_ACT_FORWARD = 'd2,
        MESI_ACT_REVOKE  = 'd3
    } mesi_action_t;

endpackage