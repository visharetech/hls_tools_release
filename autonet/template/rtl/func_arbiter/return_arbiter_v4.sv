//Purpose: Request arbitration with a scalable archtecture to support
//    - large number of input request at high speed with two-level multiplexing
//     - minimum xmem latency by informing it about the scheduling decision before forwarding data
//     - Share storage among FIFO allocating for different destiation port using with linked-list FIFO
//        - select the pop FIFO only if the destination port is not busy

// iverilog -g2005-sv linked_fifo.sv callArb.sv & vvp a.out

/*
Pipelined architecture
stage 1:
    1a. Select a non-empty queue q0 to pop such that childRdy[q0]=1
    1b. Select a new call request
        - Divide parents equally into L1_GROUP groups so that each group can do local round robin arbitration with lower routing latencies; the local round arbitration for a group g is disabled if the last local buffered request is not forwarded yet, i.e. L1Vld_r[g]=1
        - Prestart xmem read in stage 1 if
            - there is any new call request
            - the destined child function of the new call request is ready
            - mqfifo is not dequeueing
Stage 2: If there is any dequeueing in the last cycle, i.e. deq_r=1, forward the buffered call request from mqfifo; else forward the new call request from L1 buffer. Furthermore, push the new call request at L1 buffer to mqfifo if it cannot be outputted yet

C0: if(callRdy_r==1), new request--> L1Buf
C1: if(callRdy_r==1 callVld_mux_w=1
C2: if(callRdy_r==0), callVld_mux --> mqFifo
C3: deq=1
C4: deq_r, callVld_mux_w=1
C5: callVld_mux=1
*/

import func_arbiter_pkg::*;
module return_arbiter#(
    parameter int PARENT = 4,
    parameter int CHILD = 4,
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
    output logic [FULL_RET_DW-1:0]          parent_retFifo_dout_o[PARENT]
);
    localparam bit [0:L1_GROUP-1][7:0]  CHILD_PER_GROUP = get_inst_per_group(CHILD, L1_GROUP);//CHILD / L1_GROUP;
    localparam bit [0:L1_GROUP-1][7:0]  START_CHILD_IDX = get_start_inst_idx(L1_GROUP, CHILD_PER_GROUP);
    localparam int MAX_CHILD_PER_GROUP = get_max_inst_per_group(L1_GROUP, CHILD_PER_GROUP);
    localparam int LOG_MAX_CHILD_PER_GROUP = $clog2(MAX_CHILD_PER_GROUP);
    localparam int LOG_L1_GROUP = $clog2(L1_GROUP);

    logic foundL1;
    logic [LOG_L1_GROUP-1:0] L1grp;
    logic [LOG_CHILD-1:0] local_c;
    logic [LOG_MAX_CHILD_PER_GROUP:0] r;
    logic [LOG_PARENT:0] q;
    logic [LOG_L1_GROUP:0] grp;
    logic [LOG_L1_GROUP-1:0] gsel, gsel_r;
    logic [LOG_CHILD:0] wptr_r[L1_GROUP], wptr[L1_GROUP];
    logic [LOG_L1_GROUP:0] grp_ptr_r, grp_ptr;
    logic [LOG_PARENT:0] rptr_r, rptr;
    logic [L1_GROUP-1:0] L1Vld, L1Vld_r;
    logic [LOG_CHILD-1:0] L1Child[L1_GROUP], L1Child_r[L1_GROUP];
    logic [LOG_PARENT-1:0] L1Parent[L1_GROUP], L1Parent_r[L1_GROUP];
    logic [RET_DW-1:0] L1RetVal[L1_GROUP], L1RetVal_r[L1_GROUP];

    logic [PARENT-1:0]          parent_retFifo_empty_n, parent_retFifo_empty_n_o_r;
    logic [FULL_RET_DW-1:0]     parent_retFifo_dout[PARENT];

    logic                      enqRdy_r;
    logic [PARENT-1:0]         deqVld_r;
    logic                      enq, enq_r, deq, deq_r;
    logic [LOG_PARENT-1:0]     qsel, qsel_r, qsel_r2;
    logic [LOG_PARENT-1:0]     enqid, enqid_r, deqid, deqid_r, deqid_r2;
    logic [FULL_RET_DW-1:0]    enqData, enqData_r;
    logic [FULL_RET_DW-1:0]    deqData;
    logic                      dataVld;

    logic [31:0]                    retDin_grp[L1_GROUP][MAX_CHILD_PER_GROUP];
    logic [MAX_CHILD_PER_GROUP-1:0] retVld_grp[L1_GROUP];
    logic [LOG_PARENT-1:0]          parentMod_grp[L1_GROUP][MAX_CHILD_PER_GROUP];

    //logic                            child_retRdy_w[CHILD];

    logic                   retVld_w[CHILD], retVld_r[CHILD];
    logic [31:0]            retDin_w[CHILD], retDin_r[CHILD];
    logic [LOG_PARENT-1:0]  parentMod_w[CHILD], parentMod_r[CHILD];
    logic                   clrRetVld[CHILD];

    logic [ROB_W-1:0]       robVld[PARENT];
    logic [ROB_W*RET_DW-1:0]robData[PARENT];


    linked_fifo #(
        .LEN        (16),
        .PAYLOAD    (FULL_RET_DW),
        .QNUM       (PARENT)
    ) mq_fifo (
        .rstn       (rstn),
        .clk        (clk),
        .revoke2    (1'b0),
        .enq        (enq_r),
        .deq        (deq_r),
        .enqid      (enqid_r),
        .deqid      (deqid_r),
        .enqData    (enqData_r),
        .enqRdy_r   (enqRdy_r),
        .deqVld_r   (deqVld_r),
        .deqData    (deqData),
        .dataVld    (dataVld)
    );

    //input buffer
    always_comb begin
        retDin_w = retDin_r;
        retVld_w = retVld_r;
        parentMod_w = parentMod_r;
        for (int c=0; c<CHILD; c++) begin
            child_retRdy_o[c] = ~retVld_r[c];
            if (~retVld_r[c] && child_retVld_i[c]) begin
                retDin_w[c] = child_retDin_i[c];
                parentMod_w[c] = child_parentMod_i[c];
                retVld_w[c] = 1;
            end
            else if (clrRetVld[c]) begin
                retVld_w[c] = 0;
            end
        end
    end

    always @ (posedge clk or negedge rstn) begin
        if(~rstn) begin
            retDin_r <= '{default: '0};
            retVld_r <= '{default: '0};
            parentMod_r <= '{default: '0};
        end
        else begin
            retDin_r <= retDin_w;
            retVld_r <= retVld_w;
            parentMod_r <= parentMod_w;
        end
    end

    always @(*) begin
        parent_retFifo_empty_n = parent_retFifo_empty_n_o;
        parent_retFifo_dout = parent_retFifo_dout_o;
        //child_retRdy_w = '{default: '0};
        {r, local_c} = 0;
        {gsel, rptr} = {gsel_r, rptr_r};
        wptr = wptr_r;
        grp_ptr = grp_ptr_r;

        L1Vld = L1Vld_r;
        L1Parent = L1Parent_r;
        L1Child = L1Child_r;
        L1RetVal = L1RetVal_r;

        {enq, enqid, enqData} = 0;
        {deq, deqid, qsel, q} = 0;

        if (dataVld) begin
            parent_retFifo_empty_n = 1 << qsel_r2;
            parent_retFifo_dout[qsel_r2] = deqData;
        end
        else if(L1Vld_r[gsel_r] && (parent_retFifo_empty_n_o==0)) begin
            parent_retFifo_empty_n = 1 << L1Parent_r[gsel_r];
            parent_retFifo_dout[L1Parent_r[gsel_r]] = {L1Child_r[gsel_r], L1RetVal_r[gsel_r]};
            L1Vld[gsel_r] = 0;
            //child_retRdy_o[L1Child_r[gsel_r]] = 1;
        end

        for (int p=0; p<PARENT; p++) begin
            if (parent_retFifo_empty_n_o[p] && parent_retFifo_pop_i[p]) begin
                parent_retFifo_empty_n[p] = 0;
            end
            else if ((parent_retFifo_empty_n_o[p] && parent_retFifo_empty_n_o_r[p]) ||
                     (dataVld && parent_retFifo_empty_n_o[p])) begin
                parent_retFifo_empty_n[p] = 0;
                enq = 1;
                enqid = p;
                enqData = parent_retFifo_dout_o[p];
            end
        end

        for (int p=0; p<PARENT; p++) begin
            q = rptr_r + p;
            if (q >= PARENT) begin
                q -= PARENT;
            end

            if (deqVld_r[q]) begin
                deq = 1;
                deqid = q;
                qsel = q;
            end
        end

        local_c = 0;
        retDin_grp = '{default: '0};
        retVld_grp = '{default: '0};
        parentMod_grp = '{default: '0};
        clrRetVld = '{default: '0};
        for(int g=0; g<L1_GROUP; g++) begin
            for(int c=0; c<MAX_CHILD_PER_GROUP; c++) begin
                if ((local_c<CHILD) && (c<CHILD_PER_GROUP[g])) begin
                    retDin_grp[g][c] = retDin_r[local_c];
                    retVld_grp[g][c] = retVld_r[local_c];
                    parentMod_grp[g][c] = parentMod_r[local_c];
                    local_c++;
                end
            end
        end

        for(int g = 0; g < L1_GROUP; g++) begin
            // Select parent based on wptr_r based on callVld
            for(int i=0; i<CHILD_PER_GROUP[g]; i++) begin
                r = i + wptr_r[g];
                if (r>=CHILD_PER_GROUP[g])
                    r -= CHILD_PER_GROUP[g];

                if (retVld_grp[g][r] && ~L1Vld_r[g]) begin
                    clrRetVld[START_CHILD_IDX[g] + r] = 1;
                    L1Vld[g] = 1; // Mark this group as valid
                    L1Parent[g] = parentMod_grp[g][r];
                    L1Child[g] = START_CHILD_IDX[g] + r;
                    L1RetVal[g] = retDin_grp[g][r];

                    wptr[g] = r + 1;
                    break;
                end
            end
        end

        foundL1 = 0;
        L1grp = 0;
        for(int i = L1_GROUP-1; i>=0 ; i--) begin
            grp = i + grp_ptr_r;
            if (grp>=L1_GROUP) begin
                grp -= L1_GROUP;
            end
            if (L1Vld[grp]) begin //#ron
                foundL1 = 1;
                L1grp = grp;
                gsel = L1grp;
                grp_ptr = grp + 1;
            end
        end
    end

    always @ (posedge clk or negedge rstn) begin
        if(~rstn) begin
            {enq_r, enqid_r, enqData_r} <= 0;
            {parent_retFifo_empty_n_o_r, parent_retFifo_empty_n_o} <= 0;
            parent_retFifo_dout_o <= '{default: 0};
            {grp_ptr_r, gsel_r, rptr_r, deq_r, deqid_r, qsel_r, qsel_r2} <= 0;
            wptr_r <= '{default: 0};
            for(int g=0; g<L1_GROUP; g++) begin
                {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1RetVal_r[g]} <= 0;
            end
            //child_retRdy_o <= '{default: '0};
        end
        else begin
            {enq_r, enqid_r, enqData_r} <= {enq, enqid, enqData};
            {parent_retFifo_empty_n_o_r, parent_retFifo_empty_n_o} <= {parent_retFifo_empty_n_o, parent_retFifo_empty_n};
            parent_retFifo_dout_o <= parent_retFifo_dout;
            {grp_ptr_r, gsel_r, rptr_r, deq_r, deqid_r, qsel_r, qsel_r2} <=
            {grp_ptr,   gsel,   rptr,   deq,   deqid,   qsel,   qsel_r};
            wptr_r <= wptr;
            for(int g=0; g<L1_GROUP; g++) begin
                {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1RetVal_r[g]} <=
                    {L1Vld[g], L1Parent[g], L1Child[g], L1RetVal[g]};
            end
            //child_retRdy_o <= child_retRdy_w;
        end
    end

endmodule
