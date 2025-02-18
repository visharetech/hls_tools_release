//Purpose: Request arbitration with a scalable archtecture to support
//    - large number of input request at high speed with two-level multiplexing
//     - minimum xmem latency by informing it about the scheduling decision before forwarding data
//     - Share storage among FIFO allocating for different destiation port using with linked-list FIFO
//        - select the pop FIFO only if the destination port is not busy

// iverilog -g2005-sv linked_fifo.sv callArb.sv & vvp a.out

/*
Pipelined architecture
Dequeue pipeline stages
D1:
	if (~revoke2) {deq, deqi}
D2:
	{deq_r->deq_masked, deqid_r} --> fifo input
D3:
	if (dataVld)
		try to output buffered request at D3 --> call{*}_mux_w
		xmemStart = 1
		D3=1

D4:
	if (D3 && ~childRdy[callChild_mux]) begin
		revoke2 = 1;
        xmemCancel_p1 = 1;



Enqueue pipeline stages
E1:
if (~enqStall)
    - for each group
        if (callVld_r[local_p])
            - buffer new request in L1 buffer
    - check
        - L2Request = 1 if at least one L1Vld[gsel_r]=1
            - L1Vld[gsel_r] = 0;
        - mpfifo_almost_full; before sending L2 request, need to make sure there is buffer space for L2_request to be buffered since the target child may become not ready in the some encode pipeline stage
    - if L2Reqeust && ~mpfifo_almost_full
        - E1=1
        - if (L2_request is ready to output) begin  //#Nov9 Add
            xmemStart = 1;

E2:
    if (E1_r) begin
        E2=1
        try to output L2Request at E3 --> call{*}_mux_w
        if (deq_L1Request_child || enq_L1Request_child_at_enqS3)
            enqE2=1

E3:
    if (E2_r) begin
        E3=1
        if (~childRdy[callChild_mux] || enqE2_r)
            xmemCancel_p2 = 1;
            if (~revoke2)
                enq = 1;

E3/E4:
    if (E3_r)
        if revoke2 // revoke2, and thus enqStall, can be set in consecutive cycles
            enqStall=1
        else // (enq | enqStall_r)
            enqid = callChild_mux;
            enqData = {parentIdx_r, callChild_mux, returnReq_o, pc_o, callArgs_mux};
*/

import func_arbiter_pkg::*;
module call_arbiter#(
    parameter int PARENT = 32,
    parameter int CHILD = 64,
    parameter int LOG_PARENT = (PARENT==1) ? 1 : $clog2(PARENT),
    parameter int LOG_CHILD = (CHILD==1) ? 1 : $clog2(PARENT),
    parameter int CMD_FIFO_DW = ARG_W*ARG_NUM + $clog2(CHILD)+ 1 + 32
) (
    input                            rstn,
    input                            clk,
    input        [CMD_FIFO_DW-1:0]   callParam_i[PARENT],
    output logic                     callRdy_o[PARENT],
    input                            callVld_i[PARENT],
    input                            childRdy[CHILD],
    output logic                     xmemStart,
    output logic                     xmemCancel_p1, xmemCancel_p2, //#ron xmemCancel_p{1,2} at n cancel xmemStart operation at n or n-1 because child is not ready
    output logic [LOG_CHILD-1:0]     xmemStartFunc,
    output logic [LOG_PARENT-1:0]    parentIdx_r,
    output logic                     callVld_mux,
    output logic [LOG_CHILD-1:0]     callChild_mux,
    output logic                     returnReq_o,
    output logic [ARG_W-1:0]         pc_o,
    output logic [ARG_NUM*ARG_W-1:0] callArgs_mux,
    output logic [CALL_SEQ_W-1:0]    storeSeq[CHILD]
);
    localparam int ARGS = ARG_NUM*ARG_W;
    localparam int MQFIFO_PAYLOAD = LOG_CHILD + LOG_PARENT + ARGS + ARG_W + 1 + CALL_SEQ_W;
    localparam bit [0:L1_GROUP-1][7:0] PARENTS_PER_GROUP = get_inst_per_group(PARENT, L1_GROUP);
    localparam bit [0:L1_GROUP-1][7:0] START_PARENT_IDX = get_start_inst_idx(L1_GROUP, PARENTS_PER_GROUP);
    localparam int MAX_PARENTS_PER_GROUP = get_max_inst_per_group(L1_GROUP, PARENTS_PER_GROUP);
    localparam int LOG_MAX_PARENTS_PER_GROUP = $clog2(MAX_PARENTS_PER_GROUP);
    localparam int LOG_L1_GROUP = $clog2(L1_GROUP);

    localparam int ARGS_LSB = 0;
    localparam int ARGS_MSB = ARGS_LSB + ARG_W*ARG_NUM - 1;
    localparam int CHILD_PC_LSB = ARGS_MSB + 1;
    localparam int CHILD_PC_MSB = CHILD_PC_LSB + 31;
    localparam int CHILD_MOD_LSB = CHILD_PC_MSB + 1;
    localparam int CHILD_MOD_MSB = CHILD_MOD_LSB + LOG_CHILD - 1;
    localparam int RETREQ_BIT = CHILD_MOD_MSB + 1;
    localparam int CALLSEQ_LSB = RETREQ_BIT + 1;
    localparam int CALLSEQ_MSB = CALLSEQ_LSB + CALL_SEQ_W - 1;


    localparam int MQFIFO_ARGS_LSB = 0;
    localparam int MQFIFO_ARGS_MSB = MQFIFO_ARGS_LSB + ARGS - 1;
    localparam int MQFIFO_PC_LSB = MQFIFO_ARGS_MSB + 1;
    localparam int MQFIFO_PC_MSB = MQFIFO_PC_LSB + ARG_W - 1;
    localparam int MQFIFO_RET_REQ_BIT = MQFIFO_PC_MSB + 1;
    localparam int MQFIFO_CHILD_LSB = MQFIFO_RET_REQ_BIT + 1;
    localparam int MQFIFO_CHILD_MSB = MQFIFO_CHILD_LSB + LOG_CHILD - 1;
    localparam int MQFIFO_PARENT_LSB = MQFIFO_CHILD_MSB + 1;
    localparam int MQFIFO_PARENT_MSB = MQFIFO_PARENT_LSB + LOG_PARENT - 1;
    localparam int MQFIFO_CALLSEQ_LSB = MQFIFO_PARENT_MSB + 1;
    localparam int MQFIFO_CALLSEQ_MSB = MQFIFO_CALLSEQ_LSB + CALL_SEQ_W - 1;
    localparam int MQFIFO_LEN = 64;

    //logic                     callRdy[PARENT];
    logic foundL1;
    logic [LOG_L1_GROUP-1:0] L1grp;
    logic [LOG_PARENT-1:0] local_p;
    logic [LOG_PARENT:0] r;
    logic [LOG_CHILD:0] q;
    logic [LOG_CHILD-1:0] qsel, qsel_r, qsel_r2;
    logic [LOG_L1_GROUP:0] grp;
    logic [LOG_L1_GROUP-1:0] gsel, gsel_r;
    logic [LOG_MAX_PARENTS_PER_GROUP:0] wptr_r[L1_GROUP], wptr[L1_GROUP];
    logic [LOG_L1_GROUP:0] grp_ptr_r, grp_ptr;
    logic [LOG_CHILD:0] rptr_r, rptr;
    logic [L1_GROUP-1:0] L1Vld, L1Vld_r;
    //logic [L1_GROUP-1:0] set_L1Vld;
    //logic [L1_GROUP-1:0] clr_L1Vld_E2, clr_L1Vld_E3;
    logic [LOG_CHILD-1:0] L1Child[L1_GROUP], L1Child_r[L1_GROUP];
    logic [LOG_PARENT-1:0] L1Parent[L1_GROUP], L1Parent_r[L1_GROUP];
    logic [ARG_NUM*ARG_W-1:0] L1Args[L1_GROUP], L1Args_r[L1_GROUP];
    logic [ARG_W-1:0] L1Pc[L1_GROUP], L1Pc_r[L1_GROUP];
    logic L1RetReq[L1_GROUP], L1RetReq_r[L1_GROUP];
    logic [CALL_SEQ_W-1:0] L1CallSeq[L1_GROUP], L1CallSeq_r[L1_GROUP];
    logic [LOG_PARENT-1:0] parentIdx;
    logic xmemStart_r, xmemStart_r2;
    //#ron replaced by xmemCancel logic reserve_output, reserve_output_r;
    logic revoke2;
    logic mqfifo_almost_full;

    logic enqRdy_r;
    logic [CHILD-1:0] deqVld_r;
    logic enq, enq_r, enq_masked, deq, deq_r, deq_masked;
    logic [LOG_CHILD-1:0] enqid, enqid_r, deqid, deqid_r;
    logic [MQFIFO_PAYLOAD-1:0] enqData, enqData_r;
    logic [MQFIFO_PAYLOAD-1:0] deqData;
    logic                      dataVld;
    logic                      enqStall;
    logic                      req_from_L1, req_from_L1_r;

    logic                     callVld_mux_w;
    logic [LOG_CHILD-1:0]     callChild_mux_w;
    logic                     returnReq_w;
    logic [ARG_W-1:0]         pc_w;
    logic [ARG_NUM*ARG_W-1:0] callArgs_mux_w;
    logic [CALL_SEQ_W-1:0]    cur_call_seq, cur_call_seq_r;

    logic [CMD_FIFO_DW+CALL_SEQ_W-1:0]  callParam_grp[L1_GROUP][MAX_PARENTS_PER_GROUP];
    logic [MAX_PARENTS_PER_GROUP-1:0]   callVld_grp[L1_GROUP];

    logic [CMD_FIFO_DW-1:0]   callParam_w[PARENT], callParam_r[PARENT];
    logic                     callVld_w[PARENT], callVld_r[PARENT];
    logic                     clrCallVld[PARENT];
    logic [CALL_SEQ_W-1:0]    callSeq[PARENT], callSeq_w[PARENT];
    logic [CALL_SEQ_W-1:0]    storeSeq_r[CHILD];

    linked_fifo #(
        .LEN        (MQFIFO_LEN),
        .PAYLOAD    (MQFIFO_PAYLOAD),
        .QNUM       (CHILD)
    ) mq_fifo (
        .rstn       (rstn),
        .clk        (clk),
        .revoke2    (revoke2),
        .enq        (enq_r),
        .deq        (deq_masked),
        .enqid      (enqid_r),
        .deqid      (deqid_r),
        .enqData    (enqData_r),
        .enqRdy_r   (enqRdy_r),
        .almost_full_r(mqfifo_almost_full),
        .deqVld_r   (deqVld_r),
        .deqData    (deqData),
        .dataVld    (dataVld)
    );

    //input buffer
    always_comb begin
        callParam_w = callParam_r;
        callVld_w = callVld_r;
        callSeq_w = callSeq;
        for (int p=0; p<PARENT; p++) begin
            callRdy_o[p] = ~callVld_r[p];
            if (~callVld_r[p] && callVld_i[p]) begin
                callSeq_w[p] = callSeq[p] + callParam_i[p][RETREQ_BIT];
                callParam_w[p] = callParam_i[p];
                callVld_w[p] = 1;
            end
            else if (clrCallVld[p]) begin
                callVld_w[p] = 0;
            end
        end
    end


    always_comb begin

        {revoke2, xmemCancel_p1, xmemCancel_p2, xmemStart, xmemStartFunc, q, r, gsel, deq, deqid, qsel, req_from_L1} = 0;
        {rptr, qsel, grp_ptr}  = {rptr_r, qsel_r, grp_ptr_r};
        wptr = wptr_r;

        callVld_mux_w = 0;
        {callChild_mux_w, callArgs_mux_w, pc_w, returnReq_w, parentIdx,   cur_call_seq} =
        {callChild_mux,   callArgs_mux,   pc_o, returnReq_o, parentIdx_r, cur_call_seq_r};

        for(int g=0; g<L1_GROUP; g++) begin
            {L1Vld[g],   L1Parent[g],   L1Child[g],   L1Args[g],   L1Pc[g],   L1RetReq[g],   L1CallSeq[g]} =
            {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1Args_r[g], L1Pc_r[g], L1RetReq_r[g], L1CallSeq_r[g]};
        end

        storeSeq = storeSeq_r;//output without reg because retVld can arrive at same cycle
        if (callVld_mux && childRdy[callChild_mux] && returnReq_o) begin
            storeSeq[callChild_mux] = cur_call_seq_r;
        end

        // Dequeue pipeline stages
        //D4 stage: set revoke2 for dequeued request if target child not ready
        if (callVld_mux && ~childRdy[callChild_mux] && ~req_from_L1_r) begin
            revoke2 = 1;
            xmemCancel_p1 = 1;
        end

        // D3 stage: send data from mqfifo to child call port
        if (dataVld) begin
            rptr = rptr_r + 1;
            if (rptr==CHILD) begin
                rptr = 0;
            end
            callVld_mux_w = 1;
            callChild_mux_w = qsel_r2;
            callArgs_mux_w = deqData[MQFIFO_ARGS_MSB:MQFIFO_ARGS_LSB];
            parentIdx = deqData[MQFIFO_PARENT_MSB:MQFIFO_PARENT_LSB];
            pc_w = deqData[MQFIFO_PC_MSB:MQFIFO_PC_LSB];
            returnReq_w = deqData[MQFIFO_RET_REQ_BIT];
            cur_call_seq = deqData[MQFIFO_CALLSEQ_MSB:MQFIFO_CALLSEQ_LSB];
            xmemStart = 1;
            xmemStartFunc = deqData[MQFIFO_CHILD_MSB:MQFIFO_CHILD_LSB];
        end

        // D2 stage: deq_amsked and deqid_r applied to mqfifo
        deq_masked = deq_r & ~revoke2;

        // D1 stage
        if (~revoke2) begin
            for(int c=CHILD-1; c>=0; c--) begin
                q = rptr_r + c;
                if (q >= CHILD) begin
                    q -= CHILD;
                end

                if (deqVld_r[q] && childRdy[q] &&
                    ~(deq_r && (deqid_r==q)) &&
                    ~(dataVld && (qsel_r2==q))
                ) begin
                    deq = 1;
                    deqid = q;
                    qsel = q;
                end
            end
        end

        // Enqueue pipeline stages
        enqStall = enq_r & callVld_mux & ~childRdy[callChild_mux] & ~req_from_L1_r;
        {enq, enqid, enqData} = {enqStall, enqid_r, enqData_r};

        local_p = 0;
        callParam_grp = '{default: '0};
        callVld_grp = '{default: '0};
        for(int g=0; g<L1_GROUP; g++) begin
            for(int p=0; p<MAX_PARENTS_PER_GROUP; p++) begin
                if ((local_p < PARENT) && (p<PARENTS_PER_GROUP[g])) begin
                    callParam_grp[g][p] = {callSeq[local_p], callParam_r[local_p]};
                    callVld_grp[g][p] = callVld_r[local_p];
                    local_p++;
                end
            end
        end

        //E1 stage
        clrCallVld = '{default: '0};
        for(int g = 0; g < L1_GROUP; g++) begin
            // Select parent based on wptr_r based on callVld
            for(int i=0; i<PARENTS_PER_GROUP[g]; i++) begin
                r = i + wptr_r[g];
                if (r>=PARENTS_PER_GROUP[g])
                    r -= PARENTS_PER_GROUP[g];

                if (callVld_grp[g][r] && ~L1Vld_r[g]) begin
                    // buffer new request in L1 buffer
                    //callRdy[START_PARENT_IDX[g] + r] = 1;
                    clrCallVld[START_PARENT_IDX[g] + r] = 1;
                    L1Vld[g] = 1; // Mark this group as valid
                    L1Parent[g] = START_PARENT_IDX[g] + r;
                    L1Child[g] = callParam_grp[g][r][CHILD_MOD_MSB:CHILD_MOD_LSB];
                    L1Args[g] = callParam_grp[g][r][ARGS_MSB:ARGS_LSB];
                    L1Pc[g] = callParam_grp[g][r][CHILD_PC_MSB:CHILD_PC_LSB];
                    L1RetReq[g] = callParam_grp[g][r][RETREQ_BIT];
                    L1CallSeq[g] = callParam_grp[g][r][CALLSEQ_MSB:CALLSEQ_LSB];

                    wptr[g] = r + 1;
                    break;
                end
            end
        end

        //# Enqueue Stage E1b
        //  Round robin select a child from L1 group g and inform xmem to start fetching
        //  if no dequeue and child function is ready
        //   - Select a group g, such that L1Vld[g]=1, using remaining bits of wptr_r
        //   - set arb_start_s1 = 1<<L1_child_r[g]
        foundL1 = 0;
        L1grp = 0;
        for(int i = L1_GROUP-1; i>=0 ; i--) begin
            grp = i + grp_ptr_r;
            if (grp>=L1_GROUP) begin
                grp -= L1_GROUP;
            end
            if (L1Vld[grp] & ~enqStall) begin //#ron
                foundL1 = 1;
                L1grp = grp;
                gsel = L1grp;
                grp_ptr = grp + 1;
            end
        end

        // stage E2: if not dequeueing, try to output from L1 buffer
        if (~dataVld &&                             // There is no dequeued request
            L1Vld_r[gsel_r] &&                      // L1 is valid
            ~deqVld_r[L1Child_r[gsel_r]] &&         // Otherwise can be asserted the revoke2
                                                    // and requests will be reordered
            ~(enq_r && enqid_r==L1Child_r[gsel_r])  // There is no older request R0 to
                                                    // the same child since enq_r=1 enqid_r==L1Child[gsel_r].
        ) begin
            if (childRdy[L1Child_r[gsel_r]] && ~mqfifo_almost_full) begin
                // need to check available number of cells (not mqfifo_almost_full) in mqfifo,
                // due to on the next cycle required chidRdy can become 0 and will need to enq request,
                // so will be need free space in mqfifo
                req_from_L1 = 1;
                callVld_mux_w = 1;
                callChild_mux_w = L1Child_r[gsel_r];
                callArgs_mux_w = L1Args_r[gsel_r];
                pc_w = L1Pc_r[gsel_r];
                parentIdx = L1Parent_r[gsel_r];
                returnReq_w = L1RetReq_r[gsel_r];
                cur_call_seq = L1CallSeq_r[gsel_r];
                L1Vld[gsel_r] = 0;
            end
            else begin
                xmemCancel_p1=1;
            end
        end

        // E3 stage
        // push the new request at L1 buffer to mqfifo if it cannot be outputted yet
        // callRdy = '{default: '0};
        // callRdy[parentIdx_r] = callVld_mux==1 && childRdy[callChild_mux]==1 && dataVld==0;
        if (callVld_mux && ~childRdy[callChild_mux] && req_from_L1_r) begin
            //#Enqueue stage E3
            if (xmemStart_r2) xmemCancel_p2 = 1;
            enq = 1;
            enqid = callChild_mux;
            enqData = {cur_call_seq_r, parentIdx_r, callChild_mux, returnReq_o, pc_o, callArgs_mux};
        end
        else if (L1Vld_r[gsel_r] && ~mqfifo_almost_full && ~enqStall && // there is valid L1 request
                ~(deq_r && (deqid_r==L1Child_r[gsel_r])) && // there is no deq request with same id at previous cycle, because possible revoke2
                ~(dataVld && (qsel_r2==L1Child_r[gsel_r])) // there is no deq request with same id 2 cycles ago, because possible revoke2
            ) begin
            // Can't send enqueue request if was deq with same if at 1 or 2 cycles ago
            if (dataVld || childRdy[L1Child_r[gsel_r]]==0 || deqVld_r[L1Child_r[gsel_r]]) begin
                L1Vld[gsel_r] = 0;
                if (xmemStart_r) xmemCancel_p1=1;
                enq = 1;
                enqid = L1Child_r[gsel_r];
                enqData = {L1CallSeq_r[gsel_r], L1Parent_r[gsel_r], L1Child_r[gsel_r], L1RetReq_r[gsel_r], L1Pc_r[gsel_r], L1Args_r[gsel_r]};
            end
            else if (req_from_L1) begin // sending L1 request directly to callVld output and clear L1Vld
                L1Vld[gsel_r] = 0;
            end
        end
    end


    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            {rptr_r, qsel_r, qsel_r2, gsel_r, xmemStart_r, xmemStart_r2, req_from_L1_r, grp_ptr_r} <=0;
            wptr_r <= '{default: '0};
            {enq_r, enqid_r, enqData_r} <= 0;
            {callVld_mux, callChild_mux, callArgs_mux, pc_o, returnReq_o, parentIdx_r, cur_call_seq_r} <= 0;

            for (int p=0; p<PARENT; p++) begin
                callSeq[p] <= -1;
            end

            for (int c=0; c<CHILD; c++) begin
                storeSeq_r[c] <= -1;
            end

            {deq_r, deqid_r} <= 0;

            //callRdy_o <= '{default: 0};
            callParam_r <= '{default: 0};
            callVld_r <= '{default: 0};

            L1Vld_r <= 0;
            for(int g=0; g<L1_GROUP; g++)
                {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1Args_r[g], L1Pc_r[g], L1RetReq_r[g], L1CallSeq_r[g]} <= 0;
        end
        else begin
            //callRdy_o <= callRdy;
            callParam_r <= callParam_w;
            callVld_r <= callVld_w;

            callSeq <= callSeq_w;
            storeSeq_r <= storeSeq;

            {enq_r, enqid_r, enqData_r} <= {enq, enqid, enqData};

            wptr_r <= wptr;

            {deq_r, deqid_r} <= {deq, deqid};//D2 stage

            {rptr_r, qsel_r, qsel_r2, gsel_r, xmemStart_r, xmemStart_r2, req_from_L1_r, grp_ptr_r} <=
            {rptr,   qsel,   qsel_r,  gsel,    xmemStart,   xmemStart_r,   req_from_L1, grp_ptr};
            {callVld_mux,   callChild_mux,   callArgs_mux,   pc_o, returnReq_o, parentIdx_r, cur_call_seq_r} <=
            {callVld_mux_w, callChild_mux_w, callArgs_mux_w, pc_w, returnReq_w, parentIdx,   cur_call_seq};

            for(int g=0; g<L1_GROUP; g++) begin
                {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1Args_r[g], L1Pc_r[g], L1RetReq_r[g], L1CallSeq_r[g]} <=
                {L1Vld[g],   L1Parent[g],   L1Child[g],   L1Args[g],   L1Pc[g],   L1RetReq[g],   L1CallSeq[g]};
            end
        end
    end
endmodule
