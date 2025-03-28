/////////////////////////////////////////////////////////////////////////////////////////////////////
// Company            : ViShare Technology Limited
// Designed by        : Edward Leung
// Date Created       : 2025-03-04
// Description        : Return arbter
// Version            : v8.0 - remove callSeq and move to call_arbiter
//                           - two modes: FIFO mode & non-FIFO mode.
//                           - FIFO mode maintains return sequence for thread.
//                             Only one parent run thread at same time.
//                             It is used in parallel child processing.
//                           - Non-FIFO mode handle the most recent return fist.
//                             More than one thread can run the thread at same time.
//                             Parent cannot call new child until the last is returned.
//                             It is used in hierarchy function call.
//                           - (2025-03-07) Optmization for timing path by register child arbiter
//                             output.
/////////////////////////////////////////////////////////////////////////////////////////////////////
module return_arbiter #(
    THREAD      = 16,
    SEQBUF      = 4,
    DATA        = 32,
    PARENT      = 64,
    CHILD       = 64,
    SEQ         = 2 * SEQBUF,
    LOG_THREAD  = $clog2(THREAD),
    LOG_SEQ     = $clog2(SEQ),
    LOG_SEQBUF  = $clog2(SEQBUF),
    LOG_PARENT  = $clog2(PARENT),
    LOG_CHILD   = $clog2(CHILD),
    REDUCE_LAT  = 1
)
(
    input                         rstn,
    input                         clk,
    output logic [THREAD-1:0]     return_error_o,
    //Return from chlid
    input                         childRet_i[CHILD],
    input [LOG_PARENT-1:0]        childRetParent_i[CHILD],
    input [LOG_THREAD-1:0]        childThread_i[CHILD],
    input [LOG_SEQ-1:0]           childSeq_i[CHILD],
    input                         childMode_i[CHILD],
    input [DATA-1:0]              childResult_i[CHILD],
    output logic                  childRetRdy_o[CHILD],
    //Return to parent
    input [PARENT-1:0]            parentPop_i,
    output logic [PARENT-1:0]     parentPopRdy_o,
    output logic [LOG_THREAD-1:0] parentThread_o[PARENT],
    output logic [LOG_CHILD-1:0]  parentChild_o[PARENT],
    output logic [DATA-1:0]       parentResult_o[PARENT]
);

localparam BUF_WIDTH = DATA + LOG_PARENT + LOG_CHILD + 1;
localparam BUF_DEPTH = THREAD * SEQBUF;
localparam BUF_ABITS = $clog2(BUF_DEPTH);

//Child input registers
logic [CHILD-1:0]         childRet;
logic [CHILD-1:0]         childRet_r;
logic [LOG_PARENT-1:0]    childRetParent[CHILD];
logic [LOG_PARENT-1:0]    childRetParent_r[CHILD];
logic [LOG_THREAD-1:0]    childThread[CHILD];
logic [LOG_THREAD-1:0]    childThread_r[CHILD];
logic [LOG_SEQ-1:0]       childSeq[CHILD];
logic [LOG_SEQ-1:0]       childSeq_r[CHILD];
logic                     childMode[CHILD];
logic                     childMode_r[CHILD];
logic [DATA-1:0]          childResult[CHILD];
logic [DATA-1:0]          childResult_r[CHILD];
//Parent output registes
logic [PARENT-1:0]        parentPopRdy;
logic [PARENT-1:0]        parentPopRdy_r;
logic [LOG_THREAD-1:0]    parentThread[PARENT];
logic [LOG_THREAD-1:0]    parentThread_r[PARENT];
logic [LOG_CHILD-1:0]     parentChild[PARENT];
logic [LOG_CHILD-1:0]     parentChild_r[PARENT];
logic [DATA-1:0]          parentResult[PARENT];
logic [DATA-1:0]          parentResult_r[PARENT];
//Thread pop
logic [THREAD-1:0]        popRdy;
logic [THREAD-1:0]        popRdy_r;
logic [LOG_SEQ-1:0]       popSeq[THREAD];
logic [LOG_SEQ-1:0]       popSeq_r[THREAD];
//Sequence buffer
logic                     seqBufRdy[THREAD][SEQBUF];
logic                     seqBufRdy_r[THREAD][SEQBUF];
logic [BUF_ABITS-1:0]     seqBuf_radr;
logic [BUF_WIDTH-1:0]     seqBuf_dout;
logic                     seqBuf_we;
logic [BUF_WIDTH-1:0]     seqBuf_din;
logic [BUF_ABITS-1:0]     seqBuf_wadr;
//Child return arbiter
logic                     returnVld;
logic [LOG_CHILD-1:0]     returnSel;
logic [LOG_SEQ-1:0]       returnSeq;
logic [LOG_THREAD-1:0]    returnThread;
logic [DATA-1:0]          returnResult;
logic [LOG_PARENT-1:0]    returnParent;
logic                     returnMode;
//Others
logic                     popVld;
logic [LOG_THREAD-1:0]    popSel;
logic [THREAD-1:0]        return_error;
logic [THREAD-1:0]        return_error_r;
//TEMP
logic [DATA-1:0]          res;
logic [LOG_PARENT-1:0]    pidx;
logic [LOG_CHILD-1:0]     cidx;
logic                     fmode;

//bool parentPop(int t0, int &returnResult);
retArb_rr_arbiter #(
    .MUX_NUM ( THREAD ),
    .REG_OUT ( 0      )
)
inst_pop_arbiter
(
    .clk      ( clk       ),
    .rstn     ( rstn      ),
    .sel      ( popRdy_r  ),
    .vld_o    ( popVld    ),
    .vldPtr_o ( popSel    )
);

//bool childDone(int child, int childseq, int t0, int r);
retArb_rr_arbiter #(
    .MUX_NUM ( CHILD ),
    .REG_OUT ( 1     )
)
inst_child_arbiter
(
    .clk      ( clk           ),
    .rstn     ( rstn          ),
    .sel      ( childRet_r    ),
    .vld_o    ( returnVld     ),
    .vldPtr_o ( returnSel     )
);

//Sequence Buffer
dpram #(
    .aw       ( BUF_ABITS ),
    .dw       ( BUF_WIDTH ),
    .max_size ( BUF_DEPTH ),
    .rd_lat   ( 0         ) //opt
)
inst_seq_buffer (
    .rd_clk  ( clk         ),
    .raddr   ( seqBuf_radr ),
    .dout    ( seqBuf_dout ),
    .wr_clk  ( clk         ),
    .we      ( seqBuf_we   ),
    .din     ( seqBuf_din  ),
    .waddr   ( seqBuf_wadr )
);

always_comb begin
    childRet       = childRet_r;
    childRetParent = childRetParent_r;
    childThread    = childThread_r;
    childSeq       = childSeq_r;
    childMode      = childMode_r;
    childResult    = childResult_r;
    parentPopRdy   = parentPopRdy_r;
    parentThread   = parentThread_r;
    parentChild    = parentChild_r;
    parentResult   = parentResult_r;
    popSeq         = popSeq_r;
    popRdy         = popRdy_r;
    seqBufRdy      = seqBufRdy_r;
    return_error   = 0;
    seqBuf_we      = 0;

    //-----------------------------------------------
    //Stage 0: Child return
    //-----------------------------------------------
    for (int i = 0; i < CHILD; i = i + 1) begin
        childRetRdy_o[i] = ~childRet_r[i];
        if (childRetRdy_o[i]) begin
            childRet      [i] = childRet_i[i];
            childRetParent[i] = childRetParent_i[i];
            childThread   [i] = childThread_i[i];
            childSeq      [i] = childSeq_i[i];
            childMode     [i] = childMode_i[i];
            childResult   [i] = childResult_i[i];
        end
        else if (returnVld && returnSel == i) begin
            childRet      [i] = 0;
        end
    end

    //------------------------------------------------
    //Stage 1: Child Arbiter with one cycle latency
    //------------------------------------------------

    //------------------------------------------------
    //Stage 2a: Child arbitration push sequece buffer
    //------------------------------------------------
    //Child arbiter
    returnThread = childThread_r[returnSel];
    returnSeq    = childSeq_r[returnSel];
    returnResult = childResult_r[returnSel];
    returnParent = childRetParent_r[returnSel];
    returnMode   = childMode_r[returnSel];
    //Non-FIFO mode (returnMode=0), it handle the most updated return. So, returnSeq = popSeq.
    if (returnMode == 0) begin
        returnSeq = popSeq_r[returnThread];
    end
    seqBuf_wadr = returnThread * SEQBUF + returnSeq[LOG_SEQBUF-1:0];
    seqBuf_din  = {returnMode, returnSel, returnParent, returnResult};
    if (returnVld) begin
        //Write to sequence buffer if buffer is available.
        seqBuf_we = 1;
        seqBufRdy[returnThread][returnSeq[LOG_SEQBUF-1:0]] = 1;
        //Set thread ready if hit the pop sequence (if needed).
        if (REDUCE_LAT == 1) begin
            if (popRdy_r[returnThread] == 0) begin
                popRdy[returnThread] = (returnSeq == popSeq_r[returnThread]);
            end
        end
        //Error if buffer is not popped yet.
        if (seqBufRdy_r[returnThread][returnSeq[LOG_SEQBUF-1:0]]) begin
            return_error[returnThread] = 1;
        end
    end
    return_error_o = return_error_r;

    //-----------------------------------------------
    //Stage 2b: Thread pop ready
    //-----------------------------------------------
    //If stage1 & stage2 are handling same thread, popRdy cannot be set properly
    //So, update it in next cycle.
    for (int i = 0; i < THREAD; i++) begin
        if (!popRdy_r[i] & seqBufRdy_r[i][popSeq_r[i][LOG_SEQBUF-1:0]])
            popRdy[i] = 1;
    end

    //------------------------------------------------
    //Stage 3: Pop sequence buffer
    //------------------------------------------------
    //Read sequence buffer after pop arbiter (assmume pop arbiter without latency)
    seqBuf_radr = popSel * SEQBUF + popSeq_r[popSel][LOG_SEQBUF-1:0];
    {fmode, cidx, pidx, res} = seqBuf_dout;
    //If thread is pop ready and parent output register is empty, write to parent output register.
    if (popVld & popRdy_r[popSel] & ~parentPopRdy_r[pidx]) begin
        parentPopRdy[pidx] = 1;
        parentThread[pidx] = popSel;
        parentChild[pidx] = cidx;
        parentResult[pidx] = res;
        seqBufRdy[popSel][popSeq_r[popSel][LOG_SEQBUF-1:0]] = 0;
        if (fmode) begin
            //If FIFO mode, increase pop sequence.            
            popSeq[popSel] = popSeq_r[popSel] + 1;
            //And, set thread ready if next pop sequence is ready (if needed).
            if (REDUCE_LAT == 1) begin
                popRdy[popSel] = seqBufRdy_r[popSel][popSeq[popSel][LOG_SEQBUF-1:0]];
            end
        end
        else begin
            popRdy[popSel] = 0;
        end
    end

    //-----------------------------------------------
    //Stage 4: Parent pop
    //-----------------------------------------------
    parentPopRdy_o = parentPopRdy_r;
    parentThread_o = parentThread_r;
    parentChild_o = parentChild_r;
    parentResult_o = parentResult_r;
    for (int i = 0; i < PARENT; i = i + 1) begin
        if (parentPopRdy_r[i] & parentPop_i[i]) begin
            parentPopRdy[i] = 0;
        end
    end
end

always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        childRet_r       <= 0;
        childRetParent_r <= '{default:'0};
        childThread_r    <= '{default:'0};
        childSeq_r       <= '{default:'0};
        childMode_r      <= '{default:'0};
        childResult_r    <= '{default:'0};
        parentPopRdy_r   <= 0;
        parentThread_r   <= '{default:'0};
        parentChild_r    <= '{default:'0};
        parentResult_r   <= '{default:'0};
        popSeq_r         <= '{default:'0};
        popRdy_r         <= 0;
        seqBufRdy_r      <= '{default:'0};
        return_error_r   <= 0;
    end
    else begin
        childRet_r       <= childRet;
        childRetParent_r <= childRetParent;
        childThread_r    <= childThread;
        childSeq_r       <= childSeq;
        childMode_r      <= childMode;
        childResult_r    <= childResult;
        parentPopRdy_r   <= parentPopRdy;
        parentThread_r   <= parentThread;
        parentChild_r   <= parentChild;
        parentResult_r   <= parentResult;
        popSeq_r         <= popSeq;
        popRdy_r         <= popRdy;
        seqBufRdy_r      <= seqBufRdy;
        return_error_r   <= return_error;
    end
end

endmodule


module retArb_rr_arbiter #(
    parameter int MUX_NUM = 8,
    parameter     REG_OUT = 1
)
(
    input                                   rstn,
    input                                   clk,
    input           [MUX_NUM-1:0]           sel,
    output logic                            vld_o,
    output logic    [$clog2(MUX_NUM)-1:0]   vldPtr_o
);
    localparam int LOG2_MUX = $clog2(MUX_NUM);

    logic                       vld;
    logic                       vld_r;
    logic [$clog2(MUX_NUM)-1:0] vldPtr;
    logic [$clog2(MUX_NUM)-1:0] vldPtr_r;
    logic [LOG2_MUX:0]          cur_ptr;
    logic [LOG2_MUX-1:0]        rrptr;
    logic [LOG2_MUX-1:0]        rrptr_r;
    logic                       cur_req;

    assign vldPtr = cur_ptr[LOG2_MUX-1:0];

    always_comb begin
        vld = 0;
        cur_ptr = 0;
        rrptr = rrptr_r;
        for (int m=0; m<MUX_NUM; m++) begin
            cur_ptr = m + rrptr_r;
            if (cur_ptr >= MUX_NUM) begin
                cur_ptr -= MUX_NUM;
            end
            if (REG_OUT == 1) begin
                //If output is register, it does not support two successive request
                cur_req = sel[cur_ptr[LOG2_MUX-1:0]] && !(cur_ptr[LOG2_MUX-1:0] == vldPtr_r && vld_r == 1);
            end
            else begin
                cur_req = sel[cur_ptr[LOG2_MUX-1:0]];
            end
            if (cur_req) begin
                vld = 1;
                rrptr = (rrptr_r==(MUX_NUM-1)) ? 0 : (rrptr_r + 1);
                break;
            end
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            rrptr_r  <= 0;
            vld_r    <= 0;
            vldPtr_r <= 0;
        end
        else begin
            rrptr_r  <= rrptr;
            vld_r    <= vld;
            vldPtr_r <= vldPtr;
        end
    end
    
    assign vld_o = (REG_OUT == 1)? vld_r : vld;
    assign vldPtr_o = (REG_OUT == 1)? vldPtr_r : vldPtr;
    
endmodule

