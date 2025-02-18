
module dma_axiStream_axi4_regs_t import dma_axiStream_axi4_pkg_t::*;
                        #(
                            parameter REGS_DW            = 32,
                            parameter REGS_AW            = 4
                          )(
                              //-------------------------------------------------------------------------
                              output logic regs_rdy_o_tp,
                              output logic start_o_tp,
                              output logic stop_o_tp,
                              //-------------------------------------------------------------------------

                              input                         aclk,
                              input                         areset,
                              //(* mark_debug = "true" *)
                              input                         regs_we_i,
                              //(* mark_debug = "true" *)
                              input        [REGS_AW-1 : 0]  regs_addr_i,
                              //(* mark_debug = "true" *)
                              input        [REGS_DW-1 : 0]  regs_wdata_i,
                              output logic [REGS_DW-1 : 0]  regs_rdata_o,
                              //(* mark_debug = "true" *)
                              output logic                  regs_rdy_o,

                              input                         axi4_to_stream_busy_i,
                              input                         stream_to_axi4_busy_i,

                              input                         axis_axi4_fifo_empty,
                              input                         axis_axi4_fifo_full,
                              input        [REGS_DW-1 : 0]  axis_axi4_fifo_cnt_bytes,
                              input                         axi4_axis_fifo_empty,
                              input                         axi4_axis_fifo_full,
                              input        [REGS_DW-1 : 0]  axi4_axis_fifo_cnt_bytes,

                              output logic                  start_o,
                              output logic                  stop_o,
                              //(* mark_debug = "true" *)
                              output logic                  flush_fifo_axis_axi4_o,
                              //(* mark_debug = "true" *)
                              output logic                  flush_fifo_axi4_axis_o,
                              output logic [REGS_DW-1 : 0]  min_addr_o,
                              output logic [REGS_DW-1 : 0]  max_addr_o,
                              output logic [REGS_DW-1 : 0]  dma_start_addr_o,
                              output logic [REGS_DW-1 : 0]  dma_len_o,
                              output logic                  dma_dir_o,
                              output logic                  dma_mode_o
                          );

    /*
     * The DMA has the following control register:
        - minAdr: the minimum address of DMA buffer allocated in DDR
        - maxAdr: the maximum address of DMA buffer allocated in DDR
        - dmaStart: DMA start byte address
        - dmaLen: DMA length in terms of bytes
        - dmaDir: DMA direction: from AXI stream master to DDR or from DDR to AXI stream slave
     * */
    logic [REGS_DW-1 : 0] min_addr;
    logic [REGS_DW-1 : 0] max_addr;
    logic [REGS_DW-1 : 0] dma_start_addr;
    logic [REGS_DW-1 : 0] dma_len;
    logic                 dma_dir;
    logic                 dma_mode;
    logic [REGS_DW-1 : 0] regs_rdata_w;
    logic [1 : 0]         ctrl_r, ctrl_w;
    logic [3 : 0]         fifo_status;
	logic 				  regs_rdy_r;

    always_ff @(posedge aclk or posedge areset) begin
        if (areset) begin
            min_addr_o   <= 0;
            max_addr_o   <= 0;
            dma_start_addr_o  <= 0;
            dma_len_o    <= 0;
            dma_dir_o    <= 0;
            dma_mode_o   <= 0;
            regs_rdata_o <= 0;
            ctrl_r       <= 0;
			regs_rdy_r	 <= 0;
        end
        else begin
            min_addr_o   <= min_addr;
            max_addr_o   <= max_addr;
            dma_start_addr_o  <= dma_start_addr;
            dma_len_o    <= dma_len;
            dma_dir_o    <= dma_dir;
            dma_mode_o   <= dma_mode;
            regs_rdata_o <= regs_rdata_w;
            ctrl_r       <= ctrl_w;
			regs_rdy_r	 <= (~axi4_to_stream_busy_i & ~stream_to_axi4_busy_i) ||
                            (regs_we_i && ((regs_addr_i==DMA_AXIS_AXI4_FLUSH_FIFO ) || (regs_addr_i==DMA_AXIS_AXI4_FLUSH_FIFO ))) ||
                            (~regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_FIFO_STATUS || regs_addr_i==DMA_AXIS_AXI4_FIFO_CNT || regs_addr_i==DMA_AXI4_AXIS_FIFO_CNT));
        end
    end

    always_comb begin
        regs_rdy_o = regs_rdy_r;

        start_o        = ctrl_r[0] && (dma_start_addr_o >= min_addr_o) && (dma_start_addr_o <= max_addr_o) && (dma_len_o!=0);
        stop_o         = ctrl_r[1];
        ctrl_w         = ((regs_rdy_r || /*dma_len_o==-1*/regs_wdata_i[1] || dma_mode_o==DMA_CIRCULAR_MODE) && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_CTRL     )) ? regs_wdata_i : 0;
        min_addr       = (regs_rdy_r && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_MIN_ADDR )) ? regs_wdata_i : min_addr_o;
        max_addr       = (regs_rdy_r && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_MAX_ADDR )) ? regs_wdata_i : max_addr_o;
        dma_start_addr = (regs_rdy_r && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_DMA_START)) ? regs_wdata_i : dma_start_addr_o;
        dma_len        = (regs_rdy_r && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_DMA_LEN  )) ? regs_wdata_i : dma_len_o;
        dma_dir        = (regs_rdy_r && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_DMA_DIR  )) ? regs_wdata_i : dma_dir_o;
        dma_mode       = (regs_rdy_r && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_DMA_MODE )) ? regs_wdata_i : dma_mode_o;

        flush_fifo_axis_axi4_o       = (regs_rdy_r && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_FLUSH_FIFO )) ? regs_wdata_i[0] : 0;
        flush_fifo_axi4_axis_o       = (regs_rdy_r && regs_we_i && (regs_addr_i==DMA_AXIS_AXI4_FLUSH_FIFO )) ? regs_wdata_i[1] : 0;

        regs_rdata_w = 0;
        case (regs_addr_i)
            DMA_AXIS_AXI4_CTRL: begin
                regs_rdata_w = (axi4_to_stream_busy_i << 1) | stream_to_axi4_busy_i;
            end

            DMA_AXIS_AXI4_MIN_ADDR: begin
                regs_rdata_w = min_addr_o;
            end

            DMA_AXIS_AXI4_MAX_ADDR: begin
                regs_rdata_w = max_addr_o;
            end

            DMA_AXIS_AXI4_DMA_START: begin
                regs_rdata_w = dma_start_addr_o;
            end

            DMA_AXIS_AXI4_DMA_LEN: begin
                regs_rdata_w = dma_len_o;
            end

            DMA_AXIS_AXI4_DMA_DIR: begin
                regs_rdata_w = dma_dir_o;
            end

            DMA_AXIS_AXI4_DMA_MODE: begin
                regs_rdata_w = dma_mode_o;
            end

            DMA_AXIS_AXI4_FIFO_STATUS: begin
                regs_rdata_w[3:0] = {axi4_axis_fifo_full, axi4_axis_fifo_empty,
                                     axis_axi4_fifo_full, axis_axi4_fifo_empty};
            end

            DMA_AXIS_AXI4_FIFO_CNT: begin
                regs_rdata_w = axis_axi4_fifo_cnt_bytes;
            end

            DMA_AXI4_AXIS_FIFO_CNT:
            begin
                regs_rdata_w = axi4_axis_fifo_cnt_bytes;
            end
        endcase
    end

//-------------------------------------------------------
//so debug
//-------------------------------------------------------
assign regs_rdy_o_tp = regs_rdy_o;
logic start_o_r;
logic start_o_2r;
logic start_o_3r;

logic stop_o_r;
logic stop_o_2r;
logic stop_o_3r;

always_ff @(posedge aclk or posedge areset) begin
    if (areset) begin
        start_o_r <= 0;
        start_o_2r <= 0;
        start_o_3r <= 0;
        start_o_tp <= 0;

        stop_o_r <= 0;
        stop_o_2r <= 0;
        stop_o_3r <= 0;
        stop_o_tp <= 0;
    end
    else begin
        start_o_r <= start_o;
        start_o_2r <= start_o_r;
        start_o_3r <= start_o_2r;
        start_o_tp <= start_o | start_o_r | start_o_2r | start_o_3r;

        stop_o_r <= stop_o;
        stop_o_2r <= stop_o_r;
        stop_o_3r <= stop_o_2r;
        stop_o_tp <= stop_o | stop_o_r | stop_o_2r | stop_o_3r;
    end
end

endmodule

