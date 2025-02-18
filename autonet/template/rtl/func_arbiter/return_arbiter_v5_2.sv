
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

- Updated implmentation details:
    - 3-stage write arbitration logic
        - stage 0: input buffering: retDin_r <= child_retDin_i
        - stage 1: L1 arbitration forwards one input buffer from each group L1 buffer, i.e. L1RetVal[g] = retDin_r[...] for each g
        - stage 2: L2 arbitration forwards one L1 buffer to the ret_ram write port
    - Read arbitration logic
        - round robin arbitrator select a cur_p such that robVld_r[cur_p][popSeq_r[cur_p]] and read from ret_ram
        - The return arbiter buffer the read data parent_retFifo_dout[cur_p] and clear the buffer when parent cur_p fetch read data later
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
    output logic [FULL_RET_DW-1:0]          parent_retFifo_dout_o[PARENT]
);
    localparam bit [0:L1_GROUP-1][7:0]  CHILD_PER_GROUP = get_inst_per_group(CHILD, L1_GROUP);//CHILD / L1_GROUP;
    localparam bit [0:L1_GROUP-1][7:0]  START_CHILD_IDX = get_start_inst_idx(L1_GROUP, CHILD_PER_GROUP);
    localparam int MAX_CHILD_PER_GROUP = get_max_inst_per_group(L1_GROUP, CHILD_PER_GROUP);
    localparam int LOG_MAX_CHILD_PER_GROUP = $clog2(MAX_CHILD_PER_GROUP);
    localparam int LOG_L1_GROUP = $clog2(L1_GROUP);

    localparam int RET_RAM_DEPTH = PARENT*ROB_W;
    localparam int RET_RAM_AW = $clog2(RET_RAM_DEPTH);
    localparam int RET_RAM_DW = FULL_RET_DW;

    logic [PARENT-1:0]              parent_retFifo_empty_n, parent_retFifo_empty_n_r;
    logic [PARENT-1:0]              parent_retFifo_pop_r;
    logic [FULL_RET_DW-1:0]         parent_retFifo_dout[PARENT], parent_retFifo_dout_r[PARENT];

    logic [ROB_W-1:0]               robVld[PARENT], robVld_r[PARENT];
    logic [ROB_W-1:0]               clr_robVld[PARENT], clr_robVld_r[PARENT];
    logic [PARENT-1:0]              nextRobVld, nextRobVld_r;
    logic [CALL_SEQ_W-1:0]          popSeq[PARENT], popSeq_r[PARENT];
    logic [CALL_SEQ_W-1:0]          storeSeq_w[CHILD], storeSeq_r[CHILD];

    logic                           retVld_w[CHILD], retVld_r[CHILD];
    logic [31:0]                    retDin_w[CHILD], retDin_r[CHILD];
    logic [LOG_PARENT-1:0]          parentMod_w[CHILD], parentMod_r[CHILD];
    logic                           clrRetVld[CHILD];
    logic [LOG_CHILD-1:0]           local_c;

    logic [31:0]                    retDin_grp[L1_GROUP][MAX_CHILD_PER_GROUP];
    logic [MAX_CHILD_PER_GROUP-1:0] retVld_grp[L1_GROUP];
    logic [LOG_PARENT-1:0]          parentMod_grp[L1_GROUP][MAX_CHILD_PER_GROUP];
    logic [CALL_SEQ_W-1:0]          storeSeq_grp[L1_GROUP][MAX_CHILD_PER_GROUP];

    logic [LOG_CHILD:0]             wptr_r[L1_GROUP], wptr[L1_GROUP];
    logic [LOG_PARENT:0]            rptr_r, rptr;
    logic [LOG_PARENT:0]            cur_p;
    logic [LOG_PARENT-1:0]          pop_parent, pop_parent_r;
    logic [LOG_MAX_CHILD_PER_GROUP:0] r;
    logic [LOG_L1_GROUP:0]          grp;
    logic [LOG_L1_GROUP:0]          grp_ptr_r, grp_ptr;

    logic [L1_GROUP-1:0]            L1Vld, L1Vld_r;
    logic [LOG_CHILD-1:0]           L1Child[L1_GROUP], L1Child_r[L1_GROUP];
    logic [LOG_PARENT-1:0]          L1Parent[L1_GROUP], L1Parent_r[L1_GROUP];
    logic [RET_DW-1:0]              L1RetVal[L1_GROUP], L1RetVal_r[L1_GROUP];
    logic [CALL_SEQ_W-1:0]          L1StoreSeq[L1_GROUP], L1StoreSeq_r[L1_GROUP];
    logic [L1_GROUP-1:0]            clr_L1Vld;

    logic [RET_RAM_AW-1:0]          ret_ram_wadr;
    logic                           ret_ram_we;
    logic [RET_RAM_DW-1:0]          ret_ram_wdat;
    logic [RET_RAM_AW-1:0]          ret_ram_radr;
    logic                           ret_ram_re, ret_ram_re_r;
    logic [RET_RAM_DW-1:0]          ret_ram_rdat;

    logic [PARENT-1:0]              ret_bypass, ret_bypass_r;
    logic [FULL_RET_DW-1:0]         ret_bypass_data[PARENT], ret_bypass_data_r[PARENT];
    logic                           found, found2;


    dpram  #(
        .usr_ram_style  ("block"),
        .aw             (RET_RAM_AW),
        .dw             (RET_RAM_DW),
        .max_size       (RET_RAM_DEPTH),
        .rd_lat         (1)
    )ret_ram(
        .rd_clk (clk),
        .raddr  (ret_ram_radr),
        .dout   (ret_ram_rdat),
        .wr_clk (clk),
        .we     (ret_ram_we),
        .din    (ret_ram_wdat),
        .waddr  (ret_ram_wadr)
    );

    /*l1_group #(
        .L1_GROUP                   (L1_GROUP),
        .CHILD                      (CHILD),
        .LOG_CHILD                  (LOG_CHILD),
        .LOG_PARENT                 (LOG_PARENT),
        .RET_DW                     (RET_DW),
        .CALL_SEQ_W                 (CALL_SEQ_W),
        .MAX_CHILD_PER_GROUP        (MAX_CHILD_PER_GROUP),
        .LOG_MAX_CHILD_PER_GROUP    (LOG_MAX_CHILD_PER_GROUP)
    ) L1 (
        .clk            (clk),
        .rstn           (rstn),

        .retDin_grp     (retDin_grp),
        .retVld_grp     (retVld_grp),
        .parentMod_grp  (parentMod_grp),
        .storeSeq_grp   (storeSeq_grp),

        .clr_L1Vld      (clr_L1Vld),
        .L1Vld_r        (L1Vld_r),
        .L1Child_r      (L1Child_r),
        .L1Parent_r     (L1Parent_r),
        .L1RetVal_r     (L1RetVal_r),
        .L1StoreSeq_r   (L1StoreSeq_r),
        .clrRetVld      (clrRetVld)
    );*/

    always_comb begin
        //stage0: input buffer
        retDin_w = retDin_r;
        retVld_w = retVld_r;
        parentMod_w = parentMod_r;
        storeSeq_w = storeSeq_r;
        for (int c=0; c<CHILD; c++) begin
            child_retRdy_o[c] = ~retVld_r[c];
            if (~retVld_r[c] && child_retVld_i[c]) begin
                retDin_w[c] = child_retDin_i[c];
                parentMod_w[c] = child_parentMod_i[c];
                storeSeq_w[c] = storeSeq[c];
                retVld_w[c] = 1;
            end
            else if (clrRetVld[c]) begin
                retVld_w[c] = 0;
            end
        end
    end


    //stage1: get data from input buffer to L1
    always_comb begin
        local_c = 0;
        retDin_grp = '{default: '0};
        retVld_grp = '{default: '0};
        parentMod_grp = '{default: '0};
        storeSeq_grp = '{default: '0};
        for(int g=0; g<L1_GROUP; g++) begin
            for(int c=0; c<MAX_CHILD_PER_GROUP; c++) begin
                if ((local_c<CHILD) && (c<CHILD_PER_GROUP[g])) begin
                    retDin_grp[g][c] = retDin_r[local_c];
                    retVld_grp[g][c] = retVld_r[local_c];
                    parentMod_grp[g][c] = parentMod_r[local_c];
                    storeSeq_grp[g][c] = storeSeq_r[local_c];
                    local_c++;
                end
            end
        end

        L1Vld = L1Vld_r;
        L1Parent = L1Parent_r;
        L1Child = L1Child_r;
        L1RetVal = L1RetVal_r;
        L1StoreSeq = L1StoreSeq_r;
        clrRetVld = '{default: '0};
        wptr = wptr_r;
        r = 0;
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
                    L1StoreSeq[g] = storeSeq_grp[g][r];

                    wptr[g] = r + 1;
                    break;
                end
            end
        end

        //stage2: write data from L1 to parent fifo interface
        robVld = robVld_r;
        for (int p=0; p<PARENT; p++) begin
            for (int i=0; i<ROB_W; i++) begin
                if (clr_robVld_r[p][i]) begin
                    robVld[p][i] = 0;
                end
            end
        end

        {ret_ram_we, ret_ram_wadr, ret_ram_wdat} = 0;
        grp = 0;
        grp_ptr = grp_ptr_r;
        clr_L1Vld = 0;
        ret_bypass = 0;
        ret_bypass_data = '{default: 0};
        found = 0;
        for(int g = 0; g < L1_GROUP; g++) begin
            grp = g + grp_ptr_r;
            if (grp>=L1_GROUP) begin
                grp -= L1_GROUP;
            end

            if (L1Vld_r[grp] && (found==0)) begin
                grp_ptr = grp + 1;
                L1Vld[grp] = 0;
                clr_L1Vld[grp] = 1;
                /*if ((L1StoreSeq_r[grp]==popSeq_r[L1Parent_r[grp]]) &&
                    (~parent_retFifo_empty_n_r[L1Parent_r[grp]] || parent_retFifo_pop_r[L1Parent_r[grp]])
                ) begin
                    ret_bypass[L1Parent_r[grp]] = 1;
                    ret_bypass_data[L1Parent_r[grp]] = {L1Child_r[grp], L1RetVal_r[grp]};
                end
                else if (found==0) begin*/
                    robVld[L1Parent_r[grp]][L1StoreSeq_r[grp]] = 1;
                    ret_ram_we = 1;
                    ret_ram_wadr = L1Parent_r[grp]*ROB_W + L1StoreSeq_r[grp];
                    ret_ram_wdat = {L1Child_r[grp], L1RetVal_r[grp]};
                    found = 1;
                    //break;
                //end
            end
        end

        //connect to parent module
        popSeq = popSeq_r;
        {ret_ram_re, ret_ram_radr} = 0;
        rptr = rptr_r;
        cur_p = 0;
        pop_parent = 0;
        clr_robVld = '{default: 0};
        found2 = 0;
        for (int p=0; p<PARENT; p++) begin
            cur_p = p + rptr_r;
            if (cur_p>=PARENT) begin
                cur_p -= PARENT;
            end

            /*if (ret_bypass[cur_p]) begin
                popSeq[cur_p] = popSeq_r[cur_p] + 1;
            end
            else */if (nextRobVld_r[cur_p] && (~ret_ram_re_r || (cur_p!=pop_parent_r)) && (found2==0)) begin
                ret_ram_re = 1;
                ret_ram_radr = cur_p*ROB_W + popSeq_r[cur_p];
                clr_robVld[cur_p][popSeq_r[cur_p]] = 1;
                popSeq[cur_p] = popSeq_r[cur_p] + 1;
                rptr = cur_p + 1;
                pop_parent = cur_p;
                found2 = 1;
                //break;
            end
        end

        nextRobVld = nextRobVld_r;
        for (int p=0; p<PARENT; p++) begin
            nextRobVld[p] = robVld/*_r*/[p][popSeq[p]];
        end

        parent_retFifo_empty_n = parent_retFifo_empty_n_r;
        parent_retFifo_dout = parent_retFifo_dout_r;
        for (int p=0; p<PARENT; p++) begin
            if (parent_retFifo_empty_n_r[p] && parent_retFifo_pop_r[p]) begin
                parent_retFifo_empty_n[p] = 0;
            end
            else if (ret_ram_re_r && (p==pop_parent_r)) begin
                parent_retFifo_empty_n[p] = 1;
                parent_retFifo_dout[p] = ret_ram_rdat;
            end
            else if (ret_bypass_r[p]) begin
                parent_retFifo_empty_n[p] = 1;
                parent_retFifo_dout[p] = ret_bypass_data_r[p];
            end
        end
    end

    assign parent_retFifo_empty_n_o = parent_retFifo_empty_n;
    assign parent_retFifo_dout_o = parent_retFifo_dout;

    always @ (posedge clk or negedge rstn) begin
        if(~rstn) begin
            wptr_r <= '{default: 0};
            rptr_r <= 0;
            pop_parent_r <= 0;
            ret_ram_re_r <= 0;
            grp_ptr_r <= 0;

            retDin_r <= '{default: '0};
            retVld_r <= '{default: '0};
            parentMod_r <= '{default: '0};
            for (int c=0; c<CHILD; c++) begin
                storeSeq_r[c] <= -1;
            end

            robVld_r <= '{default: '0};
            clr_robVld_r <= '{default: '0};
            nextRobVld_r <= 0;
            parent_retFifo_pop_r <= 0;
            parent_retFifo_empty_n_r <= 0;
            parent_retFifo_dout_r <= '{default: 0};
            popSeq_r <= '{default: '0};

            ret_bypass_r <= 0;
            ret_bypass_data_r <= '{default: '0};

            for(int g=0; g<L1_GROUP; g++) begin
                {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1RetVal_r[g], L1StoreSeq_r[g]} <= 0;
            end
        end
        else begin
            wptr_r <= wptr;
            rptr_r <= rptr;
            pop_parent_r <= pop_parent;
            ret_ram_re_r <= ret_ram_re;
            grp_ptr_r <= grp_ptr;

            retDin_r <= retDin_w;
            retVld_r <= retVld_w;
            parentMod_r <= parentMod_w;
            storeSeq_r <= storeSeq_w;

            clr_robVld_r <= clr_robVld;
            robVld_r <= robVld;
            nextRobVld_r <= nextRobVld;
            parent_retFifo_pop_r <= parent_retFifo_pop_i;
            parent_retFifo_empty_n_r <= parent_retFifo_empty_n;
            parent_retFifo_dout_r <= parent_retFifo_dout;
            popSeq_r <= popSeq;

            ret_bypass_r <= ret_bypass;
            ret_bypass_data_r <= ret_bypass_data;

            for(int g=0; g<L1_GROUP; g++) begin
                {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1RetVal_r[g], L1StoreSeq_r[g]} <=
                {L1Vld[g],   L1Parent[g],   L1Child[g],   L1RetVal[g],   L1StoreSeq[g]};
            end
        end
    end

endmodule


/*module l1_group #(
    parameter int L1_GROUP = 2,
    parameter int CHILD = 64,
    parameter int LOG_CHILD = 6,
    parameter int LOG_PARENT = 5,
    parameter int RET_DW = 32,
    parameter int CALL_SEQ_W = 2,
    parameter bit [0:L1_GROUP-1][7:0]  CHILD_PER_GROUP = get_inst_per_group(CHILD, L1_GROUP),
    parameter int MAX_CHILD_PER_GROUP = get_max_inst_per_group(L1_GROUP, CHILD_PER_GROUP),
    parameter int LOG_MAX_CHILD_PER_GROUP = 4

)(
    input                                  clk,
    input                                  rstn,
    input        [31:0]                    retDin_grp[L1_GROUP][MAX_CHILD_PER_GROUP],
    input        [MAX_CHILD_PER_GROUP-1:0] retVld_grp[L1_GROUP],
    input        [LOG_PARENT-1:0]          parentMod_grp[L1_GROUP][MAX_CHILD_PER_GROUP],
    input        [CALL_SEQ_W-1:0]          storeSeq_grp[L1_GROUP][MAX_CHILD_PER_GROUP],
    input        [L1_GROUP-1:0]            clr_L1Vld,
    output logic [L1_GROUP-1:0]            L1Vld_r,
    output logic [LOG_CHILD-1:0]           L1Child_r[L1_GROUP],
    output logic [LOG_PARENT-1:0]          L1Parent_r[L1_GROUP],
    output logic [RET_DW-1:0]              L1RetVal_r[L1_GROUP],
    output logic [CALL_SEQ_W-1:0]          L1StoreSeq_r[L1_GROUP],
    output logic                           clrRetVld[CHILD]
);
    localparam bit [0:L1_GROUP-1][7:0]  START_CHILD_IDX = get_start_inst_idx(L1_GROUP, CHILD_PER_GROUP);

    logic [L1_GROUP-1:0]            L1Vld;
    logic [LOG_CHILD-1:0]           L1Child[L1_GROUP];
    logic [LOG_PARENT-1:0]          L1Parent[L1_GROUP];
    logic [RET_DW-1:0]              L1RetVal[L1_GROUP];
    logic [CALL_SEQ_W-1:0]          L1StoreSeq[L1_GROUP];
    logic [LOG_CHILD:0]             wptr_r[L1_GROUP], wptr[L1_GROUP];
    logic [LOG_MAX_CHILD_PER_GROUP:0] r;

    always_comb begin
        L1Vld = L1Vld_r & ~clr_L1Vld;
        L1Parent = L1Parent_r;
        L1Child = L1Child_r;
        L1RetVal = L1RetVal_r;
        L1StoreSeq = L1StoreSeq_r;
        clrRetVld = '{default: '0};
        wptr = wptr_r;
        r = 0;
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
                    L1StoreSeq[g] = storeSeq_grp[g][r];

                    wptr[g] = r + 1;
                    break;
                end
            end
        end
    end

    always @ (posedge clk or negedge rstn) begin
        if(~rstn) begin
            wptr_r <= '{default: 0};
            for(int g=0; g<L1_GROUP; g++) begin
                {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1RetVal_r[g], L1StoreSeq_r[g]} <= 0;
            end
        end
        else begin
            wptr_r <= wptr;
            for(int g=0; g<L1_GROUP; g++) begin
                {L1Vld_r[g], L1Parent_r[g], L1Child_r[g], L1RetVal_r[g], L1StoreSeq_r[g]} <=
                {L1Vld[g],   L1Parent[g],   L1Child[g],   L1RetVal[g],   L1StoreSeq[g]};
            end
        end
    end

endmodule*/