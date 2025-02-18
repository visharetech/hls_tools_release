/*
revoke info structure: {deqFlag, revoke_deqTail, revoke_headPos, revoke_newHead, revoke_deqid}
q0: a --> b --> d
q1: c --> e
revokeInfo = {0, 0}
    qid        locked    valid   head    tail    next
a   q0      0          1       1       0        b
b   q0      0          1       0       0        d
c   q1      0          1       1       0        e
d   q0      0          1       0       1        xxx
e   q1      0          1       0       1        xxx

@c0
action: enqueue q0 and dequeue q0
q0: a* ... b --> d --> f
q1: c --> e
revokeInfo = {{1,0,a,b,q0}, 0}
    qid        locked    valid    head    tail    next
a   q0      1          1       0       0        b
b   q0      0          1       1       0        d
c   q1      0          1       1       0        e
d   q0      0          1       0       0        f
e   q1      0          1       0       1        xxx
f   q0        0        1        0        1        xxx

@c1
action: revoke q0
q0: a -> b --> d --> f
q1: c --> e
revokeInfo = {0, 0}
    qid        locked    valid    head    tail    next
a   q0      0          1       1       0        b
b   q0      0          1       0       0        d
c   q1      0          1       1       0        e
d   q0      0          1       0       0        f
e   q1      0          1       0       1        xxx
f   q0        0        1        0        1        xxx

@c2
dequeue q0
q0: a* ... b --> d --> f
q1: c --> e
revokeInfo = {{1,0,a,b,q0}, 0}
    qid        locked    valid    head    tail    next
a   q0      1          1       0       0        b
b   q0      0          1       1       0        d
c   q1      0          1       1       0        e
d   q0      0          1       0       0        f
e   q1      0          1       0       1        xxx
f   q0        0        1        0        1        xxx

@c3
dequeue q1
q0: a* ... b --> d --> f
q1: c* ... e
revokeInfo = {{1,0,c,e,q1}, {1,0,a,b,q0}}
    qid        locked    valid    head    tail    next
a   q0      1          1       0       0        b
b   q0      0          1       1       0        d
c   q1      1          1       0       0        e
d   q0      0          1       0       0        f
e   q1      0          1       1       1        xxx
f   q0        0        1        0        1        xxx

@c4
revoke2=1
q0: a --> b --> d --> f
q1: c* ... e
revokeInfo = {0, {1,0,c,e,q1}}
    qid        locked    valid    head    tail    next
a   q0      0          1       1       0        b
b   q0      0          1       0       0        d
c   q1      1          1       0       0        e
d   q0      0          1       0       0        f
e   q1      0          1       1       1        xxx
f   q0        0        1        0        1        xxx

@c5
dequeue q1
q0: a --> b --> d --> f
q1: e*
revokeInfo = {{1,1,e,xx,q1}, 0}
    qid        locked    valid    head    tail    next
a   q0      0          1       1       0        b
b   q0      0          1       0       0        d
c   q1      0          0       0       0        e
d   q0      0          1       0       0        f
e   q1      1          1       0       0        xxx
f   q0        0        1        0        1        xxx

@c5
revoke=1 for q1
q0: a --> b --> d --> f
q1: e
revokeInfo = {0, 0}
    qid        locked    valid    head    tail    next
a   q0      0          1       1       0        b
b   q0      0          1       0       0        d
c   q1      0          0       0       0        e
d   q0      0          1       0       0        f
e   q1      0          1       1       1        xxx
f   q0        0        1        0        1        xxx
*/
module linked_fifo #(
    parameter int LEN=64,
    parameter int PAYLOAD = 300, //5(LOG_CHILD) + 6(LOG_PARENT) + 8*32(ARGS) + 32(PC) + 1 (RETVAL)
    parameter int QNUM=64
) (
    input                           rstn,
    input                           clk,
    input                           revoke2,    //#revoke2: cancel the dequeue operation issued in the second-to-last cycle
    input                           enq,
    input                           deq,
    input        [$clog2(QNUM)-1:0] enqid,
    input        [$clog2(QNUM)-1:0] deqid,
    input        [PAYLOAD-1:0]      enqData,
    output logic                    enqRdy_r,
    output logic                    almost_full_r,
    output logic [QNUM-1:0]         deqVld_r,
    output logic                    dataVld,
    output logic [PAYLOAD-1:0]      deqData
);
    localparam PAYLOAD_AW = $clog2(LEN);
    logic    [$clog2(LEN):0] vldCnt;

    // FIFO structure
    logic [LEN-1:0] valid_r, head_r, tail_r, locked_r;
    logic [LEN-1:0] valid,   head,   tail,   locked;
    logic deqTail;
    logic [$clog2(LEN)-1:0] newHead;
    logic [$clog2(LEN)-1:0] next_r[LEN-1:0];
    logic [$clog2(QNUM)-1:0] qid_r[LEN-1:0];
    //logic [PAYLOAD-1:0] payload_r[LEN-1:0];
    logic [QNUM-1:0] deqVld;
    logic foundFree, foundHead, foundTail, foundTail2;
    logic [$clog2(LEN)-1:0] freePos, headPos, tailPos;

    logic                  payload_we;
    logic [PAYLOAD_AW-1:0] payload_wadr;
    logic [PAYLOAD-1:0]    payload_din;
    logic [PAYLOAD_AW-1:0] payload_radr;
    logic [PAYLOAD-1:0]    payload_dout;

    logic [31:0] debug0;
    logic [31:0] debug1;
    logic [31:0] debug2;
    logic [31:0] debug3;
    logic isHeadPos;

    //#revoke2 revoke info structure: {deqFlag, revoke_deqTail, revoke_headPos, revoke_newHead, revoke_deqid}
    reg [1 + 1 + 2*$clog2(LEN) + $clog2(QNUM)-1:0] revokeInfo_r[2], revokeInfo;
    reg deqFlag, revoke_deqTail;
    reg [$clog2(LEN)-1:0] revoke_headPos, revoke_newHead;
    reg [$clog2(QNUM)-1:0] revoke_deqid;

    always @ (posedge clk or negedge rstn) begin
        if (~rstn) begin
            {valid_r, locked_r, head_r, tail_r, enqRdy_r, almost_full_r, deqVld_r, dataVld, deqData} <=0;
            {revokeInfo_r[0], revokeInfo_r[1]}<=0; //#revoke2
            for(int i=0; i<LEN; i++) begin
                qid_r[i]<=0;
                next_r[i]<=0;
            end
        end
        else begin
            //opt payload_radr <= headPos;
            {valid_r, locked_r, head_r, tail_r, deqVld_r} <=
            {valid,   locked,   head,   tail,   deqVld};
            //#revoke2
            revokeInfo_r[0] <= revokeInfo;
            revokeInfo_r[1] <= revokeInfo_r[0];
            if (foundFree) begin
                qid_r[freePos] <= enqid;
                if (foundTail2) begin
                    next_r[tailPos] <= freePos;
                end
            end

            dataVld <= foundHead;
            deqData <= payload_dout;

            enqRdy_r <= (vldCnt<LEN-1);
            almost_full_r <= ((LEN - vldCnt) < 3);
        end
    end

    always @(*) begin
        {foundFree, foundHead, foundTail, foundTail2, freePos, headPos, tailPos, isHeadPos, newHead, deqTail} =0;
        {revokeInfo, deqFlag, revoke_deqTail, revoke_headPos, revoke_newHead, revoke_deqid} = 0; //#revoke2

        {valid, head, tail, deqVld} = {valid_r, head_r, tail_r, deqVld_r};
        {payload_we, payload_wadr, payload_radr} = 0;//opt
        payload_din = enqData;
        locked = locked_r;

// find free ~valid_r
// find head valid_r & head_r
// find tail valid_r & tail_r

        debug0 = 0;
        if (revoke2) begin //#revoke2
            {deqFlag, revoke_deqTail, revoke_headPos, revoke_newHead, revoke_deqid} = revokeInfo_r[1];
            valid[revoke_headPos]   = 1'b1;
            locked[revoke_headPos]  = 1'b0;
            head[revoke_headPos]    = 1'b1;
            tail[revoke_headPos]    = revoke_deqTail;
            deqVld[revoke_deqid]    = 1'b1;
            if (~revoke_deqTail) head[revoke_newHead] = 0;
        end
        else begin
            //#revoke2: Confirm to dequeue 2 cycle after dequeueing, i.e. when revokeInfo_r[1].flag=1, and free the dequeued entry
            {deqFlag, revoke_deqTail, revoke_headPos, revoke_newHead, revoke_deqid} = revokeInfo_r[1];
            if(deqFlag==1 && revoke2==0) begin
                valid[revoke_headPos]=0;
                locked[revoke_headPos]=0;
            end

            if (deq) begin
                for (integer i = 0; i < LEN; i = i + 1) begin
                    //$display("head[i]: %b %b", head[i], head_r[i]);
                    if ((head_r[i]==1'b1) && (qid_r[i]==deqid) && valid_r[i] && locked_r[i]==0) begin //#revoke2
                        foundHead = 1;
                        headPos = i;
                        newHead = next_r[headPos];

                        //revokable operation
                        deqTail = tail_r[headPos];
                        //#revoke2: cannot clear valid[headPos] yet
                        locked[headPos] = 1'b1;
                        head[headPos] = 1'b0;
                        //tail[headPos] = 1'b0;
                        if (tail_r[headPos]==1)    deqVld[deqid]=1'b0;
                        else                     head[next_r[headPos]] = 1'b1;
                        ///////////////////////////////////////////

                        //opt
                        payload_radr = headPos;
                        //$display("Found head at position %d for queue ID %d", headPos, deqid);

                        revokeInfo = {1'b1, tail_r[headPos], headPos, next_r[headPos], deqid};
                    end
                end
            end

            if (enq) begin
                for (int i=LEN-1; i >=0; i--) begin
                    if (valid_r[i]==0) begin
                        debug1 = i;
                        foundFree=1;
                        freePos = i;
                    end
                end

                for (int i=LEN-1; i>=0; i--) begin                //optail
                    if (valid_r[i]==1 && tail_r[i]==1 && qid_r[i]==enqid) begin
                        foundTail = 1;
                        foundTail2 = 1;
                        tailPos = i;
                        //$display("tailPos=%d", tailPos);
                    end
                end

                // reset foundTail to '0' if enqeueu and dequeue the same queue with one entry
                if (enqid==deqid && deq==1 && head_r[tailPos]==tail_r[tailPos]) begin
                    foundTail = 0;
                    deqTail = 0;
                    newHead = freePos;
                    revokeInfo = {1'b1, 1'b0, headPos, newHead, deqid};
                end

                if (foundFree) begin
                    payload_wadr = freePos;
                    payload_we = 1;
                    valid[freePos] = 1'b1;
                    locked[freePos] = 1'b0; //#revoke2
                    deqVld[enqid] = 1'b1;
                end
                else begin
                    $display("Can't find free");
                        $finish;
                end

                //if (foundFree) begin
                //    tail[freePos] = 1'b1;
                //end
                if (foundTail)     begin
                    //tail[tailPos] = 1'b0;
                    head[freePos] = 1'b0;
                end
                else begin
                    head[freePos] = 1'b1;
                end
                //if (foundFree==1 && clk==0) $display("Found free position at %d for enqueue ID %d valid=%b head=%b tail=%b", freePos, enqid, valid, head, tail);
            end
        end

        if (foundHead) begin
            tail[headPos] = 1'b0;
        end
        if (foundFree) begin
            tail[freePos] = 1'b1;
        end
        if (foundTail)     begin
            tail[tailPos] = 1'b0;
        end



        vldCnt=0;
        for(int i=0; i<LEN; i=i+1) begin
            if (valid[i]==1) vldCnt=vldCnt+1;
        end

    end

    dpram #(
        .aw (PAYLOAD_AW),
        .dw (PAYLOAD),
        .max_size (LEN),
        .rd_lat (0) //opt
   ) payload_mem(
        .rd_clk     (clk),
        .raddr      (payload_radr),
        .dout       (payload_dout),
        .wr_clk     (clk),
        .we         (payload_we),
        .din        (payload_din),
        .waddr      (payload_wadr)
   );
endmodule

