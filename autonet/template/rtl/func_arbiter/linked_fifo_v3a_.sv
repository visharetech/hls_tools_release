/*

Given a multi-queue FIFO implemented with multiple linked lists.


q0: a --> b --> d
q1: c --> e
    qid        valid    head    tail    next
a     q0        1        1        0        b
b     q0        1        0        0        d
c     q1        1        1        0        e
d     q0        1        0        1        xxx
e     q1        1        0        1        xxx

c0: enqueue q0 and dequeue q0 --> a
q0: (a -->) b --> d --> f
q1: c --> e

    qid        valid    head    tail    next
a     q0        0        0        0        b
b     q0        1        1        0        d
c     q1        1        1        0        e
d     q0        1        0        0        xxx
e     q1        1        0        0        f
f    q0        1        0        1        xxx

c1: revoke and enqueue q0
q0: a --> b --> d --> f --> g
q1: c --> e
    qid        valid    head    tail    next
a     q0        1        1        0        b
b     q0        1        0        0        d
c     q1        1        1        0        e
d     q0        1        0        0        xxx
e     q1        1        0        0        f
f    q0        1        0        0        g
g     q0        1        0        1        xxx

c2: dequeue q1 --> c
q0: a --> b --> d --> f --> g
q1: (c -->) e
    qid        valid    head    tail    next
a     q0        1        1        0        b
b     q0        1        0        0        d
c     q1        0        0        0        e
d     q0        1        0        0        xxx
e     q1        1        0        0        f
f    q0        1        1        1        xxx
g     q0        1        0        1        xxx

c3: dequeue q1 --> e
q0: a --> b --> d --> f --> g
q1: (e)
    qid        valid    head    tail    next
a     q0        1        1        0        b
b     q0        1        0        0        d
c     q1        0        0        0        e
d     q0        1        0        0        xxx
e     q1        0        0        0        f
f    q0        1        1        1        xxx
g     q0        1        0        1        xxx

c4: dequeue q0 --> a
q0: (a -->) b --> d --> f --> g
q1:
    qid        valid    head    tail    next
a     q0        0        0        0        b
b     q0        1        1        0        d
c     q1        0        0        0        e
d     q0        1        0        0        xxx
e     q1        0        0        0        f
f    q0        1        1        1        xxx
g     q0        1        0        1        xxx

*/
module linked_fifo #(
    parameter int LEN=8,
    parameter int PAYLOAD = 32,
    parameter int QNUM=16
) (
    input                           rstn,
    input                           clk,
    input                           revoke,    // cancel the dequeue operation issued in the last cycle
    input                           enq,
    input                           deq,
    input        [$clog2(QNUM)-1:0] enqid,
    input        [$clog2(QNUM)-1:0] deqid,
    input        [PAYLOAD-1:0]      enqData,
    output logic                    enqRdy_r,
    output logic [QNUM-1:0]         deqVld_r,
    output logic                    dataVld,
    output logic [PAYLOAD-1:0]      deqData
);
    localparam PAYLOAD_AW = $clog2(LEN);
    logic    [$clog2(LEN):0] vldCnt;

    // FIFO structure
    logic [LEN-1:0] valid_r, head_r, tail_r;
    logic [LEN-1:0] valid,   head,   tail;
    logic deqTail, deqTail_r;
    logic [$clog2(LEN)-1:0] newHead, newHead_r;
    logic [$clog2(LEN)-1:0] next_r[LEN-1:0];
    logic [$clog2(QNUM)-1:0] qid_r[LEN-1:0];
    //logic [PAYLOAD-1:0] payload_r[LEN-1:0];
    logic [QNUM-1:0] deqVld;
    logic foundFree, foundHead, foundTail, foundTail2;
    logic [$clog2(LEN)-1:0] freePos, headPos, headPos_r, tailPos;
    logic [$clog2(QNUM)-1:0] deqid_r;

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

    always @ (posedge clk or negedge rstn) begin
        if (~rstn) begin
            {valid_r, head_r, tail_r, enqRdy_r, deqVld_r, dataVld, deqTail_r, newHead_r, headPos_r, deqid_r} <=0;
            for(int i=0; i<LEN; i++) begin
                qid_r[i]<=0;
                next_r[i]<=0;
                //payload_r[i]<=0;
            end
            //$display("FIFO reset");
            //opt payload_radr <= 0;
        end
        else begin
            //opt payload_radr <= headPos;
            {valid_r, head_r, tail_r, deqVld_r, deqTail_r, newHead_r, headPos_r, deqid_r} <= {valid, head, tail, deqVld, deqTail, newHead, headPos, deqid};
            if (foundFree) begin
                qid_r[freePos] <= enqid;
                //payload_r[freePos] <= enqData;
                if (foundTail2) begin
                    next_r[tailPos] <= freePos;
                end
                //$display("Enqueued data: %d at position %d for queue ID %d", enqData, freePos, enqid);
            end

            dataVld <= foundHead;
            if (foundHead) begin
                //deqData <= payload_r[headPos];
                deqData <= payload_dout;
            end

            enqRdy_r <= (vldCnt<LEN-1);
        end
    end

    always @(*) begin
        {foundFree, foundHead, foundTail, foundTail2, freePos, headPos, tailPos, isHeadPos, newHead, deqTail} =0;
        {valid, head, tail, deqVld} = {valid_r, head_r, tail_r, deqVld_r};
        {payload_we, payload_wadr, payload_radr} = 0;//opt
        payload_din = enqData;

// find free ~valid_r
// find head valid_r & head_r
// find tail valid_r & tail_r

        debug0 = 0;
        if (revoke) begin
            valid[headPos_r] = 1'b1;
            head[headPos_r] = 1'b1;
            tail[headPos_r] = deqTail_r;
            deqVld[deqid_r] = 1'b1;
            if (~deqTail_r) head[newHead_r] = 0;
        end
        else begin
            if (deq) begin
                for (integer i = 0; i < LEN; i = i + 1) begin
                    //$display("head[i]: %b %b", head[i], head_r[i]);
                    if ((head_r[i]==1'b1) && (qid_r[i]==deqid) && valid_r[i]) begin
                        foundHead = 1;
                        headPos = i;
                        newHead = next_r[headPos];

                        //revokable operation
                        deqTail = tail_r[headPos];
                        valid[headPos]= 1'b0;
                        head[headPos] = 1'b0;
                        tail[headPos] = 1'b0;
                        if (tail_r[headPos]==1)    deqVld[deqid]=1'b0;
                        else                     head[next_r[headPos]] = 1'b1;
                        ///////////////////////////////////////////

                        //opt
                        payload_radr = headPos;
                        //$display("Found head at position %d for queue ID %d", headPos, deqid);
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
                end

                if (foundFree) begin
                    payload_wadr = freePos;
                    payload_we = 1;
                    valid[freePos] = 1'b1;
                    deqVld[enqid] = 1'b1;
                end
                else begin
                    $display("Can't find free");
                        $finish;
                end

                if (foundFree) begin
                    tail[freePos] = 1'b1;
                end
                if (foundTail)     begin
                    tail[tailPos] = 1'b0;
                    head[freePos] = 1'b0;
                end
                else begin
                    head[freePos] = 1'b1;
                end
                //if (foundFree==1 && clk==0) $display("Found free position at %d for enqueue ID %d valid=%b head=%b tail=%b", freePos, enqid, valid, head, tail);
            end
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

