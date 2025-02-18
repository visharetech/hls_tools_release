/*
mq_rrpop_fifo is a fifo shared by multiple queues. Only one producer can push data at a time but Q consumers can set pop bit simultaneously to get output via Q popData ports. Different queues share the internal block ram and the internal storage of the blockram is divided equally for each queue.
For each queue with non-empty fifo and empty popData register, a round robin scheduler select one of the queue q0 to pop data and store the memory output in popData[q0].
*/

module mq_rrpop_fifo #(
    parameter int Q=4,
    parameter int D=16,
    parameter int W=32
)(
    input                           rstn,
    input                           clk,
    // push
    output logic [Q-1:0]            queue_full,
    input                           push,
    input        [$clog2(Q)-1:0]    pushq,
    input        [W-1:0]            pushDat,
    // pop
    output logic [Q-1:0]            popRdy,
    input        [Q-1:0]            pop,
    output logic [W-1:0]            popData [Q]
);

// Q: number of queues; D: depth of each FIFO; W: data width
// ports definition
// queue_full[q] indicate if FIFO q is queue_full; is queue_full and `empty_r` for each queue indicating if they are empty.
// Registers `rrPtr_r` and `rrPtr` are used to manage the round-robin selection of queues.
    localparam int LOG_Q = $clog2(Q);
    localparam int LOG_D = $clog2(D);
    localparam int DEPTH = Q*D;
    localparam int AW = $clog2(DEPTH);
    logic [LOG_Q-1:0]   rrPtr_r;
    logic [LOG_Q-1:0]   rrPtr;
    logic [LOG_Q-1:0]   pop_queue, pop_queue_r;
    logic               internal_pop, internal_pop_r;
    logic [Q-1:0]       popBuf_empty, popBuf_empty_r;
    logic [LOG_D-1:0]   rdPtr[Q], rdPtr_r[Q];
    logic [LOG_D-1:0]   wrPtr[Q], wrPtr_r[Q];
    logic [LOG_D:0]     num[Q], num_r[Q];
    logic [Q-1:0]       queue_empty;
    logic [AW-1:0]      radr;
    logic [AW-1:0]      wadr;
    logic               wr;
    logic [W-1:0]       dout;

    dpram  #(
        .usr_ram_style  ("block"),
        .aw             (AW),
        .dw             (W),
        .max_size       (DEPTH),
        .rd_lat         (1)
    )dpram_u0(
        .rd_clk (clk),
        .raddr  (radr),
        .dout   (dout),
        .wr_clk (clk),
        .we     (wr),
        .din    (pushDat),
        .waddr  (wadr)
    );

    always_ff @(posedge clk or negedge rstn) begin
        if(~rstn) begin
            rrPtr_r <= 0;
            rdPtr_r <= '{default: 0};
            wrPtr_r <= '{default: 0};
            num_r <=  '{default: 0};
            internal_pop_r <= 0;
            pop_queue_r <= 0;
            popBuf_empty_r <= -1;
        end else begin
            rrPtr_r <= rrPtr;
            rdPtr_r <= rdPtr;
            wrPtr_r <= wrPtr;
            num_r <= num;
            internal_pop_r <= internal_pop;
            popBuf_empty_r <= popBuf_empty;
            pop_queue_r <= pop_queue;
            if (internal_pop_r) begin
                popData[pop_queue_r] <= dout;
            end
        end
    end

    always_comb begin
        popRdy = ~popBuf_empty_r;

        wrPtr = wrPtr_r;
        num = num_r;
        wadr = 0;
        wr = 0;
        if(push & ~queue_full[pushq]) begin
            wadr = pushq*D + wrPtr_r[pushq];
            num[pushq] = num_r[pushq] + 1;
            wrPtr[pushq] = wrPtr_r[pushq] + 1;
            wr = 1;
        end

        popBuf_empty = popBuf_empty_r ;
        for (int q = 0; q < Q; q++) begin
            if (pop[q] && !popBuf_empty_r[q]) begin
                popBuf_empty[q] = 1;
            end
        end
        if (internal_pop_r) begin
            popBuf_empty[pop_queue_r] = 0;
        end

        // round robin select a queue to pop
        rdPtr = rdPtr_r;
        rrPtr = rrPtr_r;
        internal_pop = 0;
        pop_queue = 0;
        radr = 0;
        for (int i = 0; i < Q; i++) begin
            int q;
            q = (i + rrPtr_r);
            if (q >= Q) begin
                q -= Q;
            end
            if (popBuf_empty_r[q] && !queue_empty[q]) begin
                internal_pop = 1;
                radr = q*D + rdPtr_r[q];
                num[q] = num[q] - 1; // has to use num[rdPtr_r] instead of num_r[q] since q may equal to pushq
                pop_queue = q;
                rrPtr = q + 1;
                rdPtr[q] = rdPtr_r[q] + 1;
                break;
            end
        end
    end

    always_comb begin
        queue_empty = -1;
        queue_full = 0;
        for (int q=0; q<Q; q++) begin
            queue_empty[q] = (num_r[q]==0);
            queue_full[q] = (num_r[q]==D);
        end
    end

endmodule


