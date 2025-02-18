//- keep usiong 2way tag and data memory
//- add arrays partial_tag[SET], such that partial_tag[i] only stores the least significant p bits of the full tag, i.e. tag[i]
//
//The cache lookup is as following:
//cycle0:
//	- data_adr =  set * line_len+word_adr
//	- tag_adr = set
//	- partial_tag_adr= set
//cycle1:
//	- if(partial_tag_rdat[0]==user_tag) 		{ hitway=0; rdat=tag_rdat[0];}
//		else if(partial_tag_rdat[1]==user_tag) 	{ hitway=1; rdat=tag_rdat[1];}
//		else miss=1
//	- tag_rdat_r[0:1]=tag_rdat[0:1]
//cycle2:
//	- if(tag_rdat_r[0]==user_tag) 	{ rerun_hitway=0; rdat=tag_rdat_r[0]; }
//	else if(tag_rdat_r[1]==user_tag) 	{ rerun_hitway=1; rdat=tag_rdat_r[1]; }
//	else miss=1
//	if(miss==1 & rerun_hitway!=hitway && re_r2==1) rollback=1;

//- keep using 2way tag and data memory
//- add arrays partial_tag[SET], such that partial_tag[i] only stores the least significant p bits of the full tag, i.e. tag[i]
//
//The cache lookup is as following:
//cycle0:
//	- data_adr =  set * line_len+word_adr
//	- tag_adr = set
//	- partial_tag_adr= set and read partial tag at both ways
//  - read full tag at both ways
//cycle1:
//	if(partial_tag_rdat[0]==user_tag) 		{ hitway=0; rdat=tag_rdat[0]; rdat_r=tag_rdat[1]; }
//	else if(partial_tag_rdat[1]==user_tag)	{ hitway=1; rdat=tag_rdat[1]; rdat_r=tag_rdat[0]; }
//	else miss=1;
//	tag_rdat1_r=tag_rdat[1];
// 	if(tag_rdat[0]==user_tag) rerun_hit0=1;
// 	if(tag_rdat[1]==user_tag) rerun_hit1=1;
//cycle2:
//	rerun_hitway=rerun_hit1_r==1;
// 	miss = rerun_hit0_r & rerun_hit1_r;
//	if(miss==0 && rerun_hitway!=hitway && re_r2==1) { rollback=1; rdat=rdat_r; }

`include "vcap.vh"
import mru_pkg::*;

module speculative_mru  #(
    parameter int AXI_LEN_W = 8,
    parameter int DW = 32,
    parameter int AW = 32,
    parameter int CACHE_BYTE = 16*1024,
    parameter int CACHE_WAY = 2,
    parameter int CACHE_WORD_BYTE = DW / 8,
    parameter int CACHE_LINE_LEN = 8,
    parameter int ROLLBACK = 1
)(
    input                                 clk,
    input                                 rstn,
    output logic                          ready, // inform processor/DMA/flush if cache is not ready due to startup init, cache miss or RAW stall

    // requests from processor
    input                                 user_re,
    input                                 user_we,
    input        [CACHE_WORD_BYTE-1:0]    user_we_mask,
    input        [AW-1:0]                 user_adr,
    input        [DW-1:0]                 user_wdat,
    output logic [DW-1:0]                 user_rdat_o,
    output logic                          user_rdat_vld_o,

    //# DMA or flush requests from backend module
    //# both the RISC core and the backend module may contend to access valid and
    //     data mem in directHit. backend module will set valid to 0 when init or flushing
    //# the state maachine for init, flushing and dma are embedded in backend;
    //    directHit only provide the interface for backend to access valid and data memory
    input                                 back_re,         //# DMA write-> dm_rdat = mem[back_adr]
    input                                 back_we,         //# DMA read -> mem[back_adr]=back_wdat;
    input                                 back_init,       //# init: reset valid, mru and dirty to zero
    input                                 back_flush,      //# flush: writeback dataMem[backSet] if dirty[backSet]=1
    input        [AW-1:0]                 back_adr,
    input        [DW-1:0]                 back_wdat,
    output logic [DW-1:0]                 back_rdat,
    input        [$clog2(CACHE_WAY)-1:0]  back_inway,

//# miss handling: inform backend module which way to refill and writeback
    output logic [$clog2(CACHE_WAY)-1:0]  replaceWay,
    output logic                          writeback,
    output logic [AW-1:0]                 writeback_set,
    output logic                          refill,
    output logic [AW-1:0]                 refill_set,
    input                                 resume,

    output logic                          rollback
);

    localparam int WSTRB_W = DW / 8;
    localparam int LOG2_CACHE_WAY = $clog2(CACHE_WAY);
    localparam int CACHE_SET = (CACHE_BYTE/CACHE_WORD_BYTE/CACHE_LINE_LEN/CACHE_WAY);
    localparam int CACHE_TAG_BITS = AW-$clog2(CACHE_BYTE/CACHE_WAY);
    localparam int CACHE_TAG_PART_BITS = 4;
    localparam int ADBITS = $clog2(CACHE_SET*CACHE_LINE_LEN);
    localparam int LOG2_CACHE_BYTE = $clog2(CACHE_BYTE);
    localparam int LOG2_CACHE_SET = $clog2(CACHE_SET);
    localparam int NLM_BYTE = 32; //256 bit
    localparam int DATA_ADR_W = LOG2_CACHE_BYTE - 2 - LOG2_CACHE_WAY;
    localparam int CACHE_INIT_NUM = CACHE_BYTE / (CACHE_WAY * CACHE_LINE_LEN * CACHE_WORD_BYTE);
    localparam int LOG2_CACHE_WORD_BYTE = $clog2(CACHE_WORD_BYTE);
    localparam int LOG2_CACHE_LINE_LEN = $clog2(CACHE_LINE_LEN);
    localparam int SET_NUM = (CACHE_BYTE / CACHE_LINE_LEN / CACHE_WORD_BYTE / CACHE_WAY);
    localparam int SET_LSB = $clog2(CACHE_LINE_LEN*CACHE_WORD_BYTE);
    localparam int SET_MSB = SET_LSB + $clog2(SET_NUM) - 1;


    localparam int STATES_NUM = 6;
    typedef enum logic [$clog2(STATES_NUM)-1:0] {
        INIT            = 0,
        READY           = 1,
        MISS_START      = 2,
        FLUSH_START     = 3,
        STALL           = 4,
        RAW_DETECTED    = 5
    } state_t ;

    //request pipeline
    reg                         req_we, req_we_r, req_we_r2, req_we_r3;
    reg                         req_re, req_re_r, req_re_r2;
    reg                         flush_w, flush_r, flush_r2; // 4
    reg   [AW-1:0]              req_adr, req_adr_r, req_adr_r2; // 32
    reg   [DW-1:0]              req_wdat, req_wdat_r, req_wdat_r2; // 32
    reg   [CACHE_WORD_BYTE-1:0] req_we_mask, req_we_mask_r, req_we_mask_r2;
    reg                         access, access_r, access_r2; // 1
    logic [LOG2_CACHE_SET-1:0]  req_set, req_set_r, req_set_r2, req_set_r3;
    logic [CACHE_TAG_BITS-1:0]  req_tag, req_tag_r, req_tag_r2, req_tag_r3;


    // system
    reg [STATES_NUM-1:0]        state, state_r, state_r2; // 6
    reg                         raw_resume, hit, hit_r, hit_r2; // 1
    reg [CACHE_WAY-1:0]         hitway, hitway_r;//2
    reg [LOG2_CACHE_WAY-1:0]    replaceWay_r;//2

    // all memory using set_adr
    logic [LOG2_CACHE_SET-1:0]  tag_adr, tag_adr_r, tag_adr_r2;
    logic [LOG2_CACHE_SET-1:0]  mru_rad, mru_wad;
    reg [LOG2_CACHE_SET-1:0]    mru_rad_r, mru_rad_r2, mru_wad_r;//16

    // mesiState memory, shared with backend module
    logic                       mesiState_re;                   //#mesi
    reg                         mesiState_re_r, mesiState_re_r2;                   //#mesi
    logic [1:0]                 mesiState_wdat;                 //#mesi
    reg [1:0]                   mesiState_wdat_r;                 //#mesi
    logic [LOG2_CACHE_SET-1:0]  mesiState_wad, mesiState_rad;   //#mesi
    reg [LOG2_CACHE_SET-1:0]    mesiState_rad_r;               //#mesi
    reg [LOG2_CACHE_SET-1:0]    mesiState_rad_r2;               //#mesi
    reg [LOG2_CACHE_SET-1:0]    mesiState_wad_r;   //#mesi
    logic [CACHE_WAY-1:0]       mesiState_we;                   //#mesi
    reg   [CACHE_WAY-1:0]       mesiState_we_r;                   //#mesi
    wire  [2*CACHE_WAY-1:0]     mesiState_rdat;                 //#mesi
    reg [2*CACHE_WAY-1:0]       mesiState_rdat_r;               //#mesi
    reg [2*CACHE_WAY-1:0]       mesiState_rdat_r2;               //#mesi
    reg [1:0]                   mesiAction, mesiAction_r;
    reg [1:0]                   mesiReq, mesiReq_r;

    // tag memory
    logic                                 tag_re, tag_re_r;
    logic [CACHE_WAY-1:0]                 tag_we;
    logic [CACHE_TAG_BITS-1:0]            tag_wdat;//18*2
    wire  [CACHE_TAG_BITS*CACHE_WAY-1:0]  tag_rdat;
    reg   [CACHE_TAG_BITS*CACHE_WAY-1:0]  tag_rdat_r, tag_rdat_r2;

    // partial tag memory
    logic [LOG2_CACHE_SET-1:0]                 part_tag_adr, part_tag_adr_r, part_tag_adr_r2;
    logic                                      part_tag_re;
    logic [CACHE_WAY-1:0]                      part_tag_we;
    logic [CACHE_TAG_PART_BITS-1:0]            part_tag_wdat;
    wire  [CACHE_TAG_PART_BITS*CACHE_WAY-1:0]  part_tag_rdat;

    logic [LOG2_CACHE_WAY-1:0]                 rerun_hitway, rerun_hitway_r, rerun_hitway_r2;
    logic [LOG2_CACHE_WAY-1:0]                 flush_way, flush_way_r;
    logic                                      rerun_hit, rerun_hit_r, rerun_hit_r2;
    logic                                      rerun_hit0, rerun_hit0_r;
    logic                                      rerun_hit1, rerun_hit1_r;

    // mru memory
    logic                       mru_re, mru_re_r, mru_re_r2;//1
    logic                       mru_wdat, mru_wdat_r;//1
    reg   [CACHE_WAY-1:0]       mru_rdat_r, mru_rdat_r2, mru_rdat_r3, mru_rdat_bypass;//1
    reg   [CACHE_WAY-1:0]       mru_we, mru_we_r;//1
    wire  [CACHE_WAY-1:0]       mru_rdat;
    logic                       found;
    logic [CACHE_WAY-1:0]       mru_wdat_vector, mru_wdat_vector_r;//1

    // data memory
    logic [DATA_ADR_W-1:0]      data_adr;
    reg                         data_re, data_re_r;//1
    logic [CACHE_WORD_BYTE-1:0] data_we[CACHE_WAY];
    logic [DW-1:0]              data_wdat;
    wire  [DW-1:0]              data_rdat[CACHE_WAY];
    reg   [DW-1:0]              data_rdat_r;

    reg                         resume_r, resume_r2;

    logic                       writeback_w;
    logic [AW-1:0]              writeback_set_w;
    logic                       refill_w;
    logic [AW-1:0]              refill_set_w;
    logic [LOG2_CACHE_WAY-1:0]  replaceWay_w;
    logic [LOG2_CACHE_WAY-1:0]  rdat_way;

    logic [DW-1:0]              user_rdat_w;
    logic                       user_rdat_vld_w;

    logic                       raw_detect;
    logic                       rollback_r;
    logic                       pend_flush, pend_flush_r;

    always_ff @(posedge clk or negedge rstn)
        if(~rstn) begin
            {flush_r2, flush_r} <= 0;
            {req_adr_r, req_re_r, req_we_r, req_wdat_r, req_we_mask_r} <= 0;
            {req_adr_r2, req_re_r2, req_we_r3, req_we_r2, req_wdat_r2, req_we_mask_r2} <= 0;
            data_re_r <= 0;
            state_r <= 1 << INIT;
            state_r2 <= 1 << INIT;
            replaceWay_r<=0;
            hitway_r <=0;
            {hit_r2, hit_r, access_r}<=0;
            access_r2 <= 0;
            {mru_rdat_r3, mru_rdat_r2, mru_rdat_r} <=0;
            {mru_re_r2, mru_re_r} <= 0;
            {mru_rad_r2, mru_rad_r} <= 0;
            mru_wdat_r<=0;
            mru_wad_r <= 0;
            mru_we_r<=0;
            mru_wdat_vector_r <= 0;
            {mesiState_rdat_r2, mesiState_rdat_r} <= 0;
            tag_re_r <= 0;
            {tag_rdat_r2, tag_rdat_r} <= 0;
            mesiAction_r <= MESI_ACT_NULL;
            mesiReq_r <= MESI_REQ_NULL;
            resume_r <= 0;
            resume_r2 <= 0;

            writeback <= 0;
            writeback_set <= 0;
            refill <= 0;
            refill_set <= 0;
            replaceWay <= 0;
            mesiState_wdat_r <= MESI_STATE_INVALID;
            mesiState_wad_r <= 0;
            mesiState_we_r <= 0;
            mesiState_re_r <= 0;
            mesiState_re_r2 <= 0;
            mesiState_rad_r <= 0;
            mesiState_rad_r2 <= 0;

            {rerun_hitway_r2, rerun_hitway_r} <= 0;
            {rerun_hit_r2, rerun_hit_r} <= 0;
            data_rdat_r <= 0;
            rerun_hit0_r <= 0;
            rerun_hit1_r <= 0;


            {req_set_r3, req_set_r2, req_set_r} <= 0;
            {req_tag_r3, req_tag_r2, req_tag_r} <= 0;
            {tag_adr_r2, tag_adr_r} <= 0;
            {part_tag_adr_r2, part_tag_adr_r} <= 0;

            //user_rdat_o <= 0;
            //user_rdat_vld_o <= 0;
            rollback_r <= 0;
            flush_way_r <= 0;
            pend_flush_r <= 0;
        end
        else begin
            state_r <= state;
            state_r2 <= state_r;
            data_re_r <= data_re;
            replaceWay_r <= replaceWay_w;
            mru_we_r <= mru_we;
            {mru_re_r2, mru_re_r} <= {mru_re_r, mru_re};
            {mru_rad_r2, mru_rad_r} <= {mru_rad_r, mru_rad};
            if (mru_we!=0) begin
                mru_wdat_vector_r <= mru_wdat_vector;
                mru_wdat_r <= mru_wdat;
                mru_wad_r <= mru_wad;
            end

            for(int w=0; w<CACHE_WAY; w++) begin
                if ((mru_wad_r==mru_rad_r) && (mru_wdat_r!=0) && mru_re_r && (mru_we_r!=0)) begin
                    mru_rdat_r[w] <= mru_wdat_vector_r[w];
                end
                else if ((mru_wad==mru_rad_r) && (mru_wdat!=0) && mru_re_r && (mru_we!=0)) begin
                    mru_rdat_r[w] <= mru_wdat_vector[w];
                end
                else if (mru_re_r) begin
                    mru_rdat_r[w] <= mru_rdat[w];
                end
            end

            {mru_rdat_r3, mru_rdat_r2} <= {mru_rdat_r2, mru_rdat_r};

            for (int w=0; w<CACHE_WAY; w++) begin
                if (mesiState_we[w] && mesiState_re_r2 && (mesiState_rad_r2==mesiState_wad)) begin
                    mesiState_rdat_r2[w*2 +: 2] <= mesiState_wdat;
                end
                else begin
                    mesiState_rdat_r2[w*2 +: 2] <= mesiState_rdat_r[w*2 +: 2];
                end
            end

            for (int w=0; w<CACHE_WAY; w++) begin
                if (mesiState_we_r[w] && mesiState_re_r && (mesiState_rad_r==mesiState_wad_r)) begin
                    mesiState_rdat_r[w*2 +: 2] <= mesiState_wdat_r;
                end
                else if (mesiState_we[w] && mesiState_re_r && (mesiState_rad_r==mesiState_wad)) begin
                    mesiState_rdat_r[w*2 +: 2] <= mesiState_wdat;
                end
                else if (mesiState_re_r) begin
                    mesiState_rdat_r[w*2 +: 2] <= mesiState_rdat[w*2 +: 2];
                end
            end


            tag_re_r <= tag_re;
            {tag_rdat_r2, tag_rdat_r} <= {tag_rdat_r, tag_rdat};

            rollback_r <= rollback;
            {req_set_r3, req_set_r2, req_set_r} <= {req_set_r2, req_set_r, req_set};
            {req_tag_r3, req_tag_r2, req_tag_r} <= {req_tag_r2, req_tag_r, req_tag};

            req_adr_r <= req_adr;
            req_re_r <= req_re;
            req_we_r <= req_we;
            req_wdat_r <= req_wdat;
            req_we_mask_r <= req_we_mask;

            req_adr_r2 <= req_adr_r;
            req_re_r2 <= req_re_r;
            req_we_r2 <= req_we_r;
            req_we_r3 <= req_we_r2;
            req_wdat_r2 <= req_wdat_r;
            req_we_mask_r2 <= req_we_mask_r;

            resume_r <= (resume && !state_r[INIT]);
            resume_r2 <= resume_r;

            {flush_r2, flush_r} <= {flush_r, flush_w};
            if (hit) hitway_r <= hitway;
            {hit_r2, hit_r, access_r} <= {hit_r, hit, access};
            access_r2 <= access_r;
            mesiAction_r <= mesiAction;
            mesiReq_r <= mesiReq;

            writeback <= writeback_w;
            writeback_set <= writeback_set_w;
            refill <= refill_w;
            refill_set <= refill_set_w;
            replaceWay <= replaceWay_w;
            mesiState_wdat_r <= mesiState_wdat;
            mesiState_wad_r <= mesiState_wad;
            mesiState_we_r <= mesiState_we;
            mesiState_re_r <= mesiState_re;
            mesiState_re_r2 <= mesiState_re_r;
            mesiState_rad_r <= mesiState_rad;
            mesiState_rad_r2 <= mesiState_rad_r;

            {rerun_hitway_r2, rerun_hitway_r} <= {rerun_hitway_r, rerun_hitway};
            {rerun_hit_r2, rerun_hit_r} <= {rerun_hit_r, rerun_hit};
            rerun_hit0_r <= rerun_hit0;
            rerun_hit1_r <= rerun_hit1;

            data_rdat_r <= data_rdat[rdat_way];

            {tag_adr_r2, tag_adr_r} <= {tag_adr_r, tag_adr};
            {part_tag_adr_r2, part_tag_adr_r} <= {part_tag_adr_r, part_tag_adr};

            //user_rdat_o <= user_rdat_w;
            //user_rdat_vld_o <= user_rdat_vld_w;
            flush_way_r <= flush_way;
            pend_flush_r <= pend_flush;
        end

    assign user_rdat_o = user_rdat_w;
    assign user_rdat_vld_o = user_rdat_vld_w;
    assign back_rdat = user_rdat_w;

    always @ (*) begin // COMB1

        {tag_re, tag_we, tag_wdat} = 0;
        {part_tag_re, part_tag_we, part_tag_wdat} = 0;
        //data_re = 0;
        data_we = '{default: 0};
        {mru_re, mru_we, mru_wad, mru_wdat} = 0;
        {mesiState_re, mesiState_we, mesiState_wad, mesiState_wdat} = 0;
        {writeback_w, writeback_set_w, refill_w, refill_set_w, found} = 0;
        access = 0;
        ready = 0;

        replaceWay_w = replaceWay_r;
        req_adr = req_adr_r;
        req_re = req_re_r;
        req_we = req_we_r;
        req_wdat = req_wdat_r;
        req_we_mask = req_we_mask_r;
        mru_wdat_vector = mru_wdat_vector_r;
        mesiAction = mesiAction_r;
        mesiReq = mesiReq_r;

        flush_w = flush_r;
        pend_flush = pend_flush_r;

        //------------------------------------ stage 0 ------------------------------------ //
        if(state_r[READY] && (~state_r2[RAW_DETECTED] || (ROLLBACK==0))) begin
            if(user_re | user_we | back_flush) begin
                access=1;
                flush_w = back_flush;
                req_re = user_re;
                req_we = user_we;
                req_adr = user_adr;
                req_wdat = user_wdat;
                req_we_mask = user_we_mask;
            end
            else if (back_re | back_we) begin
                access = 1;
                flush_w = 0;
                req_re = back_re;
                req_we = back_we;
                req_adr = back_adr;
                req_wdat = back_wdat;
                req_we_mask = {CACHE_WORD_BYTE {back_we}};
            end
        end
        else if(resume && state_r[STALL]) begin
            access = 1;
            pend_flush = 0;
            flush_w = pend_flush_r;
        end
        else if (state_r[RAW_DETECTED]) begin
            access=1;
            req_re=1;
            req_we=0;
        end

        if (resume || (state_r[READY]) || (state_r[RAW_DETECTED])) begin
            part_tag_re = access && (ROLLBACK==1);
            tag_re      = access;
            mru_re      = access;
            mesiState_re = access;
        end

        req_set = get_set(req_adr);
        req_tag = get_tag(req_adr);
        tag_adr = req_set;
        part_tag_adr = (ROLLBACK==1) ? req_set : 0;
        mru_rad = req_set;
        mesiState_rad = req_set;
        mesiState_wad = req_set;

        //------------------------------------ stage 1 ------------------------------------ //
        hit = 0;
        hitway = 0;
        rerun_hit0 = 0;
        rerun_hit1 = 0;

        data_re = mru_re_r & req_re_r;
        data_adr = get_data_adr(req_adr_r);

        if(state_r[READY] && access_r==1) begin
            if (ROLLBACK==1) begin
                for(int w=0; w<CACHE_WAY; w++) begin
                    if(mesiState_rdat[w*2 +: 2]!=MESI_STATE_INVALID &&
                        req_tag_r[CACHE_TAG_PART_BITS-1:0]==part_tag_rdat[w*CACHE_TAG_PART_BITS +: CACHE_TAG_PART_BITS]) begin
                        hit = 1;
                        hitway[w] = 1;
                    end
                end

                if(req_tag_r==tag_rdat[0*CACHE_TAG_BITS +: CACHE_TAG_BITS]) begin
                    rerun_hit0 = 1;
                end
                if(req_tag_r==tag_rdat[1*CACHE_TAG_BITS +: CACHE_TAG_BITS]) begin
                    rerun_hit1 = 1;
                end
            end
            else begin
                if(mesiState_rdat[0*2 +: 2]!=MESI_STATE_INVALID &&
                    req_tag_r==tag_rdat[0*CACHE_TAG_BITS +: CACHE_TAG_BITS]) begin
                    hit = 1;
                    hitway[0] = 1;
                    rerun_hit0 = 1;
                end

                if(mesiState_rdat[1*2 +: 2]!=MESI_STATE_INVALID &&
                    req_tag_r==tag_rdat[1*CACHE_TAG_BITS +: CACHE_TAG_BITS]) begin
                    hit = 1;
                    hitway[1] = 1;
                    rerun_hit1 = 1;
                end
            end
        end

        if (ROLLBACK==1) begin
            //------------------------------------ stage 2 ------------------------------------ //
            rerun_hit = ((rerun_hit0_r && hitway_r[0]) || (rerun_hit1_r && hitway_r[1])) && (state_r[READY]);
            rerun_hitway = (rerun_hit1_r && hitway_r[1])? 1 : 0;
            flush_way = flush_way_r;
            rdat_way = (state_r[STALL] && ~flush_r) ? replaceWay_r :
                        flush_r2                    ? flush_way_r  :
                                                    rerun_hitway;
            user_rdat_w = data_rdat[rdat_way];

            user_rdat_vld_w = rerun_hit && req_re_r2 && ~req_we_r2 && (!state_r[RAW_DETECTED]);
            raw_detect = (access_r && access_r2 && req_we_r2 && req_re_r && rerun_hit);

            if (~rerun_hit && access_r2 && ~flush_r2 && state_r[READY]) begin
                req_re = req_re_r2;
                req_we = req_we_r2;
                req_we_mask = req_we_mask_r2;
                req_adr = req_adr_r2;
                req_wdat = req_wdat_r2;
                req_set = get_set(req_adr_r2);
                req_tag = get_tag(req_adr_r2);
                tag_re = 0;
                mesiState_re = 0;
            end
            else if ((~hit && access_r && ~flush_r && state_r[READY]) || raw_detect) begin
                req_re = req_re_r;
                req_we = req_we_r;
                req_we_mask = req_we_mask_r;
                req_adr = req_adr_r;
                req_wdat = req_wdat_r;
                req_set = get_set(req_adr_r);
                req_tag = get_tag(req_adr_r);
                tag_re = 0;
                mesiState_re = 0;
            end
            else if (hit_r && rerun_hit && flush_r2 && flush_r && mesiState_rdat_r[rerun_hitway*2 +: 2]==MESI_STATE_MODIFIED) begin
                req_adr = req_adr_r;
                req_set = get_set(req_adr_r);
                req_tag = get_tag(req_adr_r);
                pend_flush = 1;
            end

            rollback = (~rerun_hit && hit_r) && state_r[READY] && access;

            data_wdat = req_wdat_r2;
            if (rerun_hit & req_we_r2) begin
                data_re = 0;
                data_adr = get_data_adr(req_adr_r2);
                data_we[rerun_hitway] = req_we_mask_r2;
            end


            //# stage3: update MRU, dirty bit of the hit line
            if(rerun_hit_r) begin
                // update mru
                mru_wad = req_set_r3;
                {mru_wdat, mru_we, mru_wdat_vector} = update_mru(
                    rerun_hitway_r,
                    mru_rdat_r2,
                    req_set_r3,
                    mru_wad_r,
                    mru_we_r,
                    mru_wdat_vector_r
                );

                mesiState_wad = req_set_r3;
                mesiState_wdat = MESI_STATE_MODIFIED;
                mesiState_we = req_we_r3 << rerun_hitway_r;
            end
        end
        else begin
            rerun_hit = ((rerun_hit0 && hitway[0]) || (rerun_hit1 && hitway[1])) && (state_r[READY]);
            rerun_hitway = (rerun_hit1 && hitway[1]) ? 1 : 0;
            flush_way = flush_way_r;
            rdat_way = (state_r[STALL] && ~flush_r) ? replaceWay_r :
                        flush_r2                    ? flush_way_r  :
                                                    rerun_hitway_r;
            user_rdat_w = data_rdat[rdat_way];

            user_rdat_vld_w = rerun_hit_r && req_re_r2 && ~req_we_r2 && (!state_r[RAW_DETECTED]);
            raw_detect = (access && access_r && req_we_r && req_re && rerun_hit);

            if ((~hit && access_r && ~flush_r && state_r[READY])/* || raw_detect*/) begin
                req_re = req_re_r;
                req_we = req_we_r;
                req_we_mask = req_we_mask_r;
                req_adr = req_adr_r;
                req_wdat = req_wdat_r;
                req_set = get_set(req_adr_r);
                req_tag = get_tag(req_adr_r);
                tag_re = 0;
                mesiState_re = 0;
            end
            else if (hit && flush_r && mesiState_rdat[rerun_hitway*2 +: 2]==MESI_STATE_MODIFIED) begin
                req_adr = req_adr_r;
                req_set = get_set(req_adr_r);
                req_tag = get_tag(req_adr_r);
                pend_flush = 1;
            end

            rollback = 0;

            data_wdat = req_wdat_r;
            if (rerun_hit & req_we_r) begin
                data_re = 0;
                data_adr = get_data_adr(req_adr_r);
                data_we[rerun_hitway] = req_we_mask_r;
            end


            //# stage3: update MRU, dirty bit of the hit line
            if(rerun_hit_r) begin
                // update mru
                mru_wad = req_set_r2;
                {mru_wdat, mru_we, mru_wdat_vector} = update_mru(
                    rerun_hitway_r,
                    mru_rdat_r,
                    req_set_r2,
                    mru_wad_r,
                    mru_we_r,
                    mru_wdat_vector_r
                );

                mesiState_wad = req_set_r2;
                mesiState_wdat = MESI_STATE_MODIFIED;
                mesiState_we = req_we_r2 << rerun_hitway_r;
            end
        end

        //------------------------------------ fsm ---------------------------------------- //
        state = 0;//state_r;
        case(1'b1)
            state_r[INIT]: begin
                for(int i=0; i<CACHE_WAY; i++) begin
                    mru_we[i] = 1;
                    mesiState_we[i] = 1;
                end
                mru_wad = back_adr;
                mru_wdat = 0;
                mesiState_wad = back_adr;
                mesiState_wdat = MESI_STATE_INVALID;
                if (resume)
                    state[READY] = 1;
                else
                    state[INIT] = 1;
            end

            state_r[READY]: begin
                ready = 1;
                if (back_init) begin
                    state[INIT] = 1;
                    ready=0;
                end
                else if ((state_r2[RAW_DETECTED] && (ROLLBACK==1)) || (state_r[RAW_DETECTED] && (ROLLBACK==0))) begin
                    state[READY] = 1;
                    access = 0;
                    ready = 0;
                end
                else if(flush_r2 && (ROLLBACK==1) && rerun_hit && mesiState_rdat_r[rerun_hitway*2 +: 2]==MESI_STATE_MODIFIED) begin
                    ready = 0;
                    access = 0;
                    flush_way = rerun_hitway;
                    state[FLUSH_START] = 1;
                end
                else if(flush_r && (ROLLBACK==0) && rerun_hit && mesiState_rdat[rerun_hitway*2 +: 2]==MESI_STATE_MODIFIED) begin
                    ready = 0;
                    access = 0;
                    flush_way = rerun_hitway;
                    state[FLUSH_START] = 1;
                end
                else if (((access_r & ~hit & ~flush_r) || (access_r2 && ~rerun_hit && (!state_r2[RAW_DETECTED]) && ~flush_r2 && ROLLBACK==1))) begin
                    state[MISS_START] = 1;
                    access = 0;
                    ready = 0;
                    flush_w = 0;
                end
                else if (raw_detect) begin
                    state[RAW_DETECTED] = 1;
                    access = 0;
                    ready = 0;
                    flush_w = 0;
                end
                else begin
                    state[READY] = 1;
                end
            end

            state_r[MISS_START]: begin
                found=0;
                for(int w=0; w<CACHE_WAY; w++) begin
                    if(found==0 && mru_rdat_r[w]==0) begin
                        found=1;
                        replaceWay_w=w;
                    end
                end
                if(found==0) begin
                    $finish;
                end

                if (ROLLBACK==0) begin
                    writeback_w = ((mesiState_rdat_r[replaceWay_w*2 +: 2]==MESI_STATE_MODIFIED)) ||
                                (rerun_hit_r && req_we_r2 && (req_set_r==req_set_r2) && (rerun_hitway_r==replaceWay_w));
                    writeback_set_w = (tag_rdat_r[replaceWay_w*CACHE_TAG_BITS +: CACHE_TAG_BITS] << (AW-CACHE_TAG_BITS)) + req_set_r*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                end
                else if (~rollback_r) begin
                    writeback_w = ((mesiState_rdat_r[replaceWay_w*2 +: 2]==MESI_STATE_MODIFIED)) ||
                                (rerun_hit_r && req_we_r3 && (req_set_r2==req_set_r3) && (rerun_hitway_r==replaceWay_w));
                    writeback_set_w = (tag_rdat_r[replaceWay_w*CACHE_TAG_BITS +: CACHE_TAG_BITS] << (AW-CACHE_TAG_BITS)) + req_set_r*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                end
                else begin
                    writeback_w = ((mesiState_rdat_r2[replaceWay_w*2 +: 2]==MESI_STATE_MODIFIED));
                    writeback_set_w = (tag_rdat_r2[replaceWay_w*CACHE_TAG_BITS +: CACHE_TAG_BITS] << (AW-CACHE_TAG_BITS)) + req_set_r*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                end
                refill_w = 1;
                refill_set_w = (req_tag_r << (AW-CACHE_TAG_BITS)) + req_set_r*(CACHE_LINE_LEN*CACHE_WORD_BYTE);

                mesiAction = MESI_ACT_REFILL;
                mesiReq = req_we_r2 ? MESI_REQ_HANDLE_WRITE_MISS : MESI_REQ_HANDLE_READ_MISS;

                state[STALL] = 1;
            end

            state_r[FLUSH_START]: begin
                mesiState_re=0;
                mesiState_we = 1 << rerun_hitway_r;
                mesiState_wdat=MESI_STATE_INVALID;
                writeback_w = 1;
                state[STALL] = 1;
                if (ROLLBACK==1) begin
                    mesiState_wad = req_set_r3;
                    writeback_set_w = (tag_rdat_r2[rerun_hitway_r*CACHE_TAG_BITS +: CACHE_TAG_BITS] << (AW-CACHE_TAG_BITS)) + req_set_r3*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                end
                else begin
                    mesiState_wad = req_set_r2;
                    writeback_set_w = (tag_rdat_r[rerun_hitway_r*CACHE_TAG_BITS +: CACHE_TAG_BITS] << (AW-CACHE_TAG_BITS)) + req_set_r2*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                end
            end

            state_r[STALL]: begin
                if (mesiAction_r!=MESI_ACT_NULL) begin
                    tag_we = 1 << replaceWay_r;
                    //tag_adr = req_set_r;
                    tag_wdat = req_tag_r2;

                    part_tag_we = (ROLLBACK==1) ? (1 << replaceWay_r) : 0;
                    //part_tag_adr = req_set_r;
                    part_tag_wdat = (ROLLBACK==1) ? req_tag_r2[CACHE_TAG_PART_BITS-1:0] : 0;

                    mesiState_we = 1 << replaceWay_r;
                    mesiState_wad = req_set_r;

                    if(mesiReq_r==MESI_REQ_HANDLE_WRITE_MISS) begin
                        mesiState_wdat = MESI_STATE_MODIFIED;
                    end
                    else begin
                        mesiState_wdat = MESI_STATE_EXCLUSIVE;
                    end
                    mesiAction = MESI_ACT_NULL;
                end

                if (resume) begin
                    state[READY] = 1;
                    //flush_w = 0;//pend_flush_r;
                end
                else begin
                    state[STALL] = 1;

                    data_re = back_re;
                    data_we[replaceWay_r] = (back_we) ? {CACHE_WORD_BYTE {1'b1}} : 0;
                    data_adr = back_adr;
                    data_wdat = back_wdat;
                end
            end

            state_r[RAW_DETECTED]: begin
                state[READY] = 1;
                if (ROLLBACK==0) ready = 1;
            end
        endcase

        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    end

    // nway_sp_dist #(.N(CACHE_WAY), .DATA_WIDTH(TAG_BITS), .ADDR_WIDTH(LOG2_CACHE_SET))
    nway_sp_dist #(
        .N          (CACHE_WAY),
        .DATA_WIDTH (CACHE_TAG_BITS),
        .ADDR_WIDTH (LOG2_CACHE_SET),
        .RAM_TYPE   ("distributed")
    )tagMem(
        .clk  (clk),
        .re   (tag_re),
        .we   (tag_we),
        .adr  (tag_adr),
        .wdat (tag_wdat),
        .rdat (tag_rdat)
    );

    generate
        if (ROLLBACK==1) begin: PART_TAG_MEM_BLK
            nway_sp_dist #(
                .N          (CACHE_WAY),
                .DATA_WIDTH (CACHE_TAG_PART_BITS),
                .ADDR_WIDTH (LOG2_CACHE_SET),
                .RAM_TYPE   ("distributed")
            )partTagMem(
                .clk  (clk),
                .re   (part_tag_re),
                .we   (part_tag_we),
                .adr  (part_tag_adr),
                .wdat (part_tag_wdat),
                .rdat (part_tag_rdat)
            );
        end
        else begin: NO_PART_TAG_BLK
            assign part_tag_rdat = 0;
        end
    endgenerate

    multi_we_sp_bram #(
        .NUM_COL    (CACHE_WAY),
        .COL_WIDTH  (DW),
        .ADDR_WIDTH (LOG2_CACHE_BYTE-2-LOG2_CACHE_WAY)
    ) dataMem (
        .clk  (clk),
        .re   (data_re),
        .we   (data_we),
        .adr  (data_adr),
        .wdat (data_wdat),
        .rdat (data_rdat)
    );

    nway_dp_dist #(
        .N          (CACHE_WAY),
        .DATA_WIDTH (1),
        .ADDR_WIDTH (LOG2_CACHE_SET),
        .RAM_TYPE   ("distributed")
    ) mruMem (
        .clk  (clk),
        .re   (mru_re),
        .rad  (mru_rad),
        .rdat (mru_rdat),
        .we   (mru_we),
        .wad  (mru_wad),
        .wdat (mru_wdat)
    );

    nway_dp_dist #(
        .N          (CACHE_WAY),
        .DATA_WIDTH (2),
        .ADDR_WIDTH (LOG2_CACHE_SET),
        .RAM_TYPE   ("distributed")
    ) mesiMem (
        .clk  (clk),
        .re   (mesiState_re),
        .rad  (mesiState_rad),
        .rdat (mesiState_rdat),
        .we   (mesiState_we),
        .wad  (mesiState_wad),
        .wdat (mesiState_wdat)
    );

    function automatic [CACHE_WAY*2:0] update_mru(
        input [$clog2(CACHE_WAY)-1:0]   _newWay,
        input [CACHE_WAY-1:0]           _mru_rdat_r,
        input [AW-1:0]                  _last_wad,
        input [AW-1:0]                  _cur_wad,
        input [CACHE_WAY-1:0]           _mru_we_r,
        input [CACHE_WAY-1:0]           _mru_wdat_vector_r
    );
        logic [LOG2_CACHE_WAY-1:0]  mruOneCnt = 0;
        logic                       new_wdat;
        logic [CACHE_WAY-1:0]       new_we;
        logic [CACHE_WAY-1:0]       mru_rdat_bypass;
        logic [CACHE_WAY-1:0]       mru_wdat_vector;

        mru_rdat_bypass = (_mru_we_r!=0 && _cur_wad==_last_wad) ?  mru_wdat_vector_r : _mru_rdat_r;

        for (int w = 0; w < CACHE_WAY; w++) begin
            if (mru_rdat_bypass[w] == 1) begin
                mruOneCnt = mruOneCnt + 1;
            end
        end
        if((mruOneCnt==CACHE_WAY-1 && (mru_rdat_bypass[_newWay]==0))) begin
            new_wdat=0;
            new_we = -1;
            mru_wdat_vector = 0;
        end
        else begin
            new_wdat=1;
            new_we = (1 << _newWay);
            mru_wdat_vector = (1 << _newWay) | mru_rdat_bypass;
        end
        update_mru = {new_wdat, new_we, mru_wdat_vector};
    endfunction


    function [LOG2_CACHE_LINE_LEN-1:0] get_word_of_line;
        input [AW-1:0] adr;
        get_word_of_line = (adr/(AW/8)) & (CACHE_LINE_LEN - 1);
        // get_word_of_line = (adr/4)%CACHE_LINE_LEN;
    endfunction

    // function [LOG2_CACHE_SET-1:0] get_data_word;
    function [$clog2(CACHE_BYTE)-2-$clog2(CACHE_WAY):0] get_data_adr;
        input [AW-1:0] adr;
        begin
            get_data_adr = (get_set(adr) * CACHE_LINE_LEN) + ((adr / CACHE_WORD_BYTE) % CACHE_LINE_LEN);
        end
    endfunction

    function [LOG2_CACHE_SET-1:0] get_set;
        input [AW-1:0] adr;
        //get_set = (adr/(CACHE_LINE_LEN*CACHE_WORD_BYTE)) & (SET_NUM - 1);
        get_set = adr[SET_MSB:SET_LSB];
    endfunction

    function [CACHE_TAG_BITS-1:0] get_tag;
        input [AW-1:0] adr;
        get_tag = adr[(AW-1) : (AW-CACHE_TAG_BITS)];
    endfunction

endmodule



