
/*
    - In order to preserve in-order function return: the parent should attaches a call seqeunce for each child call and use reorder buffer (ROB) to store out-of-order results.
        - Given
            - Parent: callSeq[PARENT], popSeq[PARENT], [SEQ-1:0] robVld[PARENT]; logic [RET_DW*SEQ-1:0] robData[PARENT] and
            - Child: storeSeq[CHILD]
        - for each function call from p to c,
            at child: storeSeq[c] = callSeq[p];
            at parent: callSeq[p]++;
        - for each child c which just finishes execution and returns results to the parent p,
            robVld[p][storeSeq[c]] = 1
            robData[p][storeSeq[c]] = child_retDin_i[c]
        - for each parent p fetching the next return results,
            if (robVld[p][popSeq[p]] )
                pop from robData[p][popSeq[p]] and clear robVld[p][popSeq[p]] = 0;

1. P0 calls C0 => callSeq[0] = 1 => storeSeq[0]=callSeq[0]=1
2. P0 calls C1 => callSeq[0] = 2 => storeSeq[1]=callSeq[0]=2
3. P1 calls C2 => callSeq[1] = 1 => storeSeq[2]=callSeq[1]=1
4. C1 return to P0 => robVld[0][2]=1
5. C0 return to P0 => robVld[0][1]=1
6. C2 return to P1 => robVld[1][1]=1

*/

import func_arbiter_pkg::*;
module return_arbiter#(
    parameter int PARENT = 32,
    parameter int CHILD = 64,
    parameter int LOG_PARENT = (PARENT==1) ? 1 : $clog2(PARENT),
    parameter int LOG_CHILD = (CHILD==1) ? 1 : $clog2(PARENT),
    parameter int FULL_RET_DW = RET_DW + LOG_CHILD
) (
    input                                   rstn,
    input                                   clk,

    input        [CALL_SEQ_W-1:0]           storeSeq[CHILD],

    output logic                            child_retRdy_o[CHILD],
    input                                   child_retVld_i[CHILD],
    input        [31:0]                     child_retDin_i[CHILD],
    input        [LOG_PARENT-1:0]           child_parentMod_i[CHILD],

    input        [PARENT-1:0]               parent_retFifo_pop_i,
    output logic [PARENT-1:0]               parent_retFifo_empty_n_o,
    output logic [FULL_RET_DW-1:0]          parent_retFifo_dout_o
);
    localparam bit [0:L1_GROUP-1][7:0]  CHILD_PER_GROUP = get_inst_per_group(CHILD, L1_GROUP);//CHILD / L1_GROUP;
    localparam bit [0:L1_GROUP-1][7:0]  START_CHILD_IDX = get_start_inst_idx(L1_GROUP, CHILD_PER_GROUP);
    localparam int MAX_CHILD_PER_GROUP = get_max_inst_per_group(L1_GROUP, CHILD_PER_GROUP);
    localparam int LOG_MAX_CHILD_PER_GROUP = $clog2(MAX_CHILD_PER_GROUP);
    localparam int LOG_L1_GROUP = $clog2(L1_GROUP);

    logic [PARENT-1:0]              parent_retFifo_empty_n, parent_retFifo_empty_n_o_r;
    logic [FULL_RET_DW-1:0]         parent_retFifo_dout;

    logic [ROB_W-1:0]               robVld[PARENT], robVld_r[PARENT];
    logic [ROB_W*FULL_RET_DW-1:0]   robData[PARENT], robData_r[PARENT];
    logic [LOG_PARENT-1:0]          cur_parent;
    logic [CALL_SEQ_W-1:0]          popSeq[PARENT], popSeq_r[PARENT];

    //input buffer
    always_comb begin
        robVld = robVld_r;
        robData = robData_r;
        for (int c=0; c<CHILD; c++) begin
            cur_parent = child_parentMod_i[c];
            child_retRdy_o[c] = ~robVld_r[cur_parent][storeSeq[c]];
            if (child_retVld_i[c] && child_retRdy_o[c]) begin
                robVld[cur_parent][storeSeq[c]] = 1;
                robData[cur_parent][storeSeq[c]*FULL_RET_DW +: FULL_RET_DW] = {c, child_retDin_i[c]};
            end
        end

        popSeq = popSeq_r;
        parent_retFifo_empty_n = parent_retFifo_empty_n_o;
        parent_retFifo_dout = parent_retFifo_dout_o;
        for (int p=0; p<PARENT; p++) begin
            if (robVld_r[p][popSeq_r[p]]) begin
                parent_retFifo_empty_n[p] = 1;
                parent_retFifo_dout = robData_r[p][popSeq_r[p]*FULL_RET_DW +: FULL_RET_DW];
                break;
            end
        end

        for (int p=0; p<PARENT; p++) begin
            if (parent_retFifo_empty_n_o[p] && parent_retFifo_pop_i[p]) begin
                parent_retFifo_empty_n[p] = 0;
                robVld[p][popSeq_r[p]] = 0;
                popSeq[p] = popSeq_r[p] + 1;
            end
        end
    end

    always @ (posedge clk or negedge rstn) begin
        if(~rstn) begin
            robVld_r <= '{default: '0};
            robData_r <= '{default: '0};
            parent_retFifo_empty_n_o <= 0;
            parent_retFifo_dout_o <= '{default: 0};
            popSeq_r <= '{default: '0};
        end
        else begin
            robVld_r <= robVld;
            robData_r <= robData;
            parent_retFifo_empty_n_o <= parent_retFifo_empty_n;
            parent_retFifo_dout_o <= parent_retFifo_dout;
            popSeq_r <= popSeq;
        end
    end

endmodule
