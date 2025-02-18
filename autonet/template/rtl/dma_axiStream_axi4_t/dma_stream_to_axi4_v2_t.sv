//`include "common.vh"

module dma_stream_to_axi4_t import dma_axiStream_axi4_pkg_t::*;
                         #(
                            parameter AXI_AW             = 32,
                            parameter AXI_DW             = 256,
                            parameter T_DW               = 256,
                            parameter REGS_DW            = 32,
                            parameter REGS_AW            = 4,
                            parameter usr_ram_style      = "distributed",
                            parameter FIFO_DEPTH         = 16
//                            parameter WLAST_AS_WVALID    = 1
                          )(
                              input                         aclk,
                              input                         areset,
                              //input                         tclk,

							  //(* mark_debug = "true" *)
                              output logic                  awvalid,
							  //(* mark_debug = "true" *)
                              input                         awready,
							  //(* mark_debug = "true" *)
                              output logic  [AXI_AW-1 : 0]  awaddr,
							  //(* mark_debug = "true" *)
                              output logic  [7 : 0]         awlen,
                              output logic  [2 : 0]         awsize,
                              output logic  [1 : 0]         awburst,
							  //(* mark_debug = "true" *)
                              output logic                  wvalid,
							  //(* mark_debug = "true" *)
                              input                         wready,
                              output logic  [AXI_DW-1 : 0]  wdata,
							  //(* mark_debug = "true" *)
                              output logic  [AXI_DW/8-1 : 0]wstrb,
							  //(* mark_debug = "true" *)
                              output logic                  wlast,
							  //(* mark_debug = "true" *)
                              input                         bvalid,
							  //(* mark_debug = "true" *)
                              output logic                  bready,

							  //(* mark_debug = "true" *)
                              input                         m_tvalid,
							  //(* mark_debug = "true" *)
                              output logic                  m_tready,
							  //(* mark_debug = "true" *)
                              input         [T_DW-1 : 0]    m_tdata,
							  //(* mark_debug = "true" *)
                              input         [T_DW/8-1 : 0]  m_tstrb,
							  //(* mark_debug = "true" *)
                              input         [T_DW/8-1 : 0]  m_tkeep,
							  //(* mark_debug = "true" *)
                              input                         m_tlast,

							  //(* mark_debug = "true" *)
                              output  logic                 dma_busy,
							  //(* mark_debug = "true" *)
                              output  logic                 dma_finish,
							  //(* mark_debug = "true" *)
                              input                         dma_start,
							  //(* mark_debug = "true" *)
                              input                         dma_stop,
							  //(* mark_debug = "true" *)
                              input                         flush_fifo,
							  //(* mark_debug = "true" *)
                              output logic                  fifo_full_o,
							//(* mark_debug = "true" *)
                              output logic                  fifo_empty_o,
							  //(* mark_debug = "true" *)
                              output logic [REGS_DW-1 : 0]  fifo_cnt_bytes_o,
							  //(* mark_debug = "true" *)
                              input         [REGS_DW-1 : 0] min_addr,
							  //(* mark_debug = "true" *)
                              input         [REGS_DW-1 : 0] max_addr,
							  //(* mark_debug = "true" *)
                              input         [REGS_DW-1 : 0] dma_start_addr,
							  //(* mark_debug = "true" *)
                              input         [REGS_DW-1 : 0] dma_len,
							  //(* mark_debug = "true" *)
                              input                         dma_dir,
							  //(* mark_debug = "true" *)
                              input                         dma_mode

                          );
    localparam AxSIZE          = $clog2(AXI_DW >> 3);
    localparam MAX_AXI4_TR_LEN = ((AXI_DW >> 3) * (1 << 8));//16bytes * 256beats in burst
    localparam FIFO_SIZE_BYTES = (FIFO_DEPTH * AXI_DW) >> 3;
    localparam FIFO_AW   = $clog2(FIFO_DEPTH);
    localparam DW_FACTOR = AXI_DW / T_DW;
    localparam BASIC_TRANSFER_SIZE = 16 * (AXI_DW >> 3);
    localparam BEATS_W  = $clog2(BASIC_TRANSFER_SIZE >> AxSIZE);
    localparam AWADDR_MASK = (AXI_DW/8 - 1);

    /*
        The pseudo code for DMA is as follow:
        ptr=dmaStart
        for(int i=0; i<dmaLen; i++) {
            axis_master = ddr[ptr]
            ptr++; if(ptr==maxAdr) ptr=minAdr;
        }
     */

	/*
    localparam FSM_STATES_NUM = 4;
    typedef enum logic[FSM_STATES_NUM-1:0] {
        IDLE             = (1 << 0),
        AXI_WAIT_AWREADY = (1 << 1),
        AXI_WAIT_WREADY  = (1 << 2),
        AXI_WAIT_BVALID  = (1 << 3)
    } fsm_state_t;
    fsm_state_t  fsm_state, fsm_state_r;
	*/

	//(* mark_debug = "true" *)
    logic [T_DW/8-1 : 0]       fifo_wstrb[DW_FACTOR];
	//(* mark_debug = "true" *)
    logic [T_DW/8-1 : 0]       fifo_rstrb[DW_FACTOR];
	//(* mark_debug = "true" *)
    logic                      fifo_wr_en[DW_FACTOR];
	//(* mark_debug = "true" *)
    logic                      fifo_full[DW_FACTOR];
	//(* mark_debug = "true" *)
    logic                      fifo_empty[DW_FACTOR];

    logic [T_DW-1 : 0]         fifo_rdata[DW_FACTOR];
	//(* mark_debug = "true" *)
    logic [$clog2(DW_FACTOR):0] num_of_ones;
	//(* mark_debug = "true" *)
    logic [$clog2(T_DW/8):0]    num_of_bytes_by_strb;
	//(* mark_debug = "true" *)
    logic [DW_FACTOR-1:0]      fifo_rd_en, fifo_rd_en_r;
	//(* mark_debug = "true" *)
    logic                      fifo_rd_en_r_or;
	//(* mark_debug = "true" *)
    logic                      all_full, all_empty;
	//(* mark_debug = "true" *)
    logic                      fifo_rstn;
	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      fifo_cnt_bytes, fifo_cnt_bytes_r;
	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      transfered_cnt_bytes, transfered_cnt_bytes_r;
	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      fifo_cnt_bytes2, fifo_cnt_bytes2_r;
	//(* mark_debug = "true" *)
    logic                      start_axi4_transfer;
    logic                      m_tlast_r, m_tvalid_r;
	//(* mark_debug = "true" *)
    logic                      last_t_data;
	//(* mark_debug = "true" *)
    logic                      dma_finished;

    logic                      awvalid_w;
    logic  [AXI_AW-1 : 0]      awaddr_w, awaddr_r;
    logic  [AXI_AW-1 : 0]      awaddr_shift_w;
    logic  [AXI_AW-1 : 0]      awaddr_mask;
    logic  [7 : 0]             awlen_w, awlen_r;
    logic  [2 : 0]             awsize_w;
    logic  [1 : 0]             awburst_w;
    logic                      wvalid_w;
    logic  [AXI_DW-1 : 0]      wdata_w, wdata_r;
    logic  [AXI_DW/8-1 : 0]    wstrb_w, wstrb_r;
    logic                      wlast_w, wlast_r;
    logic                      bready_w;

	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      dma_cur_addr, dma_cur_addr_w;
	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      dma_cur_len, dma_cur_len_w;
	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      addr_interval;
	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      bytes_to_transfer;
	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      transfer_len, transfer_len_r;
	//(* mark_debug = "true" *)
    logic [REGS_DW-1 : 0]      beats_cnt, beats_cnt_r;
    //(* mark_debug = "true" *)
    logic                      dma_start_w;
    //(* mark_debug = "true" *)
    logic                      dma_axi4_busy;


    //(* mark_debug = "true" *)
	logic 					   axi4_tr_run, axi4_tr_run_r;
    //(* mark_debug = "true" *)
	logic 					   bvalid_done, bvalid_done_r;
    //(* mark_debug = "true" *)
	logic 					   write_addr_done, write_addr_done_r;
    //(* mark_debug = "true" *)
	logic 					   write_done, write_done_r;
    //(* mark_debug = "true" *)
	logic 					   write_start, write_start_r;

	logic 					   awvalid_r;
    logic                      awready_r;
	logic 					   wvalid_r;
	//(* mark_debug = "true" *)
    logic                      restart_in_dma_circ_mode;
    //logic                      start_tansfer_by_fifo_cnt_byte2;

    //axi_stream logic
    generate
        if (AXI_DW==T_DW) begin
            always_ff @(posedge aclk or posedge areset) begin
                if (areset) begin
                    fifo_cnt_bytes2_r <= 0;
                end
                else begin
                    fifo_cnt_bytes2_r <= fifo_cnt_bytes;
                end
            end
            always_comb begin
                m_tready = (dma_dir==DMA_DIR_AXI_STREAM_TO_AXI4) &&
                            ~fifo_full[0] &&
                            ~((fifo_cnt_bytes_r>=dma_len) && (dma_mode==DMA_DIRECT_MODE)) &&
                            dma_busy &&
                            ~(last_t_data && (dma_len==-1)) &&
                            ~dma_finish;

                for (int i=0; i<T_DW/8; i++) begin
                    fifo_wstrb[0][i] = m_tstrb[i] & m_tkeep[i];
                end
                num_of_bytes_by_strb = /*(T_DW / 8);//*/get_num_of_bytes_by_strb(fifo_wstrb[0]);

                fifo_wr_en[0] = m_tvalid & m_tready;
                if (dma_start_w || restart_in_dma_circ_mode) begin
                    fifo_cnt_bytes = 0;
                end
                else begin
                    fifo_cnt_bytes = fifo_cnt_bytes_r + (fifo_wr_en[0] ? num_of_bytes_by_strb : 0);//get_num_of_bytes_by_strb(fifo_wstrb)
                end
            end
            //assign start_tansfer_by_fifo_cnt_byte2 = 0;
        end
        else if (AXI_DW>T_DW) begin
            logic [$clog2(DW_FACTOR)-1:0] wr_fifo_idx, wr_fifo_idx_r;
            always_ff @(posedge aclk or posedge areset) begin
                if (areset) begin
                    wr_fifo_idx_r <= 0;
                    fifo_cnt_bytes2_r <= 0;
                end
                else begin
                    wr_fifo_idx_r <= wr_fifo_idx;
                    fifo_cnt_bytes2_r <= fifo_cnt_bytes2;
                end
            end
            always_comb begin
                m_tready = (dma_dir==DMA_DIR_AXI_STREAM_TO_AXI4) &&
                            ~fifo_full[wr_fifo_idx_r] &&
                            fifo_cnt_bytes_r<dma_len &&
                            dma_busy &&
                            ~(last_t_data && (dma_len==-1)) &&
                            ~dma_finish;

                num_of_ones = get_num_of_ones(fifo_rd_en_r);
                fifo_wstrb = '{default:0};
                fifo_wr_en = '{default:0};
                wr_fifo_idx = wr_fifo_idx_r;
                if (m_tvalid & m_tready) begin
                    fifo_wstrb[wr_fifo_idx_r] = m_tstrb & m_tkeep;
                    fifo_wr_en[wr_fifo_idx_r] = m_tvalid & m_tready;
                    if (wr_fifo_idx_r==(DW_FACTOR-1)) begin
                        wr_fifo_idx = 0;
                    end
                    else begin
                        wr_fifo_idx = wr_fifo_idx_r + 1;
                    end
                end

                if (dma_start_w) begin
                    wr_fifo_idx = dma_start_addr & (AXI_DW-1);
                    fifo_cnt_bytes = 0;
                    fifo_cnt_bytes2 = 0;
                end
                else begin
                    fifo_cnt_bytes = fifo_cnt_bytes_r + (fifo_wr_en[wr_fifo_idx_r] ? (T_DW/8) : 0);//get_num_of_bytes_by_strb(fifo_wstrb)
                    fifo_cnt_bytes2 = fifo_cnt_bytes2_r;
                    if (m_tvalid & m_tready) begin
                        fifo_cnt_bytes2 = fifo_cnt_bytes2_r + 1;
                    end
                    fifo_cnt_bytes2 = fifo_cnt_bytes2 - num_of_ones;
                    /*for (int i=0; i<DW_FACTOR; i++) begin
                        if (fifo_rd_en_r[i]) begin
                            if (fifo_cnt_bytes2>0)
                                fifo_cnt_bytes2--;
                        end
                    end*/
                end
            end
            //assign start_tansfer_by_fifo_cnt_byte2 = ((fifo_cnt_bytes2_r >= BASIC_TRANSFER_SIZE) && (DW_FACTOR>1));
        end
    endgenerate

    //axi4 regs
    always_ff @(posedge aclk or posedge areset) begin
        if (areset) begin
            fifo_cnt_bytes_r <= 0;
            transfered_cnt_bytes_r <= 0;
            fifo_rd_en_r <= 0;
            transfer_len_r <= 0;
            m_tlast_r <= 0;
            m_tvalid_r <= 0;
            last_t_data <= 0;

            awlen_r <= 0;
            awaddr_r <= 0;

            wdata_r <= 0;
            wstrb_r <= 0;
            wlast_r <= 0;
            bready  <= 0;

            dma_cur_addr <= 0;
            dma_cur_len  <= 0;
            dma_busy     <= 0;
            dma_axi4_busy <= 0;
            dma_finished <= 0;

            beats_cnt_r <= 0;

            axi4_tr_run_r <= 0;
            write_addr_done_r <= 0;
			write_done_r	<= 0;
            bvalid_done_r <= 0;
			write_start_r	<= 0;

			awvalid_r		<= 0;
            awready_r       <= 0;
			wvalid_r		<= 0;
            dma_finish <= 0;

            fifo_full_o <= 0;
            fifo_empty_o <= 1;
        end
        else begin
            fifo_cnt_bytes_r  <= fifo_cnt_bytes;
            transfered_cnt_bytes_r <= transfered_cnt_bytes;
            fifo_rd_en_r      <= fifo_rd_en;
            transfer_len_r    <= transfer_len;
            m_tlast_r <= m_tlast;
            m_tvalid_r <= m_tvalid;
            if (m_tvalid && m_tlast && (dma_len==-1)) begin
                last_t_data <= 1;
            end
            else if (last_t_data && all_empty/*fifo_empty[0]*/) begin
                last_t_data <= 0;
            end

            fifo_full_o <= all_full;
            fifo_empty_o <= all_empty & ~axi4_tr_run_r;

            awlen_r <= awlen_w;
            awaddr_r <= awaddr_w;
            awready_r <= awready;

            wdata_r <= wdata_w;
            wstrb_r <= wstrb_w;
            wlast_r <= wlast_w;

            bready  <= bready_w;


            dma_cur_addr	<= dma_cur_addr_w;
            dma_cur_len		<= dma_cur_len_w;
            beats_cnt_r		<= beats_cnt;

            axi4_tr_run_r <= axi4_tr_run;
            write_addr_done_r <= write_addr_done;
			write_done_r	<= write_done;
            bvalid_done_r <= bvalid_done;
			write_start_r	<= write_start;

			awvalid_r		<= awvalid_w;
			wvalid_r		<= wvalid_w;

            dma_finish <= ((  dma_len!=-1) && (dma_len!=0) && (dma_cur_len_w>=dma_len) && (dma_mode==DMA_DIRECT_MODE) ||
                            ( last_t_data && all_empty/*fifo_empty[0]*/) ||
                              dma_stop) ? 1 : 0;
            if (dma_start_w) begin
                dma_busy      <= 1;
                dma_axi4_busy <= 1;
            end
            else if (dma_finish) begin
                dma_busy      <= 0;
                dma_axi4_busy <= 0;
            end
        end
    end

    assign awvalid = awvalid_w;
    assign awaddr  = awvalid_w ? awaddr_w : 0;
    assign awlen   = awvalid_w ? awlen_w  : 0;
    assign awsize  = awsize_w;
    assign awburst = awburst_w;

    assign wvalid  = wvalid_w;
    assign wdata   = wvalid_w ? wdata_w : 0;
    assign wstrb   = wvalid_w ? wstrb_w : 0;
    assign wlast   = wvalid_w ? wlast_w : 0;

    always_comb begin
        if (dma_start_w) begin
            transfered_cnt_bytes = 0;
        end
        else if (bvalid && bready) begin
            transfered_cnt_bytes = transfered_cnt_bytes_r + transfer_len_r;
        end
        //edward: remove latch
        else begin
            transfered_cnt_bytes = transfered_cnt_bytes_r;
        end
    end
    assign fifo_cnt_bytes_o = transfered_cnt_bytes_r;

    //axi4 fsm
    always_comb begin
        if (AXI_DW==T_DW) begin
            all_full = fifo_full[0];
            all_empty = fifo_empty[0];
        end
        else if (AXI_DW>T_DW) begin
            all_full = 1;
            all_empty = 1;
            for (int i=0; i<DW_FACTOR; i++) begin
                if (~fifo_full[i]) all_full = 0;
                if (~fifo_empty[i]) all_empty = 0;
            end
        end

        dma_start_w       = dma_start && (dma_dir==DMA_DIR_AXI_STREAM_TO_AXI4);
        restart_in_dma_circ_mode = 0;//((dma_cur_len>=dma_len) && (dma_mode==DMA_CIRCULAR_MODE));
        dma_cur_addr_w = (dma_start_w || ~dma_axi4_busy/* || restart_in_dma_circ_mode*/) ? dma_start_addr : dma_cur_addr;
        dma_cur_len_w  = (dma_start_w || ~dma_axi4_busy/* || restart_in_dma_circ_mode*/) ? 0 : dma_cur_len;

        beats_cnt     = beats_cnt_r;
        addr_interval = max_addr - dma_cur_addr;
        bytes_to_transfer = fifo_cnt_bytes_r;// - dma_cur_len;
        start_axi4_transfer = (((bytes_to_transfer  >= dma_len) && (dma_len!=-1) && (dma_len!=0)) ||
                                all_full ||
                                ((fifo_cnt_bytes2_r >= BASIC_TRANSFER_SIZE) && (DW_FACTOR>1)) ||
                                ((flush_fifo || last_t_data) && (bytes_to_transfer >= dma_cur_len))) & ~dma_finish & dma_busy & ~axi4_tr_run_r;

        transfer_len = transfer_len_r;

        awaddr_mask = (AXI_DW/8 - 1);
        awaddr_w    = start_axi4_transfer ? (dma_cur_addr_w & ~awaddr_mask) : awaddr_r;
        awlen_w     = awlen_r;

        awsize_w  = AxSIZE;
        awburst_w = AxBURST_INCR;
        bready_w  = 1;

        wdata_w   = wdata_r;
        wstrb_w   = wstrb_r;
        wlast_w   = wlast_r;
        fifo_rd_en_r_or = |fifo_rd_en_r[DW_FACTOR-1:0];

        if ((AXI_DW==T_DW) && fifo_rd_en_r[0]) begin
            int num_of_bytes_by_strb_axi4;

            wdata_w  = fifo_rdata[0];
            wstrb_w  = fifo_rstrb[0];
            wlast_w  = (beats_cnt_r == (awlen_r + 1));

            num_of_bytes_by_strb_axi4 = get_num_of_bytes_by_strb_axi4(wstrb_w);
            if (dma_cur_addr + num_of_bytes_by_strb_axi4 < max_addr)
                dma_cur_addr_w = dma_cur_addr + num_of_bytes_by_strb_axi4;
            else
                dma_cur_addr_w = min_addr;
        end
        else if ((AXI_DW>T_DW) && fifo_rd_en_r_or) begin
            int num_of_bytes_by_strb_axi4;

            for (int i=0; i<DW_FACTOR; i++) begin
                wdata_w[i*T_DW +: T_DW]  = fifo_rdata[i];
                if (fifo_rd_en_r[i]) begin
                    wstrb_w[i*T_DW/8 +: T_DW/8]  = fifo_rstrb[i];
                end
                else begin
                    wstrb_w[i*T_DW/8 +: T_DW/8]  = 0;
                end
            end
            wlast_w  = (beats_cnt_r == (awlen_r + 1));

            num_of_bytes_by_strb_axi4 = get_num_of_bytes_by_strb_axi4(wstrb_w);
            if (dma_cur_addr + num_of_bytes_by_strb_axi4 < max_addr)
                dma_cur_addr_w = dma_cur_addr + num_of_bytes_by_strb_axi4;
            else
                dma_cur_addr_w = min_addr;
        end
        awaddr_shift_w = dma_cur_addr_w & awaddr_mask;

        fifo_rd_en = '{default: 0};

        axi4_tr_run = axi4_tr_run_r;
        write_addr_done = write_addr_done_r;
		write_done	= write_done_r;
        bvalid_done = bvalid_done_r;
		write_start = write_start_r;

		awvalid_w	= awvalid_r;
		wvalid_w	= wvalid_r;

		if (~write_done_r) begin
			if (start_axi4_transfer	& ~write_start_r) begin
				write_start = 1;
                axi4_tr_run = 1;

				if ((bytes_to_transfer - dma_cur_len) >= addr_interval) begin
					transfer_len = (addr_interval + 1);
				end
				else if (flush_fifo || last_t_data) begin
					transfer_len = fifo_cnt_bytes2_r;
				end
				else if (((bytes_to_transfer >= dma_len) && (dma_len!=-1))) begin
					transfer_len = bytes_to_transfer - dma_cur_len;
				end
				else if (all_full) begin
					transfer_len = FIFO_SIZE_BYTES;
				end
                else if ((fifo_cnt_bytes2_r >= BASIC_TRANSFER_SIZE) && (DW_FACTOR > 1)) begin
					transfer_len = BASIC_TRANSFER_SIZE;
                end

				awvalid_w = 1;
				awlen_w   = get_awlen(dma_cur_addr_w, transfer_len);//((transfer_len-1) >> AxSIZE);
				beats_cnt = 1;

                if (AXI_DW==T_DW) begin
				    fifo_rd_en[0] = 1;
                end
                else if (AXI_DW>T_DW) begin
                    for (int i=0; i<DW_FACTOR; i++) begin
    				    fifo_rd_en[i] = ~fifo_empty[i] && (i>=awaddr_shift_w);
                    end
                end
			end

            if (awvalid_r && awready_r) begin
                awvalid_w = 0;
                write_addr_done = 1;
            end

			if (write_start_r) begin
				wvalid_w = 1;
				if (wready) begin
					if (beats_cnt_r==(awlen_r + 1)) begin
						write_done = 1;
						write_start = 0;
					end
					else begin
						beats_cnt = beats_cnt_r + 1;
                        if (AXI_DW==T_DW) begin
                            fifo_rd_en[0] = 1;
                        end
                        else if (AXI_DW>T_DW) begin
                            for (int i=0; i<DW_FACTOR; i++) begin
                                fifo_rd_en[i] = ~fifo_empty[i] && (i>=awaddr_shift_w);
                            end
                        end
					end
				end
			end
		end
		else begin
			wvalid_w	= 0;

            if (awvalid_r && awready_r) begin
                awvalid_w = 0;
                write_addr_done = 1;
            end

			if ((bvalid || bvalid_done_r) && (write_addr_done_r || (awvalid_r && awready_r))) begin
                write_addr_done = 0;
				write_done = 0;
                bvalid_done = 0;
                axi4_tr_run = 0;

				//if (dma_cur_addr + transfer_len < max_addr)
				//	dma_cur_addr_w = dma_cur_addr + transfer_len;
				//else
				//	dma_cur_addr_w = min_addr;
				dma_cur_len_w = dma_cur_len + transfer_len;
                restart_in_dma_circ_mode = ((dma_cur_len_w>=dma_len) && (dma_mode==DMA_CIRCULAR_MODE));
                if (restart_in_dma_circ_mode) begin
                    dma_cur_addr_w = dma_start_addr;
                    dma_cur_len_w  = 0;
                end
			end
            else if (bvalid) begin
                bvalid_done = 1;
			end
		end

    end

    assign fifo_rstn = ~areset;

    generate
        if (AXI_DW==T_DW) begin
            sync_fifo1#(
        //	`DMA_AXIS_AXI4_SYNC_FIFO_NAME #(
                    .usr_ram_style ( usr_ram_style ),
                    .dw            ( T_DW          ),
                    .aw            ( FIFO_AW       )
                )data_fifo(
                    .clk    ( aclk       ),
                    .rstn   ( fifo_rstn  ),
                    .clr    ( 1'b0       ),
                    .rd_en  ( fifo_rd_en[0] ),
                    .dout   ( fifo_rdata[0] ),
                    .wr_en  ( fifo_wr_en[0] ),
                    .din    ( m_tdata    ),
                    .full   ( fifo_full[0]  ),
                    .empty  ( fifo_empty[0] )
                );

            sync_fifo1#(
            //`DMA_AXIS_AXI4_SYNC_FIFO_NAME #(
                    .usr_ram_style ( usr_ram_style       ),
                    .dw            ( T_DW/8              ),
                    .aw            ( FIFO_AW             )
                )strb_fifo(
                    .clk    ( aclk       ),
                    .rstn   ( fifo_rstn  ),
                    .clr    ( 1'b0       ),
                    .rd_en  ( fifo_rd_en[0] ),
                    .dout   ( fifo_rstrb[0] ),
                    .wr_en  ( fifo_wr_en[0] ),
                    .din    ( fifo_wstrb[0] ),
                    .full   (            ),
                    .empty  (            )
                );
        end
        else if (AXI_DW>T_DW) begin
            for (genvar i=0; i<DW_FACTOR; i++) begin
                sync_fifo1#(
            //	`DMA_AXIS_AXI4_SYNC_FIFO_NAME #(
                        .usr_ram_style ( usr_ram_style ),
                        .dw            ( T_DW          ),
                        .aw            ( FIFO_AW       )
                    )data_fifo(
                        .clk    ( aclk       ),
                        .rstn   ( fifo_rstn  ),
                        .clr    ( 1'b0       ),
                        .rd_en  ( fifo_rd_en[i] ),
                        .dout   ( fifo_rdata[i] ),
                        .wr_en  ( fifo_wr_en[i] ),
                        .din    ( m_tdata    ),
                        .full   ( fifo_full[i]  ),
                        .empty  ( fifo_empty[i] )
                    );

                sync_fifo1#(
                //`DMA_AXIS_AXI4_SYNC_FIFO_NAME #(
                        .usr_ram_style ( usr_ram_style       ),
                        .dw            ( T_DW/8              ),
                        .aw            ( FIFO_AW             )
                    )strb_fifo(
                        .clk    ( aclk       ),
                        .rstn   ( fifo_rstn  ),
                        .clr    ( 1'b0       ),
                        .rd_en  ( fifo_rd_en[i] ),
                        .dout   ( fifo_rstrb[i] ),
                        .wr_en  ( fifo_wr_en[i] ),
                        .din    ( fifo_wstrb[i] ),
                        .full   (            ),
                        .empty  (            )
                    );
            end
        end
    endgenerate

    function logic [$clog2(DW_FACTOR):0] get_num_of_ones(input [DW_FACTOR-1:0] inp);
        int i;
        get_num_of_ones = 0;
        for (i=0; i<DW_FACTOR; i++) begin
            //if (~inp[i]) break;
            get_num_of_ones += inp[i];
        end
        //get_num_of_ones = i;
    endfunction

    function logic [$clog2(T_DW/8):0] get_num_of_bytes_by_strb(input [T_DW/8-1:0] strb);
        get_num_of_bytes_by_strb = 0;
        for (int i=0; i<T_DW/8; i++) begin
            if (strb[i]) get_num_of_bytes_by_strb++;
        end
    endfunction

    function logic [$clog2(AXI_DW/8):0] get_num_of_bytes_by_strb_axi4(input [AXI_DW/8-1:0] strb);
        get_num_of_bytes_by_strb_axi4 = 0;
        for (int i=0; i<AXI_DW/8; i++) begin
            if (strb[i]) get_num_of_bytes_by_strb_axi4++;
        end
    endfunction

    function logic [7:0] get_awlen(input [AXI_AW-1:0] start_address, input [AXI_AW-1:0] tr_len);
        logic [AXI_AW-1:0] finish_address;
        logic [AXI_AW-1:0] interval;
        finish_address = start_address + tr_len;
        interval = finish_address - (start_address & ~(AXI_DW/8 - 1));
        get_awlen = (interval-1) >> AxSIZE;
    endfunction

endmodule

