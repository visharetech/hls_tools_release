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
*/

module copyEngine  #(
    parameter DATA_WIDTH       = 64,
    parameter ADDR_WIDTH       = 32,
    parameter LEN              = 16,
    parameter FULL_WORD_SIZE   = DATA_WIDTH / 8
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
    input        [LEN-1:0]            len_i,
    input        [ADDR_WIDTH-1:0]     src_i,
    input        [ADDR_WIDTH-1:0]     dst_i,
    output logic                      done_o,

    // memory ports
    //Memory read
    output logic                      mem_re_r,
    output logic [ADDR_WIDTH-1:0]     mem_rad_r,
    input                             mem_rreq_rdy,
    input        [DATA_WIDTH-1:0]     mem_rdat,
    input                             mem_rdat_rdy,

    //Memory write
    output logic [FULL_WORD_SIZE-1:0] mem_bwe_r,
    output logic [ADDR_WIDTH-1:0]     mem_wad_r,
    output logic [DATA_WIDTH-1:0]     mem_wdat_r,
    input                             mem_wreq_rdy,

    output logic                      flush_r,
    output logic [ADDR_WIDTH-1:0]     cmd_adr_r,
    input                             cmd_rdy
);

    localparam int WORD_SIZE = FULL_WORD_SIZE / 2;
    localparam int RD_FIFO_DW = 32;
    localparam int RD_FIFO_AW = 8;
    localparam int BYTE_SHIFT = $clog2(FULL_WORD_SIZE);
    localparam int LOG_BYTE_SHIFT = $clog2(BYTE_SHIFT);
    //localparam int SRC_ADDR_MASK = (1 << BYTE_SHIFT) - 1;
    //localparam int DST_ADDR_MASK = (1 << BYTE_SHIFT) - 1;
    localparam int ALIGN_BUF_SIZE = 2*RD_FIFO_DW;
    localparam int ALIGN_BUF_SIZE_BYTES = ALIGN_BUF_SIZE / 8;
    localparam int LOG_ALIGN_BUF_SIZE = $clog2(ALIGN_BUF_SIZE);
    localparam int LOG_ALIGN_BUF_SIZE_BYTES = $clog2(ALIGN_BUF_SIZE_BYTES);
    localparam int FULL_WRITE_MASK = {FULL_WORD_SIZE {1'b1}};
    localparam int WRITE_MASK = {WORD_SIZE {1'b1}};
    localparam int WRITE_FIRST=0;
    localparam int WRITE_MIDDLE=1;
    localparam int WRITE_LAST=2;
    localparam int WRITE_SKIP=3; //#ron

    logic [BYTE_SHIFT-1:0]              srcShift, srcShift_r;
    logic [BYTE_SHIFT-1:0]              dstShift, dstShift_r;
    logic [BYTE_SHIFT:0]                readNum;
    logic [BYTE_SHIFT:0]                writeNum;
    logic [LOG_ALIGN_BUF_SIZE_BYTES:0]  readNum_s1;
    logic                               cmdBusy, cmdBusy_r;
    logic                               flush;
    logic [ADDR_WIDTH-1:0]              cmd_adr;
    logic                               rdBusy, rdBusy_r, wrBusy, wrBusy_r;
    logic [LEN-1:0]                     rdCnt, rdCnt_r, wrCnt, wrCnt_r;
    logic [ADDR_WIDTH-1:0]              srcPtr, srcPtr_r, dstPtr, dstPtr_r;
    logic [ALIGN_BUF_SIZE-1:0]          alignBuf_r, alignBuf;
    logic                               memset_run, memset_run_r;
    logic [7:0]                         memset_val, memset_val_r;
    logic                               rstall, wstall;
    logic                               firstRead_req, firstRead_req_r, firstRead_vld, firstRead_vld_r;
    logic                               firstWrite, firstWrite_r;
    logic [1:0]                         writeCase;
    logic [LOG_ALIGN_BUF_SIZE_BYTES:0]  bufNum, bufNum_r;

    logic [FULL_WORD_SIZE-1:0]          mem_bwe, bwe;
    logic [ADDR_WIDTH-1:0]              mem_wad;
    logic [DATA_WIDTH-1:0]              mem_wdat;
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
    logic [LOG_BYTE_SHIFT:0]            src_word_size, src_word_size_r;
    logic [LOG_BYTE_SHIFT:0]            dst_word_size, dst_word_size_r;

    assign rdfifo_wdat =  src_dw_sel_r ? {mem_rdat[55:48], mem_rdat[39:32], mem_rdat[23:16], mem_rdat[7:0]} : mem_rdat[31:0];

    reserve_fifo #(
        .DW     (RD_FIFO_DW),
        .AW     (RD_FIFO_AW)
    ) rdfifo (
        .rstn            (rstn),
        .clk             (clk),
        .rd_en           (rdfifo_re),
        .reserve_en      (rdfifo_reserve),
        .dout            (rdfifo_rdat),
        .wr_en           (rdfifo_we),
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

            flush_r <= flush;
            cmd_adr_r <= cmd_adr;
            cmdBusy_r <= cmdBusy;
        end
    end

    always @(*) begin
        {memset_run, memset_val, rdCnt, wrCnt, rdBusy, wrBusy, alignBuf, bufNum, srcShift, dstShift, firstWrite, firstRead_req, firstRead_vld, srcPtr, dstPtr, src_dw_sel, dst_dw_sel}=
            {memset_run_r, memset_val_r, rdCnt_r, wrCnt_r, rdBusy_r, wrBusy_r, alignBuf_r, bufNum_r, srcShift_r, dstShift_r, firstWrite_r, firstRead_req_r, firstRead_vld_r, srcPtr_r, dstPtr_r, src_dw_sel_r, dst_dw_sel_r} ;

        {writeNum, rdfifo_re, bwe} = 0;

        writeCase = WRITE_SKIP; //#ron

        cmdBusy = cmdBusy_r;
        cmd_adr = cmd_adr_r;
        flush = flush_r;

    //  command reception before activating the read and write pipeline
        if (~rdBusy_r && ~wrBusy_r && ~cmdBusy_r && (mem_bwe_r==0) && (copy_i || set_i || flush_i)) begin // switch from idling to running
            srcShift = src_dw_sel_i ? (src_i & 7) : (src_i & 3);
            dstShift = dst_dw_sel_i ? (dst_i & 7) : (dst_i & 3);
            srcPtr = src_i;
            dstPtr = dst_i;
            rdCnt = len_i;
            wrCnt = len_i;
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
        end

        if (flush_r && cmd_rdy) begin
            cmdBusy = 0;
            cmd_adr = 0;
            flush = 0;
        end

        CHECK_WRITE_CASE: //# get bwe, writeNum based on different write-cases
            if(firstWrite_r==1) begin // first write word
                if (dst_dw_sel_r) begin//64
                    writeNum = (((FULL_WORD_SIZE-dstShift_r) / 2) > wrCnt_r) ? (wrCnt_r*2) : (FULL_WORD_SIZE-dstShift_r);//e.g. writeNum = 1;
                    writeCase = ((wrCnt_r <= WORD_SIZE) && ((writeNum/2)==wrCnt_r)) ? WRITE_LAST : WRITE_FIRST;
                end
                else begin
                    writeNum = ((WORD_SIZE-dstShift_r) > wrCnt_r) ? wrCnt_r : (WORD_SIZE-dstShift_r);//e.g. writeNum = 1;
                    writeCase = ((wrCnt_r <= WORD_SIZE) && (writeNum==wrCnt_r)) ? WRITE_LAST : WRITE_FIRST;
                end
                //bwe should depend on dstShift and remained number of bytes
                //example: len=2 dst=F0
                for (int b=0; b<writeNum; b++) begin
                    bwe[dstShift_r + b] = 1;
                end

            end
            else if((wrCnt_r<=WORD_SIZE) && wrBusy_r) begin // last write word
                bwe = shift_right_mask(WORD_SIZE-wrCnt_r, dst_dw_sel_r);         //e.g. bwe_o = 0111
                writeNum = dst_dw_sel_r ? (wrCnt_r*2) : wrCnt_r;
                writeCase = WRITE_LAST;
            end
            else begin
                bwe = dst_dw_sel_r ? {FULL_WORD_SIZE {1'b1}} : {WORD_SIZE {1'b1}};
                writeNum = dst_dw_sel_r ? FULL_WORD_SIZE : WORD_SIZE;
                writeCase = WRITE_MIDDLE;
            end


        rstall = (mem_rreq_rdy && rdBusy_r && rdfifo_wrdy) ? 0 : 1;
        wstall = (mem_wreq_rdy && wrBusy_r && (((bufNum_r>=writeNum && ~dst_dw_sel_r)) || (bufNum_r>=(writeNum/2) && dst_dw_sel_r))) ? 0 : 1;

        //- stage 1: if ~rstall, request to read from source-memory
        // read-source-memory pipeline
        readNum = (firstRead_req_r && src_dw_sel_r) ? (FULL_WORD_SIZE - srcShift_r)/2 :
                  (firstRead_req_r && ~src_dw_sel_r) ? (WORD_SIZE - srcShift_r) :
                                                        WORD_SIZE;         // e.g. firstRead_req_r=0; readNum=4
        mem_re = mem_re_r;
        mem_rad = mem_rad_r;
        if (~rstall) begin
            firstRead_req = 0;
            rdCnt = (rdCnt_r >= readNum) ? (rdCnt_r - readNum) : 0;
            rdBusy = (rdCnt==0) ? 0 : 1;
            srcPtr = srcPtr_r + (src_dw_sel_r ? readNum*2 : readNum);
            mem_re = 1;
            mem_rad = src_dw_sel_r ? (srcPtr_r >> BYTE_SHIFT) : (srcPtr_r >> (BYTE_SHIFT-1));
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
                else if (dst_dw_sel) begin
                    bufNum -= (writeNum / 2);                 //e.g. bufNum=3
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
        readNum_s1 = (firstRead_vld_r && src_dw_sel_r) ? (FULL_WORD_SIZE - srcShift_r)/2 :
                    (firstRead_vld_r && ~src_dw_sel_r) ? (WORD_SIZE - srcShift_r) :
                                                         WORD_SIZE;         // e.g. firstRead_req_r=0; readNum=4
        if(rdfifo_rrdy && ((bufNum+readNum_s1)<ALIGN_BUF_SIZE_BYTES) && ~memset_run_r) begin
            rdfifo_re = 1;
            firstRead_vld = 0;
            if(firstRead_vld_r && src_dw_sel_r) begin
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
        if (~wstall) begin
            firstWrite = 0;
            if (dst_dw_sel_r) begin
                dstPtr = dstPtr_r + writeNum;
                dstShift = (dstPtr & 7);
                mem_bwe = bwe;
                mem_wad = dstPtr_r >> BYTE_SHIFT;
                wrCnt = wrCnt_r - writeNum/2;
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
                mem_wad = dstPtr_r >> (BYTE_SHIFT - 1);
                wrCnt = wrCnt_r - writeNum;
                if (firstWrite_r) begin
                    mem_wdat = shift_left(alignBuf_r[31:0], dstShift_r, dst_dw_sel_r);//e.g. bwe_o = 0001
                end
                else begin
                    mem_wdat = alignBuf_r[31:0];
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

function [DATA_WIDTH-1:0] shift_left;
    input [31:0]           dat;
    input [BYTE_SHIFT-1:0] shift;
    input                  dw_sel;
    if (dw_sel) begin
        shift_left = 0;
        for (int i=0; i<FULL_WORD_SIZE; i++) begin
            if ((i&1)==0) begin
                shift_left[(i + shift)*8 +: 8] = dat[i*8/2 +: 8];
            end
        end
    end
    else begin
        shift_left = (dat << (8*shift)) & ({{32{1'b0}}, {32{1'b1}}});
    end
endfunction

function [FULL_WORD_SIZE-1:0] shift_right_mask;
    input [BYTE_SHIFT-1:0] shift;
    input                  dw_sel;
    shift_right_mask = dw_sel ? (FULL_WRITE_MASK>>(shift*2)) : (WRITE_MASK>>shift);
endfunction

endmodule

module reserve_fifo#(
    parameter DW = 32,
    parameter AW = 1
)(
    input                   rstn,
    input                   clk,
    input                   reserve_en,
    input                   wr_en,
    input        [DW-1:0]   din,
    input                   rd_en,
    output logic [DW-1:0]   dout,
    output logic            wrdy,
    output logic            rrdy
);
    localparam DEPTH = (1 << AW);
    reg [DW-1:0]   mem[DEPTH];
    logic [AW-1:0] wptr, wptr_r;
    logic [AW-1:0] rptr, rptr_r;
    logic [AW:0]   num, num_r, reserveNum, reserveNum_r;
    logic          we;
    logic vrdy;

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
            reserveNum_r<=reserveNum;
        end
    end

    always @(*) begin
        wrdy = (reserveNum_r < (DEPTH-1));
        rrdy = (num_r!=0);
        wptr = wptr_r;
        rptr = rptr_r;
        reserveNum = (reserveNum_r + reserve_en - rd_en);
        num        = num_r        + wr_en      - rd_en;
        we = 0;
        if (wr_en) begin
            wptr = wptr_r + 1;
            we = 1;
        end
        if (rd_en) begin
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