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

// >>1.  set1 hit and set2 hit
// C0: fetch set1, rd req for mesi and tag mem for set1
// C1: check hit for set1, rd mesi and tag for set2
// C2: check hit for set2
//
// >>2. set1 hit and set2 miss
// C0: fetch set1, rd req for mesi and tag mem for set1
// C1: check hit for set1, rd mesi and tag for set2
// C2: check hit for set2, hit is 0 => refill
// C3: MISS_START
// C4-CN: STALL, refill for set2
// CN+1: received resume, rd req for mesi and tag mem for set1
// CN+2: check hit for set1, rd mesi and tag for set2
// CN+3: check hit for set2
//
// >>3. set1 miss and set2 hit
// C0: fetch set1, rd req for mesi and tag mem for set1
// C1: check hit for set1, hit is 0 => refill
// C2: MISS_START
// C3-CN: STALL, refill for set1
// CN+1: received resume, rd req for mesi and tag mem for set1
// CN+2: check hit for set1, rd req for mesi and tag mem for set2
// CN+3: check hit for set2
//
// >>3. set1 miss and set2 hit
// C0: fetch set1, rd req for mesi and tag mem for set1
// C1: check hit for set1, hit is 0 => refill
// C2: MISS_START
// C3-CN: STALL, refill for set1
// CN+1: received resume, rd req for mesi and tag mem for set1
// CN+2: check hit for set1, rd req for mesi and tag mem for set2
// CN+3: check hit for set2, hit=0 => refill
// CN+4: MISS_START
// CN-CM: STALL, refill for set2
// CM+1: received resume, rd req for mesi and tag mem for set1
// CM+2: check hit for set1, rd mesi and tag for set2
// CM+3: check hit for set2


`include "vcap.vh"
//import cyclicCache_pkg::*;
import mru_pkg::*;

module cyclicCacheCore  #(
    parameter int AXI_LEN_W = 8,
    parameter int DW = 32,
    parameter int USER_DW = 128,
    parameter int USER_MAX_LEN = USER_DW / DW,
    parameter int AW = 32,
    parameter int CACHE_BYTE = 16*1024,
    parameter int CACHE_WAY = 2,
    parameter int CACHE_WORD_BYTE = DW / 8,
    parameter int CACHE_LINE_LEN = 8
)(
    input                                   clk,
    input                                   rstn,
    output logic                            ready, // inform processor/DMA/flush if cache is not ready due to startup init, cache miss or RAW stall

    // requests from processor
    input                                   user_re,
    input                                   user_we,
    input        [$clog2(USER_MAX_LEN)-1:0] user_len,//00-1 word; 01 - 2 words; ....
    input        [AW-1:0]                   user_adr,
    input        [USER_DW-1:0]              user_wdat,
    output logic [USER_DW-1:0]              user_rdat_o,
    output logic                            user_rdat_vld_o,

    //# DMA or flush requests from backend module
    //# both the RISC core and the backend module may contend to access valid and
    //     data mem in directHit. backend module will set valid to 0 when init or flushing
    //# the state maachine for init, flushing and dma are embedded in backend;
    //    directHit only provide the interface for backend to access valid and data memory
    input                                   back_re,         //# DMA write-> dm_rdat = mem[back_adr]
    input                                   back_we,         //# DMA read -> mem[back_adr]=back_wdat;
    input                                   back_init,       //# init: reset valid, mru and dirty to zero
    input                                   back_flush,      //# flush: writeback dataMem[backSet] if dirty[backSet]=1
    input        [AW-1:0]                   back_adr,
    input        [DW-1:0]                   back_wdat,
    output logic [DW-1:0]                   back_rdat,
    input        [$clog2(CACHE_WAY)-1:0]    back_inway,

//# miss handling: inform backend module which way to refill and writeback
    output logic [$clog2(CACHE_WAY)-1:0]    replaceWay,
    output logic                            writeback,
    output logic [AW-1:0]                   writeback_set,
    output logic                            refill,
    output logic [AW-1:0]                   refill_set,
    input                                   resume
);

    localparam int LOG2_USER_MAX_LEN = $clog2(USER_MAX_LEN);
    localparam int WSTRB_W = DW / 8;
    localparam int LOG2_CACHE_WAY = $clog2(CACHE_WAY);
    localparam int CACHE_SET = (CACHE_BYTE/CACHE_WORD_BYTE/CACHE_LINE_LEN/CACHE_WAY);
//    localparam int CACHE_TAG_BITS = 32-$clog2(CACHE_BYTE/CACHE_WAY);
    localparam int CACHE_TAG_BITS = AW-$clog2(CACHE_BYTE/CACHE_WAY);
    localparam int CACHE_TAG_PART_BITS = 4;
    localparam int ADBITS = $clog2(CACHE_SET*CACHE_LINE_LEN);
    localparam int LOG2_CACHE_BYTE = $clog2(CACHE_BYTE);
    localparam int LOG2_CACHE_SET = $clog2(CACHE_SET);
    localparam int NLM_BYTE = 32; //256 bit
    localparam int DATA_ADR_W = LOG2_CACHE_BYTE - 2 - LOG2_CACHE_WAY - LOG2_USER_MAX_LEN;
    localparam int CACHE_INIT_NUM = CACHE_BYTE / (CACHE_WAY * CACHE_LINE_LEN * CACHE_WORD_BYTE);
    localparam int LOG2_CACHE_WORD_BYTE = $clog2(CACHE_WORD_BYTE);
    localparam int LOG2_CACHE_LINE_LEN = $clog2(CACHE_LINE_LEN);
    localparam int SET_NUM = (CACHE_BYTE / CACHE_LINE_LEN / CACHE_WORD_BYTE / CACHE_WAY);
    localparam int SET_LSB = $clog2(CACHE_LINE_LEN*CACHE_WORD_BYTE);
    localparam int SET_MSB = SET_LSB + $clog2(SET_NUM) - 1;


    localparam int STATES_NUM = 7;
    typedef enum logic [$clog2(STATES_NUM)-1:0] {
        INIT            = 0,
        READY           = 1,
        CHECK_SET2      = 2,
        MISS_START      = 3,
        FLUSH_START     = 4,
        STALL           = 5,
        RAW_DETECTED    = 6
    } state_t ;

    //request pipeline
    reg                             req_we, req_we_r, req_we_r2, req_we_r3;
    reg   [LOG2_USER_MAX_LEN-1:0]   req_len, req_len_r, req_len_r2;
    reg   [LOG2_USER_MAX_LEN:0]     wcnt, wcnt_r;
    reg                             req_re, req_re_r, req_re_r2, req_re_r3;
    reg                             flush_w, flush_r, flush_r2; // 4
    reg   [AW-1:0]                  req_adr, req_adr_r, req_adr_r2; // 32
    reg   [USER_DW-1:0]             req_wdat, req_wdat_r, req_wdat_r2; // 32
    reg                             access, access_r, access_r2; // 1
    logic [LOG2_CACHE_SET-1:0]      req_set, req_set_r, req_set_r2;
    logic [CACHE_TAG_BITS-1:0]      req_tag, req_tag_r, req_tag_r2;
    logic [LOG2_CACHE_SET-1:0]      req_set2, req_set2_r, req_set2_r2;
    logic [CACHE_TAG_BITS-1:0]      req_tag2, req_tag2_r, req_tag2_r2;
    logic                           same_set, same_set_r, same_set_r2;


    // system
    reg [STATES_NUM-1:0]        state, state_r, state_r2, state_r3; // 6
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
    logic [DATA_ADR_W-1:0]      start_data_adr, start_data_adr_r;
    logic [DATA_ADR_W-1:0]      data_adr[USER_MAX_LEN];
    logic [LOG2_USER_MAX_LEN-1:0]  start_bank_idx, start_bank_idx_r;
    reg                         data_re, data_re_r;//1
    logic [CACHE_WAY-1:0]       data_we[USER_MAX_LEN];
    logic [DW-1:0]              data_wdat[USER_MAX_LEN];
    wire  [DW*CACHE_WAY-1:0]    data_rdat[USER_MAX_LEN];

    reg                         resume_r, resume_r2;

    logic                       writeback_w;
    logic [AW-1:0]              writeback_set_w;
    logic                       refill_w;
    logic [AW-1:0]              refill_set_w;
    logic [LOG2_CACHE_WAY-1:0]  replaceWay_w;
    logic [LOG2_CACHE_WAY-1:0]  rdat_way;

    logic [USER_DW-1:0]         user_rdat_w;
    logic                       user_rdat_vld_w;

    logic                       raw_detect;
    logic                       rollback_r;
    logic                       pend_flush, pend_flush_r;
    logic [AW-1:0]              back_adr_r;

	logic [31:0]				debug;

    always_ff @(posedge clk or negedge rstn)
        if(~rstn) begin
            {flush_r2, flush_r} <= 0;
            {req_adr_r, req_re_r, req_we_r, req_wdat_r, req_len_r} <= 0;
            {req_adr_r2, req_re_r2, req_re_r3, req_we_r3, req_we_r2, req_wdat_r2, req_len_r2} <= 0;
            data_re_r <= 0;
            start_data_adr_r <= 0;
            start_bank_idx_r <= 0;
            state_r <= 1 << INIT;
            state_r2 <= 1 << INIT;
            state_r3 <= 1 << INIT;
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
            rerun_hit0_r <= 0;
            rerun_hit1_r <= 0;


            {req_set_r2, req_set_r} <= 0;
            {req_tag_r2, req_tag_r} <= 0;
            {tag_adr_r2, tag_adr_r} <= 0;

            {req_set2_r2, req_set2_r} <= 0;
            {req_tag2_r2, req_tag2_r} <= 0;

            {same_set_r2, same_set_r} <= 0;
            flush_way_r <= 0;
            pend_flush_r <= 0;

            back_adr_r <= 0;
            wcnt_r <= 0;
        end
        else begin
            state_r <= state;
            state_r2 <= state_r;
            state_r3 <= state_r2;
            data_re_r <= data_re;
            start_data_adr_r <= start_data_adr;
            start_bank_idx_r <= start_bank_idx;
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

            {req_set_r2, req_set_r} <= {req_set_r, req_set};
            {req_tag_r2, req_tag_r} <= {req_tag_r, req_tag};

            {req_set2_r2, req_set2_r} <= {req_set2_r, req_set2};
            {req_tag2_r2, req_tag2_r} <= {req_tag2_r, req_tag2};

            {same_set_r2, same_set_r} <= {same_set_r, same_set};


            req_adr_r <= req_adr;
            req_re_r <= req_re;
            req_we_r <= req_we;
            req_wdat_r <= req_wdat;
            req_len_r <= req_len;

            req_adr_r2 <= req_adr_r;
            req_re_r2 <= req_re_r;
            req_re_r3 <= req_re_r2;
            req_we_r2 <= req_we_r;
            req_we_r3 <= req_we_r2;
            req_wdat_r2 <= req_wdat_r;
            req_len_r2 <= req_len_r;

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

            {tag_adr_r2, tag_adr_r} <= {tag_adr_r, tag_adr};

            flush_way_r <= flush_way;
            pend_flush_r <= pend_flush;

            back_adr_r <= back_adr;
            wcnt_r <= wcnt;
        end

    assign user_rdat_o = user_rdat_w;
    assign user_rdat_vld_o = user_rdat_vld_w;
    assign back_rdat = data_rdat[back_adr_r & (USER_MAX_LEN - 1)][rdat_way*DW +: DW];

    always @ (*) begin // COMB1
		debug = 0;
	
	
        {tag_re, tag_we, tag_wdat} = 0;
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
        req_len = req_len_r;
        mru_wdat_vector = mru_wdat_vector_r;
        mesiAction = mesiAction_r;
        mesiReq = mesiReq_r;

        flush_w = flush_r;
        pend_flush = pend_flush_r;

        //------------------------------------ stage 0 ------------------------------------ //
        if(state_r[READY]) begin
            if(user_re | user_we | back_flush) begin
                access=1;
                flush_w = back_flush;
                req_re = user_re;
                req_we = user_we;
                req_adr = user_adr;
                req_wdat = user_wdat;
                req_len = user_len;
            end
            else if (back_re | back_we) begin
                access = 1;
                flush_w = 0;
                req_re = back_re;
                req_we = back_we;
                req_adr = back_adr;
                req_wdat = back_wdat;
                req_len = 0;//{CACHE_WORD_BYTE {back_we}};
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
            tag_re      = access;
            mru_re      = access;
            mesiState_re = access;
        end

        req_set = get_set(req_adr);
        req_tag = get_tag(req_adr);
        req_set2 = get_set(req_adr + CACHE_WORD_BYTE*req_len);
        req_tag2 = get_tag(req_adr + CACHE_WORD_BYTE*req_len);
        same_set = (req_set2==req_set) ? 1 : 0;
        tag_adr = (state_r[STALL] & state_r3[CHECK_SET2]) ? req_set2_r : req_set;
        mru_rad = req_set;
        mesiState_rad = req_set;
        mesiState_wad = req_set;

        //------------------------------------ stage 1 ------------------------------------ //
        hit = 0;
        hitway = 0;
        rerun_hit0 = 0;
        rerun_hit1 = 0;

        data_re = mru_re_r & req_re_r;
        data_adr = '{default: 0};
        start_data_adr = get_data_adr(req_adr_r, start_bank_idx);
        for (int b=0; b<USER_MAX_LEN; b++) begin
            int cur_bank_idx;
            cur_bank_idx = (start_bank_idx + b) & (USER_MAX_LEN - 1);
            if (start_bank_idx+b < USER_MAX_LEN) begin
                data_adr[cur_bank_idx] = start_data_adr;
            end
            else begin
                data_adr[cur_bank_idx] = start_data_adr + 1;
            end
        end

        if(state_r[READY] && access_r==1) begin
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
        else if(state_r[CHECK_SET2]) begin
            if(mesiState_rdat[0*2 +: 2]!=MESI_STATE_INVALID &&
                req_tag2_r==tag_rdat[0*CACHE_TAG_BITS +: CACHE_TAG_BITS]) begin
                hit = 1;
                hitway[0] = 1;
                rerun_hit0 = 1;
            end

            if(mesiState_rdat[1*2 +: 2]!=MESI_STATE_INVALID &&
                req_tag2_r==tag_rdat[1*CACHE_TAG_BITS +: CACHE_TAG_BITS]) begin
                hit = 1;
                hitway[1] = 1;
                rerun_hit1 = 1;
            end
        end

        rerun_hit = ((rerun_hit0 && hitway[0]) || (rerun_hit1 && hitway[1]));
        rerun_hitway = (rerun_hit1 && hitway[1]) ? 1 : 0;
        flush_way = flush_way_r;
        rdat_way = (state_r[STALL] && ~flush_r) ? replaceWay_r :
                    flush_r2                    ? flush_way_r  :
                                                rerun_hitway_r;
        for (int b=0; b<USER_MAX_LEN; b++) begin
            int cur_bank_idx;
            int way;
            cur_bank_idx = (start_bank_idx_r + b);// & (USER_MAX_LEN - 1);
            way = ((cur_bank_idx<USER_MAX_LEN) && state_r2[CHECK_SET2]) ? rerun_hitway_r2 : rerun_hitway_r;
            user_rdat_w[b*DW +: DW] = data_rdat[cur_bank_idx & (USER_MAX_LEN - 1)][way*DW +: DW];
        end
        user_rdat_vld_w = rerun_hit_r && ((req_re_r2 && ~req_we_r2 && !state_r[RAW_DETECTED] && same_set_r2) ||
                                           req_re_r3 && ~req_we_r3 && state_r2[CHECK_SET2]);
        raw_detect = (access && access_r && req_we_r && req_re && rerun_hit);

        if (~hit && access_r && ~flush_r && (state_r[READY] || state_r[CHECK_SET2])) begin
            req_re = req_re_r;
            req_we = req_we_r;
            req_len = req_len_r;
            req_adr = req_adr_r;
            req_wdat = req_wdat_r;
            req_set = get_set(req_adr_r);
            req_tag = get_tag(req_adr_r);
            same_set = same_set_r;
            tag_re = 0;
            mesiState_re = 0;
        end
        else if (hit && access_r && ~flush_r && state_r[READY] && ~same_set_r) begin
            tag_re      = 1;
            mru_re      = 1;
            mesiState_re = 1;
            tag_adr = req_set2_r;
            mru_rad = req_set2_r;
            mesiState_rad = req_set2_r;

            req_re = req_re_r;
            req_we = req_we_r;
            req_len = req_len_r;
            req_adr = req_adr_r;
            req_wdat = req_wdat_r;
            req_set = req_set_r;
            req_tag = req_tag_r;
            req_set2 = req_set2_r;
            req_tag2 = req_tag2_r;
            same_set = same_set_r;
        end
        else if (hit && flush_r && mesiState_rdat[rerun_hitway*2 +: 2]==MESI_STATE_MODIFIED) begin
            req_adr = req_adr_r;
            req_set = get_set(req_adr_r);
            req_tag = get_tag(req_adr_r);
            pend_flush = 1;
        end

        data_wdat = '{default: 0};
        wcnt = state_r[READY] ? 0 : wcnt_r;
        if (rerun_hit & req_we_r) begin
            data_re = 0;
            for (int b=0; b<USER_MAX_LEN; b++) begin
                int cur_bank_idx;
                cur_bank_idx = (start_bank_idx + b);
                if (state_r[READY] && (wcnt<=req_len_r) && ((cur_bank_idx<USER_MAX_LEN) || same_set_r)) begin
                    data_we[cur_bank_idx & (USER_MAX_LEN - 1)][rerun_hitway] = 1;
                    wcnt++;
                end
                else if (state_r[CHECK_SET2] && (wcnt<=req_len_r2)  && (cur_bank_idx>=USER_MAX_LEN)) begin
                    data_we[cur_bank_idx & (USER_MAX_LEN - 1)][rerun_hitway] = 1;
                    wcnt++;
                end
                //data_we[cur_bank_idx & (USER_MAX_LEN - 1)][rerun_hitway] = (b<=req_len_r) ? 1 : 0;
                data_wdat[cur_bank_idx & (USER_MAX_LEN - 1)] = req_wdat_r[b*DW +: DW];
            end
        end

        //# stage3: update MRU, dirty bit of the hit line
        if(rerun_hit_r && ((state_r[CHECK_SET2] && rerun_hit) ||
                            ((state_r[READY] || state_r[RAW_DETECTED]) && ~state_r2[CHECK_SET2]))) begin
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
        else if(rerun_hit_r && state_r2[CHECK_SET2]) begin
            // update mru
            mru_wad = req_set2_r2;
            {mru_wdat, mru_we, mru_wdat_vector} = update_mru(
                rerun_hitway_r,
                mru_rdat_r,
                req_set2_r2,
                mru_wad_r,
                mru_we_r,
                mru_wdat_vector_r
            );

            mesiState_wad = req_set2_r2;
            mesiState_wdat = MESI_STATE_MODIFIED;
            mesiState_we = req_we_r3 << rerun_hitway_r;
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
                else if(flush_r && rerun_hit && mesiState_rdat[rerun_hitway*2 +: 2]==MESI_STATE_MODIFIED) begin
                    ready = 0;
                    access = 0;
                    flush_way = rerun_hitway;
                    state[FLUSH_START] = 1;
                end
                else if ((access_r & ~hit & ~flush_r) || (access_r2 & ~hit & ~flush_r2 & ~same_set_r2)) begin
                    state[MISS_START] = 1;
                    access = 0;
                    ready = 0;
                    flush_w = 0;
                end
                else if (access_r & hit & ~flush_r & ~same_set_r) begin
                    state[CHECK_SET2] = 1;
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

            state_r[CHECK_SET2]: begin
                if (hit) begin
                    state[READY] = 1;
                end
                else begin
                    state[MISS_START] = 1;
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
//					debug = 1;
//					$display ("[cyclicCacheCore]: finish");
//                  $finish;
                end

                refill_w = 1;
                mesiAction = MESI_ACT_REFILL;
                mesiReq = req_we_r2 ? MESI_REQ_HANDLE_WRITE_MISS : MESI_REQ_HANDLE_READ_MISS;
                state[STALL] = 1;

                if (state_r2[READY]) begin
                    writeback_w = ((mesiState_rdat_r[replaceWay_w*2 +: 2]==MESI_STATE_MODIFIED)) ||
                                (rerun_hit_r && req_we_r2 && (req_set_r==req_set_r2) && (rerun_hitway_r==replaceWay_w));
                    writeback_set_w = (tag_rdat_r[replaceWay_w*CACHE_TAG_BITS +: CACHE_TAG_BITS] << (AW-CACHE_TAG_BITS)) + req_set_r*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                    refill_set_w = (req_tag_r << (AW-CACHE_TAG_BITS)) + req_set_r*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                end
                else begin
                    writeback_w = ((mesiState_rdat_r[replaceWay_w*2 +: 2]==MESI_STATE_MODIFIED)) ||
                                (rerun_hit_r && req_we_r2 && (req_set2_r==req_set2_r2) && (rerun_hitway_r==replaceWay_w));
                    writeback_set_w = (tag_rdat_r[replaceWay_w*CACHE_TAG_BITS +: CACHE_TAG_BITS] << (AW-CACHE_TAG_BITS)) + req_set2_r*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                    refill_set_w = (req_tag2_r << (AW-CACHE_TAG_BITS)) + req_set2_r*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
                end
            end

            state_r[FLUSH_START]: begin
                mesiState_re=0;
                mesiState_we = 1 << rerun_hitway_r;
                mesiState_wdat=MESI_STATE_INVALID;
                writeback_w = 1;
                state[STALL] = 1;
                mesiState_wad = req_set_r2;
                writeback_set_w = (tag_rdat_r[rerun_hitway_r*CACHE_TAG_BITS +: CACHE_TAG_BITS] << (AW-CACHE_TAG_BITS)) + req_set_r2*(CACHE_LINE_LEN*CACHE_WORD_BYTE);
            end

            state_r[STALL]: begin
                if (mesiAction_r!=MESI_ACT_NULL) begin
                    tag_we = 1 << replaceWay_r;
                    tag_wdat = state_r3[CHECK_SET2] ? req_tag2_r : req_tag_r2;

                    mesiState_we = 1 << replaceWay_r;
                    mesiState_wad = state_r3[CHECK_SET2] ? req_set2_r : req_set_r;

                    /*if(mesiReq_r==MESI_REQ_HANDLE_WRITE_MISS) begin
                        mesiState_wdat = MESI_STATE_MODIFIED;
                    end
                    else begin*/
                        mesiState_wdat = MESI_STATE_EXCLUSIVE;
                    //end
                    mesiAction = MESI_ACT_NULL;
                end

                if (resume) begin
                    state[READY] = 1;
                end
                else begin
                    state[STALL] = 1;
                    data_re = back_re;
                    for (int b=0; b<USER_MAX_LEN; b++) begin
                        data_wdat[b] = back_wdat;
                        data_adr[b] = back_adr / USER_MAX_LEN;
                        if (back_we && ((back_adr&(USER_MAX_LEN-1))==b)) begin
                            data_we[b][replaceWay_r] = 1;
                        end
                    end
                end
            end

            state_r[RAW_DETECTED]: begin
                state[READY] = 1;
                ready = 1;
            end
        endcase
    end

    // nway_sp_dist #(.N(CACHE_WAY), .DATA_WIDTH(TAG_BITS), .ADDR_WIDTH(LOG2_CACHE_SET))
    nway_sp_dist #(
        .N          (CACHE_WAY),
        .DATA_WIDTH (CACHE_TAG_BITS),
        .ADDR_WIDTH (LOG2_CACHE_SET),
        .RAM_TYPE   ("distributed")
    ) tagMem (
        .clk  (clk),
        .re   (tag_re),
        .we   (tag_we),
        .adr  (tag_adr),
        .wdat (tag_wdat),
        .rdat (tag_rdat)
    );

    generate
        for (genvar i=0; i<USER_MAX_LEN; i++) begin: DATA_MEM_BLK
            nway_sp_dist #(
                .N          (CACHE_WAY),
                .DATA_WIDTH (DW),
                .ADDR_WIDTH (DATA_ADR_W),
                .RAM_TYPE   ("block")
            ) dataMem (
                .clk  (clk),
                .re   (data_re),
                .we   (data_we[i]),
                .adr  (data_adr[i]),
                .wdat (data_wdat[i]),
                .rdat (data_rdat[i])
            );
        end
    endgenerate

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
    function [DATA_ADR_W-1:0] get_data_adr;
        input [AW-1:0] adr;
        output logic [LOG2_USER_MAX_LEN-1:0] bank_idx;
        logic [AW-1:0] data_adr_tmp;
        begin
            data_adr_tmp = ((get_set(adr) * CACHE_LINE_LEN) + ((adr / CACHE_WORD_BYTE) % CACHE_LINE_LEN));
            bank_idx = data_adr_tmp & (USER_MAX_LEN-1);
            get_data_adr = data_adr_tmp >> LOG2_USER_MAX_LEN;
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



