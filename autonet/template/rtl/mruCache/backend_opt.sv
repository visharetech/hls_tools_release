/*
no driver
axi4_w_strb, axi4_w_last, axi4_b_ready, axi4_r_ready, replaceWay_r

constant 0
axi4_aw_addr[28:31]
axi4_aw_len[4:7]
axi4_ar_len[4:7] d
resume

unconnected
axi4_w_strb
axi4_w_last
axi4_b_ready
axi4_r_ready
axi4_b_valid
axi4_b_resp
axi4_r_last

*/
`include "vcap.vh"
import mru_pkg::*;

module backend #(
    parameter int AXI_LEN_W = 8,
    parameter int DW = 32,
    parameter int AW = 32,
    parameter int CACHE_BYTE = 16*1024,
    parameter int CACHE_WAY = 2,
    parameter int CACHE_WORD_BYTE = DW / 8,
    parameter int CACHE_LINE_LEN = 8
)(
    input                                clk,
    input                                rstn,

    input                                writeback,
    input        [AW-1:0]                wb_byte_ptr,
    input                                refill,
    input        [AW-1:0]                refill_byte_ptr,
    input        [$clog2(CACHE_WAY)-1:0] replaceWay,

    output logic                         init_done_pulse_r,
    output logic                         resume_r,
    output logic                         back_we_r,
    output logic                         back_re_r,
    output logic [AW-1:0]                back_adr_r,
    output logic [DW-1:0]                back_wdat_r,
    input        [DW-1:0]                back_rdat,
	output logic [$clog2(CACHE_WAY)-1:0] back_inway,

    output logic [AW-1:0]                axi4_aw_addr,
    output logic                         axi4_aw_valid,
    input  logic                         axi4_aw_ready,
    output logic [AXI_LEN_W-1:0]         axi4_aw_len,
    output logic [DW-1:0]                axi4_w_data,
    output logic [DW/8-1:0]              axi4_w_strb,
    output logic                         axi4_w_valid,
    input  logic                         axi4_w_ready,
    output logic                         axi4_w_last,

    input  logic                         axi4_b_valid,
    output logic                         axi4_b_ready,
    input  logic                         axi4_b_resp,

    output logic [AW-1:0]                axi4_ar_addr,
    output logic                         axi4_ar_valid,
    input  logic                         axi4_ar_ready,
    output logic [AXI_LEN_W-1:0]         axi4_ar_len,
    input  logic                         axi4_r_last,
    input  logic                         axi4_r_valid,
    output logic                         axi4_r_ready,
    input  logic [DW-1:0]                axi4_r_data
);

    localparam int WSTRB_W = DW / 8;
    localparam int LOG2_CACHE_WAY = $clog2(CACHE_WAY);
    localparam int CACHE_SET = (CACHE_BYTE/CACHE_WORD_BYTE/CACHE_LINE_LEN/CACHE_WAY);
    localparam int CACHE_TAG_BITS = AW-$clog2(CACHE_BYTE/CACHE_WAY);
    localparam int ADBITS = $clog2(CACHE_SET*CACHE_LINE_LEN);
    localparam int LOG2_CACHE_BYTE = $clog2(CACHE_BYTE);
    localparam int LOG2_CACHE_SET = $clog2(CACHE_SET);
    localparam int NLM_BYTE = 32; //256 bit
    localparam int DATA_ADR_W = LOG2_CACHE_BYTE - 2 - LOG2_CACHE_WAY;
    localparam int CACHE_INIT_NUM = CACHE_BYTE / (CACHE_WAY * CACHE_LINE_LEN * CACHE_WORD_BYTE);
    localparam int LOG2_CACHE_WORD_BYTE = $clog2(CACHE_WORD_BYTE);
    localparam int LOG2_CACHE_LINE_LEN = $clog2(CACHE_LINE_LEN);
    localparam int SET_NUM = (CACHE_BYTE / CACHE_LINE_LEN / CACHE_WORD_BYTE / CACHE_WAY);
    localparam int SEQ = $clog2(CACHE_INIT_NUM);

    localparam int BACK_ADR_SHIFT = 5;
    localparam int STATES_NUM = 4;
    typedef enum logic [STATES_NUM-1:0] {
        INIT        = (1 << 0),
        READY       = (1 << 1),
        WRITEBACK   = (1 << 2),
        REFILL      = (1 << 3)
    } states_t;

    logic [STATES_NUM-1:0]          state, state_r;//4
    //!!optimization: Register all axi4 output
    /*
    reg [AW-1:0]                    axi4_ar_addr_r;//32
    reg [AW-1:0]                    axi4_aw_addr_r;//32
    reg [DW-1:0]                    axi4_w_data_r;//32
    reg                             axi4_aw_valid_r, axi4_ar_valid_r, axi4_w_valid_r;    // 3
    reg                             axi4_aw_ready_r, axi4_ar_ready_r;    // 2
    reg                             axi4_w_ready_r;//1
    reg                             axi4_w_last_r; // 1
    */
    reg                             axi4_b_valid_r; // 1
    //!!reg   [LOG2_CACHE_SET-1:0]      iniCnt, iniCnt_r;            // 8
    reg   [DW-1:0]                  dataBuf;
    reg                             back_rdat_vld;
    reg   [LOG2_CACHE_WAY-1:0]      replaceWay_r;               // 1
    reg                             wait_bvalid, wait_bvalid_r; //1
    logic                           seq_start;
    logic [AW-1:0]                  seq_startAdr;
    wire  [AW-1:0]                  seq_adr;
    logic                           seq_last;
    logic                           seq_run;
    logic                           init_done_pulse, resume;
    logic                           back_we, back_re, back_re_r2;
    logic [AW-1:0]                  back_adr;
    logic [DW-1:0]                  back_wdat;
    //!!logic [7:0]                     wcnt, wcnt_r;
    //!!logic [7:0]                     wcnt_s1, wcnt_s1_r;
    reg                             pend_refill, pend_refill_r;
    reg   [AW-1:0]                  pend_refill_byte_ptr, pend_refill_byte_ptr_r;
    reg                             addr_compl, addr_compl_r;
    reg                             data_compl, data_compl_r;
    logic [AW-1:0]                  axi4_ar_addr_c;
    logic [AW-1:0]                  axi4_aw_addr_c;
    logic [DW-1:0]                  axi4_w_data_c;
    logic                           axi4_aw_valid_c, axi4_ar_valid_c, axi4_w_valid_c;
    logic                           axi4_w_last_c;
    logic [SEQ-1:0]                 seq_startCnt;
    logic [SEQ:0]                   seq_len;
    logic [SEQ-1:0]                 seq_cnt;
    reg   [SEQ-1:0]                 seq_cnt_r, seq_cnt_r2;
    reg   [AW-1:0]                  back_adr_r2;
    logic                           init_run;
    reg                             init_run_r;

    always @(*) begin
        back_we = '0;
        back_wdat = '0;
        back_re = '0;
        back_rdat_vld = 0;
        back_adr = '0;
        back_inway = replaceWay_r;

        //!!iniCnt = 0;
        axi4_ar_len = CACHE_LINE_LEN - 1;
        axi4_aw_len = CACHE_LINE_LEN - 1;

        axi4_aw_valid_c = axi4_aw_valid;
        axi4_aw_addr_c = axi4_aw_addr;
        axi4_w_valid_c = axi4_w_valid;
        axi4_w_data_c = axi4_w_data;
        axi4_ar_valid_c = axi4_ar_valid;
        axi4_ar_addr_c = axi4_ar_addr;
        axi4_w_last_c = axi4_w_last;
        //!!wcnt = wcnt_r;
        //!!wcnt_s1 = wcnt_s1_r;

        state = state_r;
        resume = '0;

        seq_start = '0;
        seq_startAdr = '0;
        seq_run = '0;
        seq_startCnt = '0;
        seq_len = CACHE_LINE_LEN;
        init_done_pulse=0;
        init_run = init_run_r;

        axi4_r_ready =1;
        axi4_w_strb = {WSTRB_W {1'b1}};
        axi4_b_ready = 1;
        wait_bvalid = wait_bvalid_r;

        dataBuf = axi4_r_ready ? axi4_r_data : back_rdat;

        pend_refill = pend_refill_r;
        pend_refill_byte_ptr = pend_refill_byte_ptr_r;
        addr_compl = addr_compl_r;
        data_compl = data_compl_r;

        //!!optmization: default value instead of 0
        back_wdat = dataBuf;
        back_adr = seq_adr;

        case ( state_r )
            INIT: begin
                //`combCap6($time, iniCnt_r, CACHE_BYTE, CACHE_WAY, CACHE_BYTE/(CACHE_WAY*CACHE_LINE_LEN*CACHE_WORD_BYTE), CACHE_WORD_BYTE);
                //!!Optimization: no need initialize dataMem as 0
                //!!back_we = 1'b1;
                //!!back_adr = iniCnt_r << BACK_ADR_SHIFT;
                //!!Optimization: no need initialize dataMem as 0
                //!!back_wdat = '0;
                //!!Optimization: reuse sequencer
                seq_len = CACHE_INIT_NUM;
                if (~init_run) begin
                    seq_start = 1;
                    init_run = 1;
                end
                //!!iniCnt = iniCnt_r + 1'b1;
                else if (seq_last /*iniCnt_r==(CACHE_INIT_NUM-1)*/) begin
                    resume =  1;
                    state = READY;
                    init_done_pulse = 1;
                    //`combStr(backend finish init);
                    //`combCap3(resume, state, state_r);
                end
                else begin
                    back_we = 1'b1;
                    seq_run = 1'b1;
                end
            end
            READY: begin
                addr_compl = 0;
                data_compl = 0;
                if( writeback ) begin
                    state = WRITEBACK;
                // read a burst from mruCore
                    seq_start = 1'b1;
                    seq_startAdr = getCacheAdr(wb_byte_ptr);
                //prepare write-address channel
                    axi4_aw_valid_c = 1'b1;
                    axi4_aw_addr_c = wb_byte_ptr;

                    pend_refill = refill;
                    pend_refill_byte_ptr = refill_byte_ptr;
                end
                else if( refill ) begin
                    state = REFILL;
                    //!!optmization: No issue AXI4 read request here
                    pend_refill_byte_ptr = refill_byte_ptr;
					/*
                // write a burst to mruCore
                    seq_start = 1'b1;
                    seq_startAdr = getCacheAdr(refill_byte_ptr);
                //prepare read-address channel
                    axi4_ar_valid = 1'b1;
                    axi4_ar_addr = refill_byte_ptr;
					*/
                end
            end
            WRITEBACK: begin
                // aw channel finish
                if(axi4_aw_valid & axi4_aw_ready) begin
                    axi4_aw_valid_c = 1'b0;
					//!!optimization: no need set 0 if valid=0
                    //!!axi4_aw_addr_c = 0;
                    addr_compl = 1;
                end

                // dw channel finish
                if(axi4_w_valid && axi4_w_last && axi4_w_ready) begin
                    axi4_w_valid_c = 0;
					//!!optimization: no need set 0 if valid=0
                    //!!axi4_w_data_c = 0;
                    //!!axi4_w_last_c = 0;
                    data_compl = 1;
                end

                //s0
                back_adr = seq_adr;
                if (((~axi4_w_valid && ~wait_bvalid_r && (~back_re_r2 || axi4_w_ready)) ||
                    //!!optmization: use seq_last instead of wcnt_r
                    (axi4_w_ready && axi4_w_valid)) && ~seq_last /*(wcnt_r<CACHE_LINE_LEN)*/ ) begin
                    seq_run = 1;
                    back_re = 1;
                    //!!wcnt = wcnt_r + 1;
                end
                //!!optimization: if axi4 is not ready, re-start mru read address with the address of previous pipeline stage.
                else if (axi4_w_valid & ~axi4_w_last & ~axi4_w_ready) begin
                   seq_start = 1;
                   seq_startAdr = back_adr_r2;
                   seq_startCnt = seq_cnt_r2;
                end

                //s1
                if (wait_bvalid_r && axi4_b_valid_r && addr_compl) begin
                    if (pend_refill_r) begin
                        pend_refill = 0;
                        state = REFILL;
                        //!!optmization: No issue AXI4 read request here
                        addr_compl = 0;
                        /*
                    // write a burst to mruCore
                        seq_start = 1'b1;
                        seq_startAdr = getCacheAdr(pend_refill_byte_ptr_r);
                    //prepare read-address channel
                        axi4_ar_valid = 1'b1;
                        axi4_ar_addr = pend_refill_byte_ptr_r;
                        */
                    end
                    else begin
                        state = READY;
                        resume = 1;
                    end
                    wait_bvalid = 0;
                end
                else if (~data_compl /*back_re_r2*/ && (axi4_w_ready || ~axi4_w_valid)) begin
                    axi4_w_valid_c = back_re_r2; //1;
                    axi4_w_data_c = back_rdat;
                    //!!optmization: use seq_cnt instead of wcnt_s1_r
                    axi4_w_last_c = (seq_cnt_r2 == CACHE_LINE_LEN-1);
                    //!!axi4_w_last = (wcnt_s1_r==CACHE_LINE_LEN-1);
                    //!!if (wcnt_s1_r<CACHE_LINE_LEN) begin
                    //!!    wcnt_s1 = wcnt_s1_r + 1;
                    //!!end
                end
                else if (data_compl && addr_compl) begin
                    //!!wcnt = 0;
                    //!!wcnt_s1 = 0;
                    if (axi4_b_valid_r) begin
                        if (pend_refill_r) begin
                            pend_refill = 0;
                            state = REFILL;
                            //!!optmization: No issue AXI4 read request here
                            addr_compl = 0;
                            /*
                        // write a burst to mruCore
                            seq_start = 1'b1;
                            seq_startAdr = getCacheAdr(pend_refill_byte_ptr_r);
                        //prepare read-address channel
                            axi4_ar_valid = 1'b1;
                            axi4_ar_addr = pend_refill_byte_ptr_r;
                            */
                        end
                        else begin
                            state = READY;
                            resume = 1;
                        end
                    end
                    else begin
                        wait_bvalid = 1;
                    end
                end
                //`combCap3(back_re, back_re_r, seq_start);
            end

            REFILL:    begin
            // write a burst to mruCore
                seq_start = seq_last & ~addr_compl;
                seq_startAdr = getCacheAdr(pend_refill_byte_ptr_r);
            //prepare read-address channel
                axi4_ar_valid_c = ~addr_compl;
                axi4_ar_addr_c = pend_refill_byte_ptr;

                back_we = axi4_r_valid;
                back_adr = seq_adr;
                back_wdat = dataBuf;
                seq_run = axi4_r_valid & axi4_r_ready;

                if (axi4_ar_ready & axi4_ar_valid) begin
					//!!optimization: no need set 0 if valid=0
                    //!!axi4_ar_addr_c = 0;
                    axi4_ar_valid_c = 0;
                    addr_compl = 1;
                end

                if(seq_last & addr_compl_r) begin
                    state = READY;
                    resume = 1;
                end
            end

        endcase
    end

    always_ff @(posedge clk or negedge rstn)
        if(~rstn) begin
            {axi4_aw_valid, axi4_aw_addr, /*axi4_w_ready_r,*/ axi4_w_last, axi4_w_valid, axi4_w_data, replaceWay_r, axi4_ar_addr, axi4_ar_valid, /*axi4_aw_ready_r,*/
            /*axi4_ar_ready_r,*/ axi4_b_valid_r, /*iniCnt_r,*/ pend_refill_r, pend_refill_byte_ptr_r, addr_compl_r, data_compl_r} <= '0;
            { init_done_pulse_r, resume_r, back_we_r, back_re_r, back_re_r2, back_adr_r, back_wdat_r, /*wcnt_r, wcnt_s1_r,*/ wait_bvalid_r} <=0;
            { seq_cnt_r, seq_cnt_r2, back_adr_r2, init_run_r} <= 0;
            state_r <= INIT;
        end
        else begin
            { init_done_pulse_r, resume_r, init_run_r} <= { init_done_pulse, resume, init_run};

            back_we_r <= back_we;
            if ((state_r==WRITEBACK && (axi4_w_ready || ~axi4_w_valid)) || (state_r!=WRITEBACK)) begin
                back_re_r <= back_re;
                back_re_r2 <= back_re_r;
                back_adr_r <= back_adr;
                back_adr_r2 <= back_adr_r;
                seq_cnt_r  <= seq_cnt;
                seq_cnt_r2 <= seq_cnt_r;
                //wcnt_r <= wcnt;
            end
            //!!optimization: if axi4 is not ready, disable all read enable of previous pipeline stage.
            else if (axi4_w_valid & ~axi4_w_ready) begin
                back_re_r <= 0;
                back_re_r2 <= 0;
            end

            back_wdat_r <= back_wdat;

            replaceWay_r <= replaceWay;
            //iniCnt_r <= iniCnt;
            axi4_aw_valid <= axi4_aw_valid_c;
            axi4_aw_addr <= axi4_aw_addr_c;
            axi4_w_valid <= axi4_w_valid_c;
            axi4_w_data <= axi4_w_data_c;
            //!!axi4_aw_ready_r <= axi4_aw_ready;
            //!!axi4_ar_ready_r <= axi4_ar_ready;
            state_r <= state;
            axi4_ar_addr <= axi4_ar_addr_c;
            axi4_ar_valid <= axi4_ar_valid_c;
            //!!axi4_w_ready_r <= axi4_w_ready;
            axi4_w_last <= axi4_w_last_c;
            axi4_b_valid_r <= axi4_b_valid;
            //!!wcnt_s1_r <= wcnt_s1;
            wait_bvalid_r <= wait_bvalid;
            pend_refill_r <= pend_refill;
            pend_refill_byte_ptr_r <= pend_refill_byte_ptr;
            addr_compl_r <= addr_compl;
            data_compl_r <= data_compl;
        end

    //sequencer #(.SEQ($clog2(CACHE_LINE_LEN)+1), .ADR(AW-4))
    sequencer #(.SEQ(SEQ), .ADR(AW))
    backSeq (
        .rstn       (rstn),
        .clk        (clk),
        .start      (seq_start),
        .run        (seq_run),
        .startAdr   (seq_startAdr),
        .startCnt   (seq_startCnt),
        .len        (seq_len),
        .adr_r      (seq_adr),
        .cnt_r      (seq_cnt),
        .last_r     (seq_last)
    );

    function [$clog2(CACHE_BYTE)-1:0] getCacheAdr;
        input [AW-1:0] userAdr;
        //input [LOG2_CACHE_WAY-1:0] cacheWay;
        //getCacheAdr = (get_set(userAdr)*CACHE_WAY+cacheWay)*CACHE_LINE_LEN;
        getCacheAdr = get_set(userAdr)*CACHE_LINE_LEN;
    endfunction

    function [LOG2_CACHE_SET-1:0] get_set;
        input [AW-1:0] adr;
        get_set = (adr/(CACHE_LINE_LEN*CACHE_WORD_BYTE)) & (SET_NUM - 1);
    endfunction
endmodule

module sequencer #(
    parameter int ADR = 32,
    parameter int SEQ = 4
) (
    input                   rstn,
    input                   clk,
    input                   start,
    input        [ADR-1:0]  startAdr,
    input        [SEQ-1:0]  startCnt,
    input        [SEQ:0]    len,
    input                   run,
    output reg   [ADR-1:0]  adr_r,
    output reg   [SEQ-1:0]  cnt_r,
    output reg              last_r
);

    //!!reg [SEQ-1:0]     cnt_r;

    always_ff @(posedge clk or negedge rstn) begin
        if(~rstn) begin
            adr_r<=0;
            last_r<=1;
            cnt_r<=0;
        end
        else begin
            if(start) begin
                //$display("start seq");
                adr_r <= startAdr;
                cnt_r <= startCnt;
                last_r <= 0;
            end
            else if(run) begin
                //$display("cnt_r=%d", cnt_r);
                cnt_r <= cnt_r + 1;
                adr_r <= adr_r + 1;
                if(cnt_r==len-1) last_r<=1;
            end
        end
    end

endmodule


