
module dma_axi4_to_stream_t import dma_axiStream_axi4_pkg_t::*;
                         #(
                            parameter AXI_AW             = 32,
                            parameter AXI_DW             = 32,
                            parameter T_DW               = 32,
                            parameter REGS_DW            = 32,
                            parameter REGS_AW            = 3,
                            parameter usr_ram_style      = "distributed",
                            parameter FIFO_DEPTH         = 4
                          )(
                              input                         aclk,
                              input                         areset,
                              input                         tclk,
				(* mark_debug = "true" *)
                              output logic                  arvalid,
				(* mark_debug = "true" *)
                              input                         arready,
                              output logic  [AXI_AW-1 : 0]  araddr,
                              output logic  [7 : 0]         arlen,
                              output logic  [2 : 0]         arsize,
                              output logic  [1 : 0]         arburst,
				(* mark_debug = "true" *)
                              input                         rvalid,
				(* mark_debug = "true" *)
                              output logic                  rready,
                              input         [AXI_DW-1:0]    rdata,
				(* mark_debug = "true" *)
                              input                         rlast,
                              input         [1 : 0]         rresp,

				(* mark_debug = "true" *)
                              output logic                  s_tvalid,
				(* mark_debug = "true" *)
                              input                         s_tready,
				//(* mark_debug = "true" *)
                              output logic  [T_DW-1 : 0]    s_tdata,
                              output logic  [T_DW/8-1 : 0]  s_tstrb,
                              output logic  [T_DW/8-1 : 0]  s_tkeep,
                              output logic                  s_tlast,
				(* mark_debug = "true" *)
                              output  logic                 dma_busy,
				(* mark_debug = "true" *)
                              output  logic                 dma_finish,
				(* mark_debug = "true" *)
                              input                         dma_start,
				(* mark_debug = "true" *)
                              input                         dma_stop,
				(* mark_debug = "true" *)
                              input                         flush_fifo,
				(* mark_debug = "true" *)
                              output logic                  fifo_full_o,
				(* mark_debug = "true" *)
                              output logic                  fifo_empty_o,
                              output logic  [REGS_DW-1 : 0] fifo_cnt_bytes_o,

                              input         [REGS_DW-1 : 0] min_addr,
                              input         [REGS_DW-1 : 0] max_addr,
                              input         [REGS_DW-1 : 0] dma_start_addr,
                              input         [REGS_DW-1 : 0] dma_len,
                              input                         dma_dir
                          );
    localparam AxSIZE = $clog2(AXI_DW >> 3);
    localparam MAX_AXI4_TR_LEN = ((AXI_DW >> 3) * (1 << 8));//4bytes * 256beats in burst
    localparam FIFO_AW = $clog2(FIFO_DEPTH);
    localparam ADDR_MASK = ((AXI_DW >> 3) - 1);
    localparam NUM_BYTES_IN_WORD = (AXI_DW >> 3);
    localparam DW_FACTOR = AXI_DW / T_DW;
    localparam LOG_DW_FACTOR = $clog2(DW_FACTOR);
    localparam TR_LEN_W = $clog2(FIFO_DEPTH * NUM_BYTES_IN_WORD);

    /*
        The pseudo code for DMA is as follow:
        ptr=dmaStart
        for(int i=0; i<dmaLen; i++) {
            axis_master = ddr[ptr]
            ptr++; if(ptr==maxAdr) ptr=minAdr;
        }
     */

    localparam FSM_STATES_NUM = 2;
    typedef enum logic[FSM_STATES_NUM-1:0] {
        IDLE             = (1 << 0),
        //AXI_WAIT_ARREADY = (1 << 1),
        AXI_WAIT_RVALID  = (1 << 1)
    } fsm_state_t;
    (* mark_debug = "true" *)
    fsm_state_t  fsm_state, fsm_state_r;

	(* mark_debug = "true" *)
    logic                      fifo_rd_en, fifo_rd_en_r;
	(* mark_debug = "true" *)
    logic                      fifo_wr_en;
    logic                      fifo_full;
    logic                      fifo_empty;
    logic [AXI_DW-1:0]         fifo_rdata/*, fifo_rdata_r*/;
    logic                      fifo_rstn;
    logic                      flush_fifo_r;

	(* mark_debug = "true" *)
    logic                      arvalid_w, arvalid_r;
	(* mark_debug = "true" *)
    logic [AXI_AW-1 : 0]       araddr_r, araddr_w;
	(* mark_debug = "true" *)
    logic [7 : 0]              arlen_r, arlen_w;
    logic                      rready_w;
    logic                      axi4_tr_run, axi4_tr_run_r;


    logic [REGS_DW-1 : 0]      addr_interval;

	(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      dma_cur_addr, dma_cur_addr_w;
	(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      dma_cur_len, dma_cur_len_w;
	(* mark_debug = "true" *)
    logic [TR_LEN_W : 0]       transfer_len_bytes, transfer_len_bytes_r;
	(* mark_debug = "true" *)
    logic [23 : 0]             total_num_of_beats, total_num_of_beats_r;
	(* mark_debug = "true" *)
    logic [$clog2(FIFO_DEPTH) : 0] num_of_beats/*, num_of_beats_r*/;
	(* mark_debug = "true" *)
    logic                      send_next_axi_transfer, send_next_axi_transfer_r;
	(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      fifo_cnt_bytes, fifo_cnt_bytes_r;
	(* mark_debug = "true" *)
    logic                      dma_start_w, dma_start_r;
	(* mark_debug = "true" *)
    logic                      infinite_len;

    logic [23 : 0]             tdata_cnt_beats, tdata_cnt_beats_r;
    logic                      tlast;
    logic                      tvalid, tvalid_r;
    logic [T_DW/8-1 : 0]       tstrb;
    logic [T_DW-1 : 0]         tdata, tdata_r;

    logic                        tlast_w;
    logic                        tvalid_w;
    logic [T_DW-1:0]             tdata_w;
    logic [T_DW/8-1:0]           tstrb_w;
    logic                        s_tready_w;


    logic                      last_r;
    logic                      dma_busy_r;

    //axi4 regs
    always_ff @(posedge aclk or posedge areset) begin
        if (areset) begin
            fsm_state_r <= IDLE;

            arvalid_r <= 0;
            arlen_r   <= 0;
            araddr_r  <= 0;

            dma_cur_addr           <= 0;
            dma_cur_len            <= 0;
            send_next_axi_transfer_r <= 0;
            infinite_len <= 0;
            transfer_len_bytes_r <= 0;
            //num_of_beats_r <= 0;
            total_num_of_beats_r <= 0;

            dma_start_r <= 0;
            dma_finish <= 0;
            dma_busy_r   <= 0;

            fifo_full_o <= 0;
            fifo_empty_o <= 1;
            fifo_cnt_bytes_r <= 0;

            last_r <= 0;
            axi4_tr_run_r <= 0;
        end
        else begin
            fsm_state_r <= fsm_state;

            fifo_full_o <= fifo_full;
            fifo_empty_o <= fifo_empty;
            fifo_cnt_bytes_r <= fifo_cnt_bytes;

            arvalid_r <= arvalid_w;
            arlen_r   <= arlen_w;
            araddr_r  <= araddr_w;

            dma_cur_addr           <= dma_cur_addr_w;
            dma_cur_len            <= dma_cur_len_w;
            send_next_axi_transfer_r <= send_next_axi_transfer;
            infinite_len <= (dma_len == -1);
            transfer_len_bytes_r <= transfer_len_bytes;

            //if (dma_start_r | send_next_axi_transfer_r)
            //    num_of_beats_r <= num_of_beats;

            total_num_of_beats_r <= total_num_of_beats;

            dma_start_r <= dma_start_w;
            dma_finish <= (tlast & tvalid & s_tready) | dma_stop;
            if (dma_start_w)
                dma_busy_r   <= 1;
            else if (dma_finish)
                dma_busy_r   <= 0;


            if (rvalid & rlast & rready) begin
                last_r <= 1;
            end
            else if (send_next_axi_transfer || ~dma_busy_r) begin
                last_r <= 0;
            end
            axi4_tr_run_r <= axi4_tr_run;
        end
    end
    assign fifo_cnt_bytes_o = fifo_cnt_bytes_r;

    assign arvalid = arvalid_r;
    assign araddr  = arvalid_r ? araddr_r : 0;
    assign arlen   = arvalid_r ? arlen_r  : 0;
    assign dma_busy = dma_busy_r || (fsm_state_r!=IDLE);

    //axi4 fsm
    always_comb begin
        fsm_state = fsm_state_r;
        fifo_cnt_bytes = (dma_cur_addr>=dma_start_addr) ? (dma_cur_addr - dma_start_addr) : 0;

        arvalid_w = (arvalid && arready) ? 0 : arvalid_r;
        arlen_w   = arlen_r;
        araddr_w  = araddr_r;
        arsize    = AxSIZE;
        arburst   = (max_addr=='hFFFFFFFF) ? AxBURST_INCR : AxBURST_WRAP;

        axi4_tr_run = axi4_tr_run_r;
        //rready    = ~fifo_full && dma_busy_r && ((~flush_fifo && ~flush_fifo_r) || ((fsm_state_r!=IDLE) && ~last_r));
        rready = ~fifo_full && axi4_tr_run_r;

        dma_start_w       = dma_start && (dma_dir==DMA_DIR_AXI4_TO_AXI_STREAM)/* && (dma_start_addr>=min_addr) && (dma_start_addr <= max_addr)*/;

        dma_cur_addr_w    = dma_start_w ? dma_start_addr : dma_cur_addr;
        dma_cur_len_w     = dma_start_w ? dma_len        : dma_cur_len;
        addr_interval     = max_addr - dma_cur_addr_w;

        send_next_axi_transfer = 0;
        num_of_beats = get_num_of_beats(dma_cur_addr, dma_cur_len, max_addr, transfer_len_bytes);
        total_num_of_beats = dma_start_w ? get_total_num_of_beats(dma_start_addr, dma_len) : total_num_of_beats_r;
        //transfer_len_bytes = transfer_len_bytes_r;
        case (fsm_state_r)
            IDLE: begin
                if ((dma_start_r | send_next_axi_transfer_r) && dma_busy_r && ~dma_stop) begin
                    araddr_w  = dma_cur_addr & ~ADDR_MASK;
                    arvalid_w = 1;
                    arlen_w   = (num_of_beats - 1);
                    fsm_state = AXI_WAIT_RVALID;//arready ? AXI_WAIT_RVALID : AXI_WAIT_ARREADY;
                    axi4_tr_run = 1;
                end
            end

            //AXI_WAIT_ARREADY: begin
            //    arvalid_w = 1;
            //    if (arready) begin
            //        fsm_state = AXI_WAIT_RVALID;
            //    end
            //    /*else if (dma_stop) begin
            //        fsm_state = IDLE;
            //    end*/
            //end

            AXI_WAIT_RVALID: begin
                //if (rvalid & rlast & ~fifo_full) begin
                if (last_r) begin
                    axi4_tr_run = 0;
                end

                if (last_r & fifo_empty) begin
                    if (dma_cur_addr + transfer_len_bytes_r < max_addr)
                        dma_cur_addr_w = dma_cur_addr + transfer_len_bytes_r;
                    else
                        dma_cur_addr_w = min_addr;

                    send_next_axi_transfer = ((infinite_len || (~infinite_len && (dma_cur_len > transfer_len_bytes_r)))) && dma_busy_r && ~flush_fifo && ~flush_fifo_r;
                    if (~infinite_len && (dma_cur_len > transfer_len_bytes_r) && dma_busy_r) begin
                        dma_cur_len_w = dma_cur_len - transfer_len_bytes_r;
                    end
                    fsm_state = IDLE;
                end
                else if (dma_stop && ~axi4_tr_run) begin
                    fsm_state = IDLE;
                end
            end
        endcase
    end

    //axi-stream regs (common for all configurations)
    always_ff @(posedge tclk or posedge areset) begin
        if (areset) begin
            fifo_rd_en_r      <= 0;
            //fifo_rdata_r      <= 0;
            tdata_cnt_beats_r <= 0;
        end
        else begin
            fifo_rd_en_r      <= fifo_rd_en;
            /*if (fifo_rd_en_r)
                fifo_rdata_r <= fifo_rdata;*/

            tdata_cnt_beats_r <= tdata_cnt_beats;
        end
    end

    assign s_tvalid = tvalid;
    assign s_tdata  = tvalid ? tdata : 0;
    assign s_tlast  = tvalid ? tlast : 0;
    assign s_tstrb  = tvalid ? tstrb : 0;
    assign s_tkeep  = tvalid ? tstrb : 0;
    assign s_tdest  = 0;


    //axi-stream logic (common for all configurations)
    always_comb begin
        tdata_cnt_beats = tdata_cnt_beats_r;
        if (dma_start_w) begin
            tdata_cnt_beats = 0;
        end
        else if (tvalid_w && s_tready_w) begin
            tdata_cnt_beats = tdata_cnt_beats_r + 1;
        end
    end

    always_ff @(posedge tclk or posedge areset) begin
        if (areset) begin
            tvalid_r <= 0;
            tdata_r  <= 0;
        end
        else begin
            if (fifo_rd_en_r && ~s_tready_w && (dma_len!=0)) begin
                tvalid_r <= 1;
                tdata_r  <= fifo_rdata;
            end
            else if ((tvalid_r && s_tready_w) || ~dma_busy_r) begin
                tvalid_r <= 0;
                tdata_r  <= 0;
            end
        end
    end

    generate
        if (AXI_DW==T_DW) begin
            //axi_stream logic
            always @(*) begin
                fifo_rd_en = dma_busy_r && ~fifo_empty && (s_tready_w | (~tvalid_r & ~fifo_rd_en_r));
                tlast_w = (~infinite_len && (dma_len!=0) && (tdata_cnt_beats>=total_num_of_beats_r)) ? 1 : 0;
                tvalid_w = ((fifo_rd_en_r & dma_len!=0) || tvalid_r) && dma_busy_r;
                tstrb_w =  (tdata_cnt_beats_r==0) ? get_strb_at_start(dma_start_addr, dma_len)  :
                          tlast                  ? get_strb_at_finish(dma_start_addr, dma_len) : {(T_DW/8){tvalid}};
                tdata_w = (fifo_rd_en_r & s_tready_w)   ? fifo_rdata :
                        tvalid_r                    ? tdata_r    : 0;
            end
        end
        else if (AXI_DW>T_DW) begin
            logic [$clog2(AXI_DW/8):0] rd_cnt, rd_cnt_r;
            logic                        tdata_run, tdata_run_r;
            logic [REGS_DW-1:0]          tdata_cnt_r;
            logic [AXI_DW-1:0]           fifo_rdata_r;


            always_ff @(posedge tclk or posedge areset) begin
                if (areset) begin
                    rd_cnt_r <= 0;
                    tdata_run_r <= 0;
                    tdata_cnt_r <= 0;
                    fifo_rdata_r <= 0;
                end
                else begin
                    rd_cnt_r <= rd_cnt;
                    tdata_run_r <= tdata_run;
                    if (dma_start_w) begin
                        tdata_cnt_r <= 0;
                    end
                    else if (tvalid && s_tready_w)begin
                        tdata_cnt_r <= tdata_cnt_r + (T_DW/8);
                    end

                    if (fifo_rd_en_r)
                        fifo_rdata_r <= fifo_rdata;

                end
            end
            always @(*) begin
                fifo_rd_en = 0;
                rd_cnt = rd_cnt_r;
                tdata_run = tdata_run_r;

                tdata_w = (fifo_rd_en_r & s_tready_w)  ? fifo_rdata[rd_cnt_r*8 +: T_DW] :
                        (tdata_run_r & s_tready_w)   ? fifo_rdata_r[rd_cnt_r*8 +: T_DW] :
                        tvalid_r                   ? tdata_r    : 0;
                tlast_w = (~infinite_len && (dma_len!=0) && (tdata_cnt_beats>=total_num_of_beats_r)) ? 1 : 0;
                tvalid_w = (tdata_run_r & dma_len!=0) | tvalid_r;
                tstrb_w =  (tdata_cnt_beats_r==0) ? get_strb_at_start(dma_start_addr, dma_len)  :
                         tlast_w                  ? get_strb_at_finish(dma_start_addr, dma_len) : {(T_DW/8){tvalid_w}};

                if (dma_start_w) begin
                    rd_cnt = dma_start_addr & (AXI_DW/8 - 1) & ~(T_DW/8 - 1);
                end
                else if (~fifo_empty && ~tdata_run_r && dma_busy_r) begin
                    fifo_rd_en = 1;
                    tdata_run = 1;
                end
                else if (tdata_run_r && ~dma_busy_r) begin
                    tdata_run  = 0;
                end
                else if (tdata_run_r && s_tready_w) begin
                    if (tlast_w) begin
                        tdata_run  = 0;
                    end
                    else if ((rd_cnt_r + (T_DW/8))>(AXI_DW/8-1)) begin
                        rd_cnt = 0;
                        fifo_rd_en = ~fifo_empty;
                        tdata_run  = ~fifo_empty;
                    end
                    else begin
                        rd_cnt = rd_cnt_r + (T_DW/8);
                    end
                end
            end
        end
    endgenerate

    generate
        if ((T_DW==8) || (T_DW==AXI_DW)) begin
            assign tdata = tdata_w;
            assign tlast = tlast_w;
            assign tvalid = tvalid_w;
            assign tstrb = tstrb_w;
            assign s_tready_w = s_tready;
        end
        else if (T_DW < AXI_DW) begin
            localparam OBUF_DEPTH = 2*T_DW/8;
            localparam L_OBUF_DEPTH = $clog2(OBUF_DEPTH);

            logic [L_OBUF_DEPTH-1 : 0] wptr_w, wptr_r;
            logic [L_OBUF_DEPTH-1 : 0] rptr_w, rptr_r;
            logic [L_OBUF_DEPTH   : 0] status_w, status_r;
            logic [8 : 0]              obuf_r[OBUF_DEPTH];
            logic [8 : 0]              obuf_w[OBUF_DEPTH];
            logic                      obuf_full;

            always_ff @(posedge tclk or posedge areset) begin
                if (areset) begin
                    wptr_r <= 0;
                    rptr_r <= 0;
                    status_r <= 0;
                    obuf_r <= '{default: 0};
                end
                else begin
                    wptr_r <= wptr_w;
                    rptr_r <= rptr_w;
                    status_r <= status_w;
                    obuf_r <= obuf_w;
                end
            end

            always @(*) begin
                obuf_w = obuf_r;
                wptr_w = wptr_r;
                if (tvalid_w && ~obuf_full && dma_busy_r) begin
                    for (int i=0; i<T_DW/8; i++) begin
                        if (tstrb_w[i]) begin
                            obuf_w[wptr_w][7:0] = tdata_w[i*8 +: 8];
                            obuf_w[wptr_w][8] = tlast_w;
                            wptr_w++;
                        end
                    end
                end
                else if (~dma_busy_r) begin
                    wptr_w = 0;
                end
            end

            always @(*) begin
                rptr_w = rptr_r;
                tlast = obuf_r[rptr_r + (T_DW/8) - 1][8];
                for (int i=0; i<(T_DW/8); i++) begin
                    tdata[i*8 +: 8] = obuf_r[rptr_r + i][7:0];
                end
                tvalid = 0;
                tstrb = 0;
                if ((status_r>=(T_DW/8)) && dma_busy_r) begin
                    tvalid = 1;
                    for (int i=0; i<(T_DW/8); i++) begin
                        tstrb[i] = 1;
                    end
                    if (s_tready) begin
                        rptr_w = rptr_r + (T_DW/8);
                    end
                end
                else if (~dma_busy_r) begin
                    rptr_w = 0;
                end
            end

            always @(*) begin
                obuf_full = (status_r>=(OBUF_DEPTH-1));
                status_w = status_r;
                if (~dma_busy_r) begin
                    status_w = 0;
                end
                else begin
                    if (status_r>=(T_DW/8) && s_tready) begin
                        status_w = status_r - (T_DW/8);
                    end
                    if (tvalid_w && ~obuf_full) begin
                        for (int i=0; i<T_DW/8; i++) begin
                            if (tstrb_w[i]) begin
                                status_w++;
                            end
                        end
                    end
                end
            end
            assign s_tready_w = ~obuf_full;
        end
    endgenerate

    always_ff @(posedge aclk or posedge areset) begin
        if (areset) begin
            flush_fifo_r <= 0;
        end
        else if (flush_fifo) begin
            flush_fifo_r <= 1;
        end
        else if (dma_start_w) begin
            flush_fifo_r <= 0;
        end
    end

    assign fifo_rstn = ~areset;// & ~flush_fifo;
    assign fifo_wr_en = rvalid & ~fifo_full & dma_busy_r & ~flush_fifo_r;
    /*sync_fifo#(
            .usr_ram_style ( usr_ram_style ),
            .dw            ( AXI_DW        ),
            .aw            ( FIFO_AW       )
        )data_fifo(
            .clk    ( aclk                ),
            .rstn   ( fifo_rstn           ),
            .rd_en  ( fifo_rd_en          ),
            .dout   ( fifo_rdata          ),
            .wr_en  ( fifo_wr_en          ),
            .din    ( rdata               ),
            .full   ( fifo_full           ),
            .empty  ( fifo_empty          )
        );*/

    sync_fifo1#(
            .usr_ram_style ( usr_ram_style ),
            .dw            ( AXI_DW        ),
            .aw            ( FIFO_AW       )
        )data_fifo(
            .clk    ( aclk                ),
            .rstn   ( fifo_rstn           ),
            .clr    ( flush_fifo          ),
            .rd_en  ( fifo_rd_en          ),
            .dout   ( fifo_rdata          ),
            .wr_en  ( fifo_wr_en          ),
            .din    ( rdata               ),
            .full   ( fifo_full           ),
            .empty  ( fifo_empty          )
        );

    function logic [31:0] get_num_of_beats( input [REGS_DW-1 : 0] start_addr,
                                           input [REGS_DW-1 : 0] len,
                                           input [REGS_DW-1 : 0] maxAddr,
                                           output logic [REGS_DW-1 : 0] num_of_bytes
                                          );
        logic [REGS_DW-1 : 0] remain_bytes_at_start;
        logic [REGS_DW-1 : 0] remain_bytes_at_finish;
        logic [REGS_DW-1 : 0] finish_addr;
        logic [REGS_DW-1 : 0] len_tmp;
        logic                 addr_overflowing;


        addr_overflowing       = (len==-1) || ((start_addr + len - 1) > maxAddr);
        finish_addr            = (~addr_overflowing) ? (start_addr + len - 1) : maxAddr;
        remain_bytes_at_start  = NUM_BYTES_IN_WORD - (start_addr & ADDR_MASK);
        remain_bytes_at_finish = (((finish_addr + 1) & ~ADDR_MASK) != (start_addr & ~ADDR_MASK)) ? ((finish_addr + 1) & ADDR_MASK) : 0;
        len_tmp                = (addr_overflowing ? (maxAddr - start_addr + 1) : len);

        num_of_bytes           = len_tmp;
        get_num_of_beats       = (remain_bytes_at_start!=0) ? 1 : 0;
        get_num_of_beats      += (remain_bytes_at_finish!=0) ? 1 : 0;
        get_num_of_beats      += (len_tmp > remain_bytes_at_start) ? ((len_tmp - remain_bytes_at_start) >> AxSIZE) : 0;

        if (get_num_of_beats > FIFO_DEPTH) begin
            get_num_of_beats = FIFO_DEPTH;
            num_of_bytes = FIFO_DEPTH * NUM_BYTES_IN_WORD - (NUM_BYTES_IN_WORD - remain_bytes_at_start);
        end
    endfunction

    function logic [31:0] get_total_num_of_beats( input [REGS_DW-1 : 0] start_addr,
                                                 input [REGS_DW-1 : 0] len
                                                );
        logic [REGS_DW-1 : 0] num_of_full_words;
        logic [REGS_DW-1 : 0] remain_bytes_at_start;
        logic [REGS_DW-1 : 0] remain_bytes_at_finish;
        logic [REGS_DW-1 : 0] finish_addr;
        logic [REGS_DW-1 : 0] len_tmp;


        if (AXI_DW==T_DW) begin
            remain_bytes_at_start = NUM_BYTES_IN_WORD - (start_addr & ADDR_MASK);
            len_tmp = (len > remain_bytes_at_start) ? (len - remain_bytes_at_start) : 0;
            finish_addr = (start_addr + len - 1);
            num_of_full_words = (len_tmp >> AxSIZE);
            remain_bytes_at_finish = (((finish_addr + 1) & ~ADDR_MASK) != (start_addr & ~ADDR_MASK)) ? ((finish_addr + 1) & ADDR_MASK) : 0;
            get_total_num_of_beats = (remain_bytes_at_start!=0) ? 1 : 0;
            get_total_num_of_beats += num_of_full_words;
            get_total_num_of_beats += (remain_bytes_at_finish!=0) ? 1 : 0;
        end
        else if (AXI_DW>T_DW) begin
            remain_bytes_at_start = T_DW/8 - (start_addr & (T_DW/8 - 1));
            len_tmp = (len > remain_bytes_at_start) ? (len - remain_bytes_at_start) : 0;
            finish_addr = (start_addr + len - 1);
            num_of_full_words = (len_tmp >> $clog2(T_DW/8));
            remain_bytes_at_finish = (((finish_addr + 1) & ~(T_DW/8 - 1)) != (start_addr & ~(T_DW/8 - 1))) ? ((finish_addr + 1) & (T_DW/8 - 1)) : 0;
            get_total_num_of_beats = (remain_bytes_at_start!=0) ? 1 : 0;
            get_total_num_of_beats += num_of_full_words;
            get_total_num_of_beats += (remain_bytes_at_finish!=0) ? 1 : 0;
        end
    endfunction

    function [T_DW/8-1 : 0] get_strb_at_start(input [REGS_DW-1:0] addr, input [REGS_DW-1:0] len);
        logic[$clog2(NUM_BYTES_IN_WORD)  :0] num_of_valid_bytes;
        logic[$clog2(NUM_BYTES_IN_WORD)-1:0] start_byte_idx;

        start_byte_idx = (addr & (T_DW/8 - 1));

        if (((start_byte_idx + len) > NUM_BYTES_IN_WORD) || (len==-1)) begin
            num_of_valid_bytes = NUM_BYTES_IN_WORD - start_byte_idx;
        end
        else begin
            num_of_valid_bytes = len;
        end

        get_strb_at_start = 0;
        for (int i=0; i<T_DW/8; i++) begin
            get_strb_at_start[i] = ((i >= start_byte_idx) && (i<(start_byte_idx + num_of_valid_bytes))) ? 1 : 0;
        end
    endfunction

    function [T_DW/8-1 : 0] get_strb_at_finish(input [REGS_DW-1:0] addr, input [REGS_DW-1:0] len);
        logic[$clog2(T_DW/8):0] last_byte_idx;
        last_byte_idx = ((addr + len - 1) & (T_DW/8 - 1));
        get_strb_at_finish = 0;
        for (int i=0; i<T_DW/8; i++) begin
            get_strb_at_finish[i] = (i <= last_byte_idx) ? 1 : 0;
        end
    endfunction


endmodule

