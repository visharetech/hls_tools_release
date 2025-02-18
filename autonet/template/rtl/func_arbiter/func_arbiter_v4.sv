

/*
Change log:
29/08/2024 - Vyacheslav
    - fixed the return arb issue repored by Edward: "In waveform, child 9 set retVld and parentMod=1.
    But, why the ref_fifo_empty_n[0]=1? It is should be ret_fifo_empty_n[1]=1?"
    - renamed the IO ports, added prefix parent/child and suffix i/o
    - parameters PARENT, CHILD, CMD_FIFO_DW has been moved from package to module parameters list.
    Other parameters depending from PARENT and CHILD are also moved from package and declared as
    localparam
*/

import func_arbiter_pkg::*;
module func_arbiter#(
    parameter int PARENT = 32,
    parameter int CHILD = 64,
    parameter int CMD_FIFO_DW = ARG_W*ARG_NUM + $clog2(CHILD)+ 1 + 32,
    parameter int LOG_PARENT = (PARENT==1) ? 1 : $clog2(PARENT),
    parameter int LOG_CHILD = (CHILD==1) ? 1 : $clog2(CHILD)
)(
    input                                   rstn,
    input                                   clk,

    input        [CMD_FIFO_DW-1:0]          parent_cmdfifo_din_i[PARENT],
    output                                  parent_cmdfifo_full_n_o[PARENT],
    input                                   parent_cmdfifo_write_i[PARENT],

    output logic [CHILD-1:0]                child_ap_ce_o,
    input        [CHILD-1:0]                child_ap_done_i,
    output                                  child_retReq_o,
    input                                   child_rdy_i[CHILD],
    output logic [CHILD-1:0]                child_callVld_o,
    output       [LOG_PARENT-1:0]           child_parent_o,
    output       [ARG_W-1:0]                child_pc_o,
    output       [ARG_NUM*ARG_W-1:0]        child_args_o,
    output logic                            xmemStart,
    output logic [LOG_CHILD-1:0]            xmemStartFunc,
    output                                  xmemCancel_p1,
    output                                  xmemCancel_p2,

    output                                  child_retRdy_o[CHILD],
    input                                   child_retVld_i[CHILD],
    input        [31:0]                     child_retDin_i[CHILD],
    input        [LOG_PARENT-1:0]           child_parentMod_i[CHILD],

    input        [PARENT-1:0]               parent_retFifo_pop_i,
    output logic [PARENT-1:0]               parent_retFifo_empty_n_o,
    output       [RET_DW+LOG_CHILD-1:0]     parent_retFifo_dout_o[PARENT]
);
    localparam int FULL_RET_DW = RET_DW + LOG_CHILD;

    logic                               callVld_mux;
    logic [LOG_CHILD-1:0]               callChild_mux;
    logic [CHILD-1:0]                   child_ap_ce_r;
    logic [CHILD-1:0]                   child_ap_done_r;
    logic [CALL_SEQ_W-1:0]              storeSeq[CHILD];

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
    end

    call_arbiter #(
        .PARENT     (PARENT),
        .CHILD      (CHILD),
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
        .parentIdx_r                (child_parent_o),
        .callVld_mux                (callVld_mux),
        .callChild_mux              (callChild_mux),
        .returnReq_o                (child_retReq_o),
        .pc_o                       (child_pc_o),
        .callArgs_mux               (child_args_o),
        .storeSeq                   (storeSeq)
    );

    return_arbiter #(
        .PARENT         (PARENT),
        .CHILD          (CHILD),
        .LOG_PARENT     (LOG_PARENT),
        .LOG_CHILD      (LOG_CHILD),
        .FULL_RET_DW    (FULL_RET_DW)
    ) ret_arb (
        .rstn                       (rstn),
        .clk                        (clk),
        .storeSeq                   (storeSeq),
        .child_retRdy_o             (child_retRdy_o),
        .child_retVld_i             (child_retVld_i),
        .child_retDin_i             (child_retDin_i),
        .child_parentMod_i          (child_parentMod_i),
        .parent_retFifo_pop_i       (parent_retFifo_pop_i),
        .parent_retFifo_empty_n_o   (parent_retFifo_empty_n_o),
        .parent_retFifo_dout_o      (parent_retFifo_dout_o)
    );

endmodule

