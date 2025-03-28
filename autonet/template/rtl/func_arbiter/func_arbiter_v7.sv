

/*
Change log:
29/08/2024 - Vyacheslav
    - fixed the return arb issue repored by Edward: "In waveform, child 9 set retVld and parentMod=1.
    But, why the ref_fifo_empty_n[0]=1? It is should be ret_fifo_empty_n[1]=1?"
    - renamed the IO ports, added prefix parent/child and suffix i/o
    - parameters PARENT, CHILD, CMD_FIFO_DW has been moved from package to module parameters list.
    Other parameters depending from PARENT and CHILD are also moved from package and declared as
    localparam
21/02/2025 - Vyacheslav
    - added threads for parent and child ports
06/03/2025: 
    - return_arbiter (v8) to maintain return sequence to parent. There are two arugments to control return sequence:
        1. retMode (FIFO or LIFO): To select return order is FIFO or LIFO.
        2. callSeq: It will be outputted to child. Andm, child will return back callSeq after done.
    - call_arbiter (v7)
        1. Use 2-bits returnReq.
           bit 0: request return that is same as before.
           bit 1: return mode (1:FIFO mode 0:LIFO mode)
        2. Output callSeq. If FIFO mode, increase callSeq. Otherwise, keep the current value.
    - Return arbiter will aslo return thread to parent.
*/

import func_arbiter_pkg::*;
module func_arbiter#(
    parameter int THREAD = 16,
    parameter int PARENT = 32,
    parameter int CHILD = 64,
    parameter int SEQBUF = 4,
    parameter int SEQ = 2 * SEQBUF,
    parameter int LOG_THREAD = (THREAD==1) ? 1 : $clog2(THREAD),
    parameter int LOG_PARENT = (PARENT==1) ? 1 : $clog2(PARENT),
    parameter int LOG_CHILD = (CHILD==1) ? 1 : $clog2(CHILD),
    parameter int LOG_SEQ = $clog2(SEQ),
    parameter int LOG_SEQBUF = $clog2(SEQBUF),
    parameter int CMD_FIFO_DW = ARG_W*ARG_NUM + LOG_THREAD + LOG_CHILD + 2 + 32,
    parameter int FULL_RET_DW = RET_DW + LOG_CHILD + LOG_THREAD
)(
    input                                   rstn,
    input                                   clk,
    output logic [THREAD-1:0]               return_error_o,

    input        [CMD_FIFO_DW-1:0]          parent_cmdfifo_din_i[PARENT],
    output                                  parent_cmdfifo_full_n_o[PARENT],
    input                                   parent_cmdfifo_write_i[PARENT],

    output logic [CHILD-1:0]                child_ap_ce_o,
    input        [CHILD-1:0]                child_ap_done_i,
    output       [1:0]                      child_retReq_o,
    input                                   child_rdy_i[CHILD],
    output logic [CHILD-1:0]                child_callVld_o,
    output       [LOG_THREAD-1:0]           child_thread_o,
    output       [LOG_PARENT-1:0]           child_parent_o,
    output       [ARG_W-1:0]                child_pc_o,
    output       [ARG_NUM*ARG_W-1:0]        child_args_o,
    output       [LOG_SEQ-1:0]              child_callSeq_o,
    output logic                            xmemStart,
    output logic [LOG_CHILD-1:0]            xmemStartFunc,
    output                                  xmemCancel_p1,
    output                                  xmemCancel_p2,

    output                                  child_retRdy_o[CHILD],
    input                                   child_retVld_i[CHILD],
    input        [31:0]                     child_retDin_i[CHILD],
    input        [LOG_THREAD-1:0]           child_retThread_i[CHILD],
    input        [LOG_PARENT-1:0]           child_parentMod_i[CHILD],
    input        [LOG_SEQ-1:0]              child_retSeq_i[CHILD],
    input                                   child_retMode_i[CHILD],

    input        [PARENT-1:0]               parent_retFifo_pop_i,
    output logic [PARENT-1:0]               parent_retFifo_empty_n_o,
    output logic [FULL_RET_DW-1:0]          parent_retFifo_dout_o[PARENT]
);

    logic                               callVld_mux;
    logic [LOG_CHILD-1:0]               callChild_mux;
    logic [CHILD-1:0]                   child_ap_ce_r;
    logic [CHILD-1:0]                   child_ap_done_r;
    logic [LOG_THREAD-1:0]              parentThread_o[PARENT];
    logic [LOG_CHILD-1:0]               parentChild_o[PARENT];
    logic [RET_DW-1:0]                  parentResult_o[PARENT];

    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            child_ap_ce_r <= 0;
            child_ap_done_r <= 0;
        end
        else begin
            child_ap_ce_r <= child_ap_ce_o;
            child_ap_done_r <= child_ap_done_i;
        end
    end

    always_comb begin
        child_callVld_o = callVld_mux << callChild_mux;
        child_ap_ce_o = child_ap_ce_r;
        for (int c=0; c<CHILD; c++) begin
            if (child_callVld_o[c]) begin
                child_ap_ce_o[c] = 1;
            end
            else if (child_ap_done_r[c]) begin
                child_ap_ce_o[c] = 0;
            end
        end
        for (int p=0; p<PARENT; p++) begin
            parent_retFifo_dout_o[p] = {parentThread_o[p],parentChild_o[p],parentResult_o[p]};
        end
    end

    call_arbiter #(
        .THREAD     (THREAD),
        .PARENT     (PARENT),
        .CHILD      (CHILD),
        .CALL_SEQ_W (LOG_SEQ),
        .LOG_THREAD (LOG_THREAD),
        .LOG_PARENT (LOG_PARENT),
        .LOG_CHILD  (LOG_CHILD)
    ) call_arb (
        .rstn                       (rstn),
        .clk                        (clk),
        .callParam_i                (parent_cmdfifo_din_i),
        .callRdy_o                  (parent_cmdfifo_full_n_o),
        .callVld_i                  (parent_cmdfifo_write_i),
        .childRdy                   (child_rdy_i),
        .xmemStart                  (xmemStart),
        .xmemCancel_p1              (xmemCancel_p1),
        .xmemCancel_p2              (xmemCancel_p2),
        .xmemStartFunc              (xmemStartFunc),
        .thread_r                   (child_thread_o),
        .parentIdx_r                (child_parent_o),
        .callVld_mux                (callVld_mux),
        .callChild_mux              (callChild_mux),
        .returnReq_o                (child_retReq_o),
        .pc_o                       (child_pc_o),
        .callArgs_mux               (child_args_o),
        .callSeq_o                  (child_callSeq_o)
    );

    return_arbiter #(
        .THREAD         (THREAD),
        .SEQBUF         (SEQBUF),
        .DATA           (RET_DW),
        .PARENT         (PARENT),
        .CHILD          (CHILD),
        .SEQ            (SEQ),
        .LOG_THREAD     (LOG_THREAD),
        .LOG_SEQ        (LOG_SEQ),
        .LOG_SEQBUF     (LOG_SEQBUF),
        .LOG_PARENT     (LOG_PARENT),
        .LOG_CHILD      (LOG_CHILD)
    ) ret_arb (
        .rstn             (rstn),
        .clk              (clk),
        .return_error_o   (return_error_o),
        .childRetRdy_o    (child_retRdy_o),
        .childRet_i       (child_retVld_i),
        .childResult_i    (child_retDin_i),
        .childThread_i    (child_retThread_i),
        .childRetParent_i (child_parentMod_i),
        .childSeq_i       (child_retSeq_i),
        .childMode_i      (child_retMode_i),
        .parentPop_i      (parent_retFifo_pop_i),
        .parentPopRdy_o   (parent_retFifo_empty_n_o),
        .parentThread_o   (parentThread_o),
        .parentChild_o    (parentChild_o),
        .parentResult_o   (parentResult_o)
    );

endmodule

