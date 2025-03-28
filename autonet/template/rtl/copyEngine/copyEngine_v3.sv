/*
            cmd_reception
                |
    -----------------------
    |                     |
mem_read                 mem_write
    |                     ^
    v                     |
    ----->rdfifo--->alignBuf_r

Cycles info at aligned read and write address and bweMemLat=2
_____________________________________________________
Signal       | C0 | C1 | C2 | C3 | C4 | C5 | C6 | C7 |
copy_i       | 1  |    |    |    |    |    |    |    |
mem_re       |    | 1  |    |    |    |    |    |    |
mem_re_r     |    |    | 1  |    |    |    |    |    |
mem_rdat_rdy |    |    |    |    | 1  |    |    |    |
rdfifo_we    |    |    |    |    | 1  |    |    |    |
rdfifo_rrdy  |    |    |    |    |    | 1  |    |    |
rdfifo_re    |    |    |    |    |    | 1  |    |    |
alignBuf     |    |    |    |    |    |    | V  |    |
bufNum_r     |    |    |    |    |    |    | 4  |    |
mem_bwe      |    |    |    |    |    |    | 1  |    |
mem_bwe_r    |    |    |    |    |    |    |    | 1  |
______________________________________________________

- if 32b to 64b, copy engine insert '0' to odd byte to dest mem, i.e. 3210 --> 03020100
- if 64b to 32b, copy engine discard odd byte from source mem, i.e. 76543210 --> 6420

at CONV_32_64     = 1, DATA_WIDTH should be 64
possible combinations of the src_dw_sel_i / dst_dw_sel_i
src_dw_sel_i=0, dst_dw_sel_i=0: copy or set 32-bit data
src_dw_sel_i=0, dst_dw_sel_i=1: src - 32 bit dst - 64 bit, bytes 0, 2, 4 are from src data, bytes 1, 3, 5, .. are 0
src_dw_sel_i=1, dst_dw_sel_i=0: src - 64 bit dst - 32 bit, src bytes 0, 2, 4 issued to dst memory

at CONV_32_64     = 0, DATA_WIDTH can be 64 or 32
possible combinations of the src_dw_sel_i / dst_dw_sel_i
src_dw_sel_i=0, dst_dw_sel_i=0: copy or set 32-bit data
src_dw_sel_i=1, dst_dw_sel_i=1: copy or set 64-bit data

*/

module copyEngine_v3  #(
    parameter WDATA_WIDTH    = 64,
    parameter RDATA_WIDTH    = 64,
    parameter ADDR_WIDTH     = 32,
    parameter LEN            = 16,
    parameter CONV_32_64     = 1
) (
    input                             rstn,
    input                             clk,

    // param input
    input                             src_dw_sel_i,//0-32, 1-64
    input                             dst_dw_sel_i,//0-32, 1-64
    input                             copy_i,
    input                             set_i,
    input        [7:0]                setVal_i,
    input                             flush_i,
    input                             stop_i,
    input        [LEN-1:0]            len_i,
    input        [ADDR_WIDTH-1:0]     src_i,
    input        [ADDR_WIDTH-1:0]     dst_i,
    output logic                      done_o,

    // memory ports
    //Memory read
    output logic                      mem_re_r,
    output logic [ADDR_WIDTH-1:0]     mem_rad_r,
    input                             mem_rreq_rdy,
    input        [RDATA_WIDTH-1:0]    mem_rdat,
    input                             mem_rdat_rdy,
    output logic                      rdfifo_full_n,

    //Memory write
    output logic [WDATA_WIDTH/8-1:0]  mem_bwe_r,
    output logic [ADDR_WIDTH-1:0]     mem_wad_r,
    output logic [WDATA_WIDTH-1:0]    mem_wdat_r,
    input                             mem_wreq_rdy,
    output logic                      stop_axi4_r,

    output logic                      flush_r,
    output logic [ADDR_WIDTH-1:0]     cmd_adr_r,
    input                             cmd_rdy
);
    localparam int FULL_WWORD_SIZE = WDATA_WIDTH / 8;
    localparam int FULL_RWORD_SIZE = RDATA_WIDTH / 8;
    localparam int WWORD_SIZE = (CONV_32_64==1) ? (FULL_WWORD_SIZE / 2) : FULL_WWORD_SIZE;
    localparam int RWORD_SIZE = (CONV_32_64==1) ? (FULL_RWORD_SIZE / 2) : FULL_RWORD_SIZE;
    localparam int RD_FIFO_DW = (CONV_32_64==1) ? 32 : RDATA_WIDTH;
    localparam int RD_FIFO_AW = 9;
    localparam int RBYTE_SHIFT = $clog2(FULL_RWORD_SIZE);
    localparam int LOG_RBYTE_SHIFT = $clog2(RBYTE_SHIFT);
    localparam int WBYTE_SHIFT = $clog2(FULL_WWORD_SIZE);
    localparam int LOG_WBYTE_SHIFT = $clog2(WBYTE_SHIFT);

    localparam int ALIGN_BUF_SIZE = (CONV_32_64==1)             ? 64              :
                                    (RDATA_WIDTH > WDATA_WIDTH) ? (2*RDATA_WIDTH) :
                                                                  (2*WDATA_WIDTH);
    localparam int ALIGN_BUF_SIZE_BYTES = ALIGN_BUF_SIZE / 8;
    localparam int LOG_ALIGN_BUF_SIZE = $clog2(ALIGN_BUF_SIZE);
    localparam int LOG_ALIGN_BUF_SIZE_BYTES = $clog2(ALIGN_BUF_SIZE_BYTES);
    localparam int FULL_WWRITE_MASK = {FULL_WWORD_SIZE {1'b1}};
    localparam int WRITE_MASK = {WWORD_SIZE {1'b1}};
    localparam int WRITE_FIRST=0;
    localparam int WRITE_MIDDLE=1;
    localparam int WRITE_LAST=2;
    localparam int WRITE_SKIP=3; //#ron

    logic [RBYTE_SHIFT-1:0]             srcShift, srcShift_r;
    logic [WBYTE_SHIFT-1:0]             dstShift, dstShift_r;
    logic [RBYTE_SHIFT:0]               readNum;
    logic [WBYTE_SHIFT:0]               writeNum;
    logic [LOG_ALIGN_BUF_SIZE_BYTES:0]  readNum_s1;
    logic                               cmdBusy, cmdBusy_r;
    logic                               flush;
    logic [ADDR_WIDTH-1:0]              cmd_adr;
    logic                               rdBusy, rdBusy_r, wrBusy, wrBusy_r;
    logic [LEN-1:0]                     rdCnt, rdCnt_r, wrCnt, wrCnt_r;
    logic [ADDR_WIDTH-1:0]              srcPtr, srcPtr_r, dstPtr, dstPtr_r;
    logic [ALIGN_BUF_SIZE-1:0]          alignBuf_r, alignBuf;
    logic                               infinite_len, infinite_len_r;
    logic                               memset_run, memset_run_r;
    logic [7:0]                         memset_val, memset_val_r;
    logic                               rstall, wstall;
    logic                               firstRead_req, firstRead_req_r, firstRead_vld, firstRead_vld_r;
    logic                               firstWrite, firstWrite_r;
    logic [1:0]                         writeCase;
    logic [LOG_ALIGN_BUF_SIZE_BYTES:0]  bufNum, bufNum_r;

    logic [WDATA_WIDTH/8-1:0]           mem_bwe, bwe;
    logic [ADDR_WIDTH-1:0]              mem_wad;
    logic [WDATA_WIDTH-1:0]             mem_wdat;
    logic                               mem_re;
    logic [ADDR_WIDTH-1:0]              mem_rad;

    logic                               rdfifo_reserve;
    logic                               rdfifo_we;
    logic                               rdfifo_re;
    logic [RD_FIFO_DW-1:0]              rdfifo_wdat;
    logic [RD_FIFO_DW-1:0]              rdfifo_rdat;
    logic                               rdfifo_rrdy;
    logic                               rdfifo_wrdy;
    logic                               almost_full;

    logic                               src_dw_sel, src_dw_sel_r;//0-32, 1-64
    logic                               dst_dw_sel, dst_dw_sel_r;//0-32, 1-64
    logic [LOG_RBYTE_SHIFT:0]           src_word_size;
    logic [LOG_WBYTE_SHIFT:0]           dst_word_size;

    logic                               stop_axi4;
    logic                               stop_proc, stop_proc_r;

    generate
        if (CONV_32_64==1) begin
            assign rdfifo_wdat =  src_dw_sel_r ? {mem_rdat[55:48], mem_rdat[39:32], mem_rdat[23:16], mem_rdat[7:0]} : mem_rdat[31:0];
        end
        else begin
            assign rdfifo_wdat =  mem_rdat;
        end
    endgenerate

    reserve_fifo_v3 #(
        .DW     (RD_FIFO_DW),
        .AW     (RD_FIFO_AW)
    ) rdfifo (
        .rstn            (rstn),
        .clk             (clk),
        .stop            (stop_i),
        .rd_en           (rdfifo_re),
        .reserve_en      (rdfifo_reserve),
        .dout            (rdfifo_rdat),
        .wr_en           (rdfifo_we),
        .full_n          (rdfifo_full_n),
        .din             (rdfifo_wdat),
        .wrdy            (rdfifo_wrdy),
        .rrdy            (rdfifo_rrdy)
    );

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            alignBuf_r <= 0;
            mem_re_r <= 0;
            mem_rad_r <= 0;
            mem_bwe_r <= 0;
            mem_wad_r <= 0;
            mem_wdat_r <= 0;
            {memset_run_r, memset_val_r, rdCnt_r, wrCnt_r, rdBusy_r, wrBusy_r, alignBuf_r, bufNum_r, srcShift_r, dstShift_r,
            firstWrite_r, firstRead_req_r, firstRead_vld_r, srcPtr_r, dstPtr_r, src_dw_sel_r,
            dst_dw_sel_r} <= 0;
            flush_r <= 0;
            cmd_adr_r <= 0;
            cmdBusy_r <= 0;
            infinite_len_r <= 0;
            stop_axi4_r <= 0;
            stop_proc_r <= 0;
        end
        else begin
            alignBuf_r <= alignBuf;
            mem_re_r <= mem_re;
            mem_rad_r <= mem_rad;
            mem_bwe_r <= mem_bwe;
            mem_wad_r <= mem_wad;
            mem_wdat_r <= mem_wdat;
            {memset_run_r, memset_val_r, rdCnt_r, wrCnt_r, rdBusy_r, wrBusy_r, alignBuf_r, bufNum_r, srcShift_r, dstShift_r,  firstWrite_r, firstRead_req_r, firstRead_vld_r, srcPtr_r, dstPtr_r, src_dw_sel_r, dst_dw_sel_r} <=
                {memset_run, memset_val, rdCnt, wrCnt, rdBusy, wrBusy, alignBuf, bufNum, srcShift, dstShift, firstWrite, firstRead_req, firstRead_vld, srcPtr, dstPtr, src_dw_sel, dst_dw_sel};
            infinite_len_r <= infinite_len;
            flush_r <= flush;
            cmd_adr_r <= cmd_adr;
            cmdBusy_r <= cmdBusy;
            stop_axi4_r <= stop_axi4;
            stop_proc_r <= stop_proc;
        end
    end

    always @(*) begin
        {memset_run, memset_val, rdCnt, wrCnt, rdBusy, wrBusy, alignBuf, bufNum, srcShift, dstShift, firstWrite, firstRead_req, firstRead_vld, srcPtr, dstPtr, src_dw_sel, dst_dw_sel}=
            {memset_run_r, memset_val_r, rdCnt_r, wrCnt_r, rdBusy_r, wrBusy_r, alignBuf_r, bufNum_r, srcShift_r, dstShift_r, firstWrite_r, firstRead_req_r, firstRead_vld_r, srcPtr_r, dstPtr_r, src_dw_sel_r, dst_dw_sel_r} ;

        {writeNum, rdfifo_re, bwe} = 0;
        infinite_len = infinite_len_r;
        writeCase = WRITE_SKIP; //#ron

        cmdBusy = cmdBusy_r;
        cmd_adr = cmd_adr_r;
        flush = flush_r;

    //  command reception before activating the read and write pipeline
        if (~rdBusy_r && ~wrBusy_r && ~cmdBusy_r && (mem_bwe_r==0) && (copy_i || set_i || flush_i)) begin // switch from idling to running
            if (CONV_32_64==1) begin
                srcShift = src_dw_sel_i ? (src_i & 7) : (src_i & 3);
                dstShift = dst_dw_sel_i ? (dst_i & 7) : (dst_i & 3);
            end
            else begin
                srcShift = src_i & (FULL_RWORD_SIZE-1);
                dstShift = dst_i & (FULL_WWORD_SIZE-1);
            end
            srcPtr = src_i;
            dstPtr = dst_i;
            rdCnt = len_i;
            wrCnt = len_i;
            infinite_len = &len_i[LEN-1:0];
            firstRead_req = 1;
            firstRead_vld = 1;
            firstWrite = 1;
            rdBusy = copy_i;
            wrBusy = (copy_i || set_i);
            memset_run = set_i & ~copy_i;
            memset_val = setVal_i;
            src_dw_sel = src_dw_sel_i;
            dst_dw_sel = dst_dw_sel_i;
            cmdBusy = flush_i;
            cmd_adr = dst_i;
            flush = flush_i;
            // synthesis translate_off
            if ((CONV_32_64==0) && (src_dw_sel_i!=dst_dw_sel_i)) begin
                $display("At CONV_32_64==0 src_dw_sel_i and dst_dw_sel_i should be equal to each other");
                $finish;
            end
            else if ((CONV_32_64==1) && ((WDATA_WIDTH!=64) || (RDATA_WIDTH!=64))) begin
                $display("Wrong setting of the CONV_32_64=%d WDATA_WIDTH = %d RDATA_WIDTH=%d parameters in %m module", CONV_32_64, WDATA_WIDTH, RDATA_WIDTH);
                $finish;
            end
            // synthesis translate_on
        end

        if (flush_r && cmd_rdy) begin
            cmdBusy = 0;
            cmd_adr = 0;
            flush = 0;
        end

        CHECK_WRITE_CASE: //# get bwe, writeNum based on different write-cases
            /*if (stop_i) begin
                writeNum = 0;
            end
            else */if(firstWrite_r==1) begin // first write word
                if (CONV_32_64==0) begin
                    writeNum = ((WWORD_SIZE-dstShift_r) > wrCnt_r) ? wrCnt_r : (WWORD_SIZE-dstShift_r);//e.g. writeNum = 1;
                    writeCase = ((wrCnt_r <= WWORD_SIZE) && (writeNum==wrCnt_r)) ? WRITE_LAST : WRITE_FIRST;
                end
                else begin
                    if (dst_dw_sel_r) begin//64
                        writeNum = (((FULL_WWORD_SIZE-dstShift_r) / 2) > wrCnt_r) ? (wrCnt_r*2) : (FULL_WWORD_SIZE-dstShift_r);//e.g. writeNum = 1;
                        writeCase = ((wrCnt_r <= WWORD_SIZE) && ((writeNum/2)==wrCnt_r)) ? WRITE_LAST : WRITE_FIRST;
                    end
                    else begin
                        writeNum = ((WWORD_SIZE-dstShift_r) > wrCnt_r) ? wrCnt_r : (WWORD_SIZE-dstShift_r);//e.g. writeNum = 1;
                        writeCase = ((wrCnt_r <= WWORD_SIZE) && (writeNum==wrCnt_r)) ? WRITE_LAST : WRITE_FIRST;
                    end
                end
                //bwe should depend on dstShift and remained number of bytes
                //example: len=2 dst=F0
                for (int b=0; b<writeNum; b++) begin
                    bwe[dstShift_r + b] = 1;
                end
            end
            else if((((wrCnt_r<=WWORD_SIZE) && ~infinite_len_r) || (stop_i && (bufNum_r>0))) && wrBusy_r) begin // last write word
                if (stop_i) begin
                    bwe = shift_right_mask(WWORD_SIZE-bufNum_r, dst_dw_sel_r);         //e.g. bwe_o = 0111
                    writeNum = bufNum_r;
                end
                else begin
                    bwe = shift_right_mask(WWORD_SIZE-wrCnt_r, dst_dw_sel_r);         //e.g. bwe_o = 0111
                    if (CONV_32_64==0) begin
                        writeNum = wrCnt_r;
                    end
                    else begin
                        writeNum = dst_dw_sel_r ? (wrCnt_r*2) : wrCnt_r;
                    end
                end
                writeCase = WRITE_LAST;
            end
            else begin
                bwe = dst_dw_sel_r ? {FULL_WWORD_SIZE {1'b1}} : {WWORD_SIZE {1'b1}};
                writeNum = dst_dw_sel_r ? FULL_WWORD_SIZE : WWORD_SIZE;
                writeCase = WRITE_MIDDLE;
            end


        rstall = (mem_rreq_rdy && rdBusy_r && rdfifo_wrdy) ? 0 : 1;
        if (CONV_32_64==0) begin
            wstall = (mem_wreq_rdy && wrBusy_r && (bufNum_r>=writeNum)) ? 0 : 1;
        end
        else begin
            wstall = (mem_wreq_rdy && wrBusy_r && (((bufNum_r>=writeNum && ~dst_dw_sel_r)) || (bufNum_r>=(writeNum/2) && dst_dw_sel_r))) ? 0 : 1;
        end

        //- stage 1: if ~rstall, request to read from source-memory
        // read-source-memory pipeline
        //readNum = (firstRead_req_r && src_dw_sel_r) ? (FULL_WORD_SIZE - srcShift_r)/2 :
        //          (firstRead_req_r && ~src_dw_sel_r) ? (WORD_SIZE - srcShift_r) :
        //                                                WORD_SIZE;         // e.g. firstRead_req_r=0; readNum=4
        readNum = RWORD_SIZE;
        if (stop_i) begin
            readNum = 0;
        end
        else if (CONV_32_64==0) begin
            if (firstRead_req_r) begin
                readNum = FULL_RWORD_SIZE - srcShift_r;
            end
        end
        else begin
            if (firstRead_req_r && src_dw_sel_r) begin
                readNum = (FULL_RWORD_SIZE - srcShift_r)/2;
            end
            else if (firstRead_req_r && ~src_dw_sel_r) begin
                readNum = (RWORD_SIZE - srcShift_r);
            end
        end

        mem_re = mem_re_r;
        mem_rad = mem_rad_r;
        if (stop_i) begin
            rdCnt = 0;
            rdBusy = 0;
        end
        else if (~rstall) begin
            firstRead_req = 0;
            if (~infinite_len_r) begin
                rdCnt = (rdCnt_r >= readNum) ? (rdCnt_r - readNum) : 0;
            end
            rdBusy = ((rdCnt==0) && ~infinite_len_r) ? 0 : 1;
            if (CONV_32_64==0) begin
                srcPtr = srcPtr_r + readNum;
                mem_rad = srcPtr_r >> RBYTE_SHIFT;
            end
            else begin
                srcPtr = srcPtr_r + (src_dw_sel_r ? readNum*2 : readNum);
                mem_rad = src_dw_sel_r ? (srcPtr_r >> RBYTE_SHIFT) : (srcPtr_r >> (RBYTE_SHIFT-1));
            end
            mem_re = 1;
        end
        else if (mem_rreq_rdy) begin
            mem_re = 0;
        end
        rdfifo_reserve = mem_rreq_rdy & mem_re_r;

        //- stage 2: if data return,  write to rdfifo
        rdfifo_we = mem_rdat_rdy;// && rdfifo_wrdy;

        //- stage 3b: if ~wstall, read from alignBuf and write to destination memory
        UPDATE_ALIGN_BUF_FOR_WRITE: //# if write is not stalled, update bufNum and alignBuf after the write operation
            if(~wstall) begin
                if (writeCase==WRITE_LAST) begin
                    bufNum = 0;
                    alignBuf = 0;
                end
                else if (CONV_32_64==0) begin
                    bufNum -= writeNum;                 //e.g. bufNum=3
                    alignBuf >>= (writeNum*8);         //e.g. alignBuf_r=00000dcb
                end
                else if (dst_dw_sel_r) begin
                    bufNum -= (writeNum / 2);          //e.g. bufNum=3
                    alignBuf >>= (writeNum*4);         //e.g. alignBuf_r=00000dcb
                end
                else begin
                    bufNum -= writeNum;                 //e.g. bufNum=3
                    alignBuf >>= (writeNum*8);         //e.g. alignBuf_r=00000dcb
                end
            end
            else begin
                bwe=0; writeCase=WRITE_SKIP; writeNum=0; // WRITE_SKIP not used; just for clarity
            end

        //- stage 3a: read from rdfifo and write to alignBuf
        //readNum_s1 = (firstRead_vld_r && src_dw_sel_r) ? (FULL_WORD_SIZE - srcShift_r)/2 :
        //            (firstRead_vld_r && ~src_dw_sel_r) ? (WORD_SIZE - srcShift_r) :
        //                                                 WORD_SIZE;         // e.g. firstRead_req_r=0; readNum=4

        readNum_s1 = RWORD_SIZE;
        if (CONV_32_64==0) begin
            if (firstRead_vld_r) begin
                readNum_s1 = FULL_RWORD_SIZE - srcShift_r;
            end
        end
        else begin
            if (firstRead_vld_r && src_dw_sel_r) begin
                readNum_s1 = (FULL_RWORD_SIZE - srcShift_r)/2;
            end
            else if (firstRead_vld_r && ~src_dw_sel_r) begin
                readNum_s1 = (RWORD_SIZE - srcShift_r);
            end
        end


        if (stop_i) begin
            bufNum = 0;
            alignBuf = 0;
        end
        else if(rdfifo_rrdy && ((bufNum+readNum_s1)<ALIGN_BUF_SIZE_BYTES) && ~memset_run_r) begin
            rdfifo_re = 1;
            firstRead_vld = 0;
            if (CONV_32_64==0) begin
                if (firstRead_vld_r) begin
                    alignBuf |= (rdfifo_rdat >> (srcShift_r*8));
                end
                else begin //alignBuf_r may be shifted due to buffer fetched by memory write operation
                    alignBuf |= (rdfifo_rdat << (bufNum*8));     // e.g. rdfifo_rdat=hgfe, rdat<<(3*8)=hgfe000, alignBuf_r=hgfedcb,
                end
            end
            else if(firstRead_vld_r && src_dw_sel_r) begin
                alignBuf |= (rdfifo_rdat >> (srcShift_r*4));
            end
            else if (firstRead_vld_r) begin
                alignBuf |= (rdfifo_rdat >> (srcShift_r*8));
            end
            else begin //alignBuf_r may be shifted due to buffer fetched by memory write operation
                alignBuf |= (rdfifo_rdat << (bufNum*8));     // e.g. rdfifo_rdat=hgfe, rdat<<(3*8)=hgfe000, alignBuf_r=hgfedcb,
            end
            bufNum += readNum_s1; // e.g. bufNum = 7
        end
        else if ((bufNum<ALIGN_BUF_SIZE_BYTES) && memset_run_r && (writeCase!=WRITE_LAST)) begin
            alignBuf = {ALIGN_BUF_SIZE_BYTES {memset_val_r}};
            bufNum += (((ALIGN_BUF_SIZE_BYTES - bufNum) > wrCnt_r) ? wrCnt_r : (ALIGN_BUF_SIZE_BYTES - bufNum));
        end

        //- stage 4: if ~wstall, read from alignBuf and write to destination memory
        // write-dest-memory pipeline
        mem_bwe = mem_bwe_r;
        mem_wad = mem_wad_r;
        mem_wdat = mem_wdat_r;
        stop_axi4 = ((stop_proc_r && mem_wreq_rdy) || (stop_i && (bufNum_r==0))) ? 1 : 0;
        stop_proc = mem_wreq_rdy ? 0 : stop_proc_r;
        if (stop_i && (bufNum_r==0)) begin
            wrCnt = 0;
            wrBusy = 0;
            mem_bwe = 0;
        end
        else if (~wstall) begin
            firstWrite = 0;
            if (CONV_32_64==0) begin
                dstPtr = dstPtr_r + writeNum;
                dstShift = (dstPtr & (FULL_WWORD_SIZE-1));
                mem_bwe = bwe;
                mem_wad = dstPtr_r >> WBYTE_SHIFT;
                if (~infinite_len_r) begin
                    wrCnt = wrCnt_r - writeNum;
                end
                stop_proc = infinite_len_r & stop_i;
                if (firstWrite_r) begin
                    mem_wdat = shift_left(alignBuf_r[WDATA_WIDTH-1:0], dstShift_r, dst_dw_sel_r);//e.g. bwe_o = 0001
                end
                else begin
                    mem_wdat = alignBuf_r[WDATA_WIDTH-1:0];
                end
            end
            else begin
                if (dst_dw_sel_r) begin
                    dstPtr = dstPtr_r + writeNum;
                    dstShift = (dstPtr & 7);
                    mem_bwe = bwe;
                    mem_wad = dstPtr_r >> WBYTE_SHIFT;
                    if (~infinite_len_r) begin
                        wrCnt = wrCnt_r - writeNum/2;
                    end
                    if (firstWrite_r) begin
                        mem_wdat = shift_left(alignBuf_r[31:0], dstShift_r, dst_dw_sel_r);//e.g. bwe_o = 0001
                    end
                    else begin
                        mem_wdat = {8'b0, alignBuf_r[31:24], 8'b0, alignBuf_r[23:16], 8'b0, alignBuf_r[15:8], 8'b0, alignBuf_r[7:0]};
                    end
                end
                else begin
                    dstPtr = dstPtr_r + writeNum;
                    dstShift = (dstPtr & 3);
                    mem_bwe = bwe;
                    mem_wad = dstPtr_r >> (WBYTE_SHIFT - 1);
                    if (~infinite_len_r) begin
                        wrCnt = wrCnt_r - writeNum;
                    end
                    if (firstWrite_r) begin
                        mem_wdat = shift_left(alignBuf_r[31:0], dstShift_r, dst_dw_sel_r);//e.g. bwe_o = 0001
                    end
                    else begin
                        mem_wdat = alignBuf_r[31:0];
                    end
                end
            end
            if(writeCase==WRITE_LAST) begin
                wrBusy = 0;
                memset_run = 0;
            end
        end
        else if (mem_wreq_rdy) begin
            mem_bwe = 0;
        end

        done_o = ~rdBusy_r && ~wrBusy_r && (mem_bwe_r==0) && ~cmdBusy_r;
    end

function [WDATA_WIDTH-1:0] shift_left;
    input [WDATA_WIDTH-1:0] dat;
    input [WBYTE_SHIFT-1:0] shift;
    input                   dw_sel;
    if (CONV_32_64==0) begin
        shift_left = dat << (8*shift);
    end
    else if (dw_sel) begin
        shift_left = 0;
        for (int i=0; i<FULL_WWORD_SIZE; i++) begin
            if ((i&1)==0) begin
                shift_left[(i + shift)*8 +: 8] = dat[i*8/2 +: 8];
            end
        end
    end
    else begin
        shift_left = (dat << (8*shift)) & ({{32{1'b0}}, {32{1'b1}}});
    end
endfunction

function [FULL_WWORD_SIZE-1:0] shift_right_mask;
    input [WBYTE_SHIFT-1:0] shift;
    input                   dw_sel;
    shift_right_mask = (dw_sel && (CONV_32_64==1)) ? (FULL_WWRITE_MASK>>(shift*2)) : (WRITE_MASK>>shift);
endfunction

endmodule

module reserve_fifo_v3 #(
    parameter DW = 32,
    parameter AW = 1
)(
    input                   rstn,
    input                   clk,
    input                   stop,
    input                   reserve_en,
    input                   wr_en,
    input        [DW-1:0]   din,
    input                   rd_en,
    output logic [DW-1:0]   dout,
    output logic            full_n,
    output logic            wrdy,
    output logic            rrdy
);
    localparam DEPTH = (1 << AW);
    reg [DW-1:0]   mem[DEPTH];
    logic [AW-1:0] wptr, wptr_r;
    logic [AW-1:0] rptr, rptr_r;
    logic [AW:0]   num, num_r, reserveNum, reserveNum_r;
    logic          we;

    always @(posedge clk or negedge rstn) begin
        if (~rstn) begin
            wptr_r <= 0;
            rptr_r <= 0;
            num_r <= 0;
            reserveNum_r<=0;
        end
        else begin
            wptr_r <= wptr;
            rptr_r <= rptr;
            num_r <= num;
            reserveNum_r <= reserveNum;
        end
    end

    always @(*) begin
        wrdy = (reserveNum_r < (DEPTH-1));
        full_n = (num_r < DEPTH);
        rrdy = (num_r!=0);
        wptr = stop ? 0 : wptr_r;
        rptr = stop ? 0 : rptr_r;
        reserveNum = stop ? 0 : (reserveNum_r + reserve_en - rd_en);
        num        = stop ? 0 : (num_r + wr_en - rd_en);
        we = 0;
        if (wr_en && ~stop) begin
            wptr = wptr_r + 1;
            we = 1;
        end
        if (rd_en && ~stop) begin
            rptr = rptr_r + 1;
        end
    end

    always @(posedge clk) begin
        if (we) begin
            mem[wptr_r] <= din;
        end
    end

    assign dout = mem[rptr_r];

endmodule