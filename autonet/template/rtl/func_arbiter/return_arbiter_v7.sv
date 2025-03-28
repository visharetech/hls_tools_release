import func_arbiter_pkg::*;
module return_arbiter#(
    parameter int THREAD = 4,
    parameter int PARENT = 32,
    parameter int CHILD = 64,
    parameter int LOG_THREAD = (THREAD==1) ? 1 : $clog2(THREAD),
    parameter int LOG_PARENT = (PARENT==1) ? 1 : $clog2(PARENT),
    parameter int LOG_CHILD = (CHILD==1) ? 1 : $clog2(PARENT),
    parameter int FULL_RET_DW = RET_DW + LOG_CHILD
) (
    input                                   rstn,
    input                                   clk,

    // from call arb
    output logic [PARENT-1:0]               clrParentCall,
    input        [PARENT-1:0]               parentCall,
    input        [LOG_CHILD-1:0]            call_child[PARENT],
    input        [LOG_THREAD-1:0]           call_thread[PARENT],

    output logic [1:0]                      popStatus,

    // from child
    output logic                            child_retRdy_o[CHILD],
    input                                   child_retVld_i[CHILD],
    input        [31:0]                     child_retDin_i[CHILD],
    input        [LOG_THREAD-1:0]           child_retThread_i[CHILD],
    input        [LOG_PARENT-1:0]           child_parentMod_i[CHILD],

    // to parent
    input        [PARENT-1:0]               parent_retFifo_pop_i,
    output logic [PARENT-1:0]               parent_retFifo_empty_n_o,
    output logic [FULL_RET_DW-1:0]          parent_retFifo_dout_o[PARENT]
);

    typedef enum logic [1:0] {
        WAITING     = 'd0,
        POP_FAIL    = 'd1,
        POP_READY   = 'd2,
        DONE        = 'd3
    } popStatus_t;

    typedef enum logic [31:0]{
        NEXT_CALL  = 0,
        FIRST_CALL = CHILD * THREAD,
        LAST_CALL  = CHILD * THREAD + PARENT
    } callAdr_t;

    typedef enum logic [2:0]{
        READY   = 'd0,
        CALL1   = 'd1,
        CALL2   = 'd2,
        EXE1    = 'd3,
        POP1    = 'd4,
        POP2    = 'd5,
        POP3    = 'd6
    } state_t;
    state_t state, state_r;

    //NEXT_CALL segemnt used child_thread as address
    //FIRST and LAST segments used parent as address
    localparam CALL_MEM_DEPTH = (CHILD*THREAD) + 2*PARENT;
    localparam CALL_MEM_AW = $clog2(CALL_MEM_DEPTH);

    logic [PARENT-1:0]                  returnRdy, returnRdy_r;
    logic                               callWe, callRe, resultWe, resultRe;
    logic [CALL_MEM_AW-1:0]             callAdr;
    logic [LOG_CHILD+LOG_THREAD-1:0]    callWdat, callRdat;
    logic [LOG_CHILD+LOG_THREAD-1:0]    resultAdr;
    logic [32:0]                        resultWdat, resultRdat;
    reg   [PARENT-1:0]                  callFlag, callFlag_r;
    logic [LOG_CHILD+LOG_THREAD-1:0]    first_child_thread, first_child_thread_r;
    logic [LOG_CHILD+LOG_THREAD-1:0]    next_child_thread, next_child_thread_r;
    logic [LOG_CHILD+LOG_THREAD-1:0]    call_child_thread, last_child_thread;

    logic [LOG_PARENT-1:0]              call_parent_w, call_parent_r;
    logic [LOG_CHILD-1:0]               call_child_w, call_child_r;
    logic [LOG_THREAD-1:0]              call_thread_w, call_thread_r;

    logic [CHILD-1:0]                   clrRetVld;
    logic [LOG_THREAD-1:0]              retThread[CHILD], retThread_r[CHILD];
    logic [LOG_PARENT-1:0]              retParent[CHILD], retParent_r[CHILD];
    logic [31:0]                        retDin[CHILD], retDin_r[CHILD];
    logic [CHILD-1:0]                   retVld, retVld_r;

    logic [LOG_CHILD-1:0]               cur_child, cur_child_r;
    logic                               childDone, childDone_r;
    logic                               clrChildDone;
    logic [LOG_PARENT-1:0]              ret_parent, ret_parent_r;
    logic [LOG_CHILD-1:0]               ret_child, ret_child_r;
    logic [LOG_THREAD-1:0]              ret_thread, ret_thread_r;
    logic [31:0]                        ret_din;

    logic [LOG_PARENT-1:0]              pop_parent, pop_parent_r;

    logic [PARENT-1:0]                  parent_retFifo_empty_n;
    logic [FULL_RET_DW-1:0]             parent_retFifo_dout[PARENT];

    logic [LOG_PARENT-1:0]              cur_call_parent, cur_call_parent_r;
    logic [LOG_PARENT-1:0]              cur_pop_parent, cur_pop_parent_r;

    logic                               parentCall_w, parentCall_r;
    logic                               parentPop, parentPop_r;
    logic                               ena;
    logic [PARENT-1:0]                  pop_rrarb_sel;

    logic [$clog2(CHILD*THREAD)-1:0]    init_cnt, init_cnt_r;
    logic                               init_done, init_done_r;

    //input buffer for return requests
    always_comb begin
        retDin = retDin_r;
        retVld = retVld_r;
        retParent = retParent_r;
        retThread = retThread_r;
        for (int c=0; c<CHILD; c++) begin
            child_retRdy_o[c] = ~retVld_r[c] & init_done_r;
            if (~retVld_r[c] && child_retVld_i[c]) begin
                retDin[c] = child_retDin_i[c];
                retThread[c] = child_retThread_i[c];
                retParent[c] = child_parentMod_i[c];
                retVld[c] = 1;
            end
            else if (clrRetVld[c]) begin
                retVld[c] = 0;
            end
        end
    end

    assign rrarb_ena = (state_r==READY) ? 1 : 0;

    rr_arbiter #(.MUX_NUM(PARENT)) call_rrarb (
        .rstn   (rstn),
        .clk    (clk),
        .ena    (rrarb_ena),
        .sel    (parentCall),
        .vld    (parentCall_w),
        .vldPtr (cur_call_parent)
    );

    rr_arbiter #(.MUX_NUM(CHILD)) child_done_rrarb (
        .rstn   (rstn),
        .clk    (clk),
        .ena    (rrarb_ena),
        .sel    (retVld_r),
        .vld    (childDone),
        .vldPtr (cur_child)
    );

    assign pop_rrarb_sel = ~parent_retFifo_empty_n_o & returnRdy_r;
    rr_arbiter #(.MUX_NUM(PARENT)) pop_rrarb (
        .rstn   (rstn),
        .clk    (clk),
        .ena    (rrarb_ena),
        .sel    (pop_rrarb_sel),
        .vld    (parentPop),
        .vldPtr (cur_pop_parent)
    );

    /*
    state machine
        READY:
            - if parentCall,
                - if callFlag[parent]==0,
                    - callFlag[parent]=1
                    - write firstCall[parent]=call_child_thread then goto CALL2
                else read lastCall[parent]=call_child_thread
            - if childDone,
                - read first_child_thread=firstCall[returnParent]
                - write childThreadDone[exe_child_thread] = true
                - write result[exe_child_thread] = result_i
                - goto EXE1
            - if pop,
                - read first_child_thread = firstCall[parent]; goto POP1
            - else goto READY

        CALL1: write nextCall[last_child_thread]=call_child_thread; goto CALL1S

        CALL2: write lastCall[parent]=call_child_thread

        EXE1:
            returnRdy[returnParent] = (ret_child_thread == exe_child_thread);

        POP1:
            - read {isDone, _result} = result[first_child_thread];
            - read next_call_thread = nextCall[first_child_thread];
        POP2:
            if(isDone)
                - next_call_thread = callRdat
                - read isNextDone = childThreadDone[next_call_thread]
                - read last_child_thread = lastCall[parent]
            else goto READY and also report error
        POP3:
            - write firstCall[parent] = next_call_thread_r
            - write result[first_child_thread_r] = 0
            - if(first_child_thread == last_child_thread) callFlag[parent] = false
            - returnRdy[parent] = isNextDone

    */
    always @ (*) begin
        //child = child_r;
        //thread = thread_r;
        //parent = parent_r;
        //child_o = 0;
        //thread_o = 0;
        popStatus = WAITING;
        callWe = 0;
        callRe = 0;
        resultWe = 0;
        resultRe = 0;
        callAdr = 0;
        callWdat = 0;
        resultAdr = 0;
        resultWdat = 0;
        returnRdy = returnRdy_r;
        callFlag = callFlag_r;
        first_child_thread = first_child_thread_r;
        next_child_thread = next_child_thread_r;
        call_child_thread = 0;
        last_child_thread = 0;
        state = state_r;
        clrChildDone = 0;

        init_cnt = init_cnt_r;
        init_done = init_done_r;

        parent_retFifo_empty_n = parent_retFifo_empty_n_o;
        parent_retFifo_dout = parent_retFifo_dout_o;
        for (int p=0; p<PARENT; p++) begin
            if (parent_retFifo_pop_i[p] && parent_retFifo_empty_n_o[p]) begin
                parent_retFifo_empty_n[p] = 0;
                parent_retFifo_dout[p] = 0;
            end
        end

        ret_parent = ret_parent_r;
        ret_child = ret_child_r;
        ret_thread = ret_thread_r;
        ret_din = 0;
        clrRetVld = 0;


        clrParentCall = 0;
        call_parent_w = call_parent_r;
        call_child_w = call_child_r;
        call_thread_w = call_thread_r;

        pop_parent = pop_parent_r;
        case(state_r)
            READY: begin
                if (~init_done_r) begin
                    callWe = 1;
                    callAdr = NEXT_CALL + init_cnt_r;
                    callWdat = -1;

                    resultWe = 1;
                    resultAdr = init_cnt_r;
                    resultWdat = 0;

                    if (init_cnt_r==(THREAD*CHILD - 1)) begin
                        init_done = 1;
                    end
                    else begin
                        init_cnt = init_cnt_r + 1;
                    end
                end
                else if (parentCall_r) begin
                    clrParentCall[cur_call_parent_r] = 1;
                    call_parent_w = cur_call_parent_r;
                    call_child_w = call_child[cur_call_parent_r];
                    call_thread_w = call_thread[cur_call_parent_r];

                    call_child_thread = {call_child_w, call_thread_w};
                    if (callFlag_r[cur_call_parent_r] == 0) begin
                        callFlag[cur_call_parent_r] = 1;
                        // write firstCall[parent] = call_child_thread;
                        callWe = 1;
                        callAdr = FIRST_CALL + cur_call_parent_r;
                        callWdat = call_child_thread;
                        state = CALL2;
                    end
                    else begin
                        // read lastCall[parent]
                        callRe = 1;
                        callAdr = LAST_CALL + cur_call_parent_r;
                        state = CALL1;
                    end
                end
                else if (childDone_r) begin
                    clrRetVld[cur_child_r] = 1;
                    ret_parent = retParent_r[cur_child_r];
                    ret_child = cur_child_r;
                    ret_thread = retThread_r[cur_child_r];
                    ret_din = retDin_r[cur_child_r];

                    // read ret_child_thread=firstCall[returnParent]
                    callRe = 1;
                    callAdr = FIRST_CALL + ret_parent;
                    // write childThreadDone[exe_child_thread] = true
                    // write result[exe_child_thread] = result_i;
                    resultWe = 1;
                    resultAdr = {ret_child, ret_thread};
                    resultWdat = {1'b1, ret_din};
                    state = EXE1;
                end
                else if (parentPop_r) begin
                    returnRdy[cur_pop_parent_r] = 0;
                    pop_parent = cur_pop_parent_r;

                    //read first_child_thread = firstCall[parent];
                    callRe = 1;
                    callAdr = FIRST_CALL + cur_pop_parent_r;
                    state = POP1;
                end
            end

            CALL1: begin
                // write nextCall[last_child_thread]=call_child_thread;
                state = CALL2;
                callWe = 1;
                callWdat = {call_child_r, call_thread_r};
                callAdr = NEXT_CALL + callRdat;
            end

            CALL2: begin
                //lastCall[parent] = index;
                callWe = 1;
                callAdr = LAST_CALL + call_parent_r;
                callWdat = {call_child_r, call_thread_r};
                state = READY;
            end

            EXE1: begin
                clrChildDone = 1;
                first_child_thread = callRdat;
                if (~returnRdy_r[ret_parent_r]) begin
                    returnRdy[ret_parent_r] = (first_child_thread == {ret_child_r, ret_thread_r});
                end
                state = READY;
            end

            POP1: begin
                first_child_thread = callRdat;
                // read {isDone, _result} = result[first_child_thread];
                resultRe = 1;
                resultAdr = first_child_thread;
                // read next_call_thread = nextCall[first_child_thread];
                callRe = 1;
                callAdr = NEXT_CALL + first_child_thread;
                state = POP2;
            end

            POP2: begin
                if (resultRdat[32]) begin //done=1
                    parent_retFifo_empty_n[pop_parent_r] = 1;
                    parent_retFifo_dout[pop_parent_r] = {first_child_thread_r[LOG_CHILD+LOG_THREAD-1:LOG_THREAD], resultRdat[31:0]};

                    next_child_thread = callRdat;
                    // read isNextDone = childThreadDone[next_child_thread]
                    resultRe = 1;
                    resultAdr = next_child_thread;
                    // read last_child_thread = lastCall[parent]
                    callRe = 1;
                    callAdr = LAST_CALL + pop_parent_r;
                    state = POP3;
                end
                else begin
                    popStatus = POP_FAIL;
                    state = READY;
                end
            end

            POP3: begin
                /*
                - write firstCall[parent] = next_call_thread_r
                - write result[first_child_thread_r] = 0
                - if(first_child_thread == last_child_thread) callFlag[parent] = false
                - returnRdy[parent] = isNextDone
                */
                popStatus = READY;
                last_child_thread = callRdat;
                // firstCall[parent] = next_call_thread_r
                callWe = 1;
                callAdr = FIRST_CALL + pop_parent_r;
                callWdat = next_child_thread_r;
                // write childThreadDone[first_child_thread] = false
                resultWe = 1;
                resultAdr = first_child_thread_r;
                resultWdat = 33'b0;
                //
                if(first_child_thread_r == last_child_thread) begin
                    callFlag[pop_parent_r] = 0;
                end
                else begin
                    returnRdy[pop_parent_r] = resultRdat[32];
                end
                state = READY;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            state_r <= READY;
            callFlag_r <= 0;
            first_child_thread_r <= 0;
            next_child_thread_r <= 0;
            returnRdy_r <= 0;

            parentCall_r <= 0;
            cur_call_parent_r <= 0;
            call_parent_r   <= 0;
            call_child_r    <= 0;
            call_thread_r   <= 0;

            retDin_r <= '{default: '0};
            retVld_r <= 0;
            retParent_r <= '{default: '0};
            retThread_r <= '{default: '0};

            childDone_r <= 0;
            cur_child_r <= 0;
            ret_parent_r <= 0;
            ret_child_r <= 0;
            ret_thread_r <= 0;

            parentPop_r <= 0;
            cur_pop_parent_r <= 0;

            parent_retFifo_empty_n_o <= 0;
            parent_retFifo_dout_o <= '{default: 0};

            pop_parent_r <= 0;

            init_cnt_r <= 0;
            init_done_r <= 0;
        end else begin
            state_r <= state;
            callFlag_r <= callFlag;
            first_child_thread_r <= first_child_thread;
            next_child_thread_r <= next_child_thread;
            returnRdy_r <= returnRdy;

            parentCall_r    <= parentCall_w;
            cur_call_parent_r <= cur_call_parent;
            call_parent_r   <= call_parent_w;
            call_child_r    <= call_child_w;
            call_thread_r   <= call_thread_w;

            retDin_r <= retDin;
            retVld_r <= retVld;
            retParent_r <= retParent;
            retThread_r <= retThread;

            childDone_r <= childDone;
            cur_child_r <= cur_child;
            ret_parent_r <= ret_parent;
            ret_child_r <= ret_child;
            ret_thread_r <= ret_thread;

            parentPop_r <= parentPop;
            cur_pop_parent_r <= cur_pop_parent;

            parent_retFifo_empty_n_o <= parent_retFifo_empty_n;
            parent_retFifo_dout_o <= parent_retFifo_dout;

            pop_parent_r <= pop_parent;

            init_cnt_r <= init_cnt;
            init_done_r <= init_done;

        end
    end

    sp_ram #(
        .ADR        (CALL_MEM_AW),
        .DATA       (LOG_CHILD+LOG_THREAD)
    ) callMem(
        .clk    (clk),
        .we     (callWe),
        .re     (callRe),
        .adr    (callAdr),
        .wdat   (callWdat),
        .rdat   (callRdat)
    );

    sp_ram #(
        .ADR        (LOG_CHILD+LOG_THREAD),
        .DATA       (33)
    ) resultMem(
        .clk    (clk),
        .we     (resultWe),
        .re     (resultRe),
        .adr    (resultAdr),
        .wdat   (resultWdat),
        .rdat   (resultRdat)
    );

endmodule

module sp_ram #(
    parameter int       ADR = 8,
    parameter int       DATA = 32
) (
    input                   clk,
    input                   we,
    input                   re,
    input       [ADR-1:0]   adr,
    input       [DATA-1:0]  wdat,
    output reg  [DATA-1:0]  rdat
);
    localparam int DEPTH = (1 << ADR);
    (* ram_style = "block" *) logic [DATA-1:0] mem [DEPTH];// = '{default: 0};
    always @(posedge clk) begin
        if (we) begin
            mem[adr] <= wdat;
        end
        else if (re) begin
            rdat <= mem[adr];
        end
    end
endmodule


module rr_arbiter #(parameter int MUX_NUM = 8)
(
    input                                   rstn,
    input                                   clk,
    input                                   ena,
    input           [MUX_NUM-1:0]           sel,
    output logic                            vld,
    output logic    [$clog2(MUX_NUM)-1:0]   vldPtr
);
    localparam int LOG2_MUX = $clog2(MUX_NUM);

    logic [LOG2_MUX:0]      cur_ptr;
    logic [LOG2_MUX-1:0]    rrptr, rrptr_r;

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
            if (sel[cur_ptr] && ena) begin
                vld = 1;
                rrptr = (rrptr_r==(MUX_NUM-1)) ? 0 : (rrptr_r + 1);
                break;
            end
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            rrptr_r <= 0;
        end
        else begin
            rrptr_r <= rrptr;
        end
    end
endmodule

