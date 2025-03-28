

module cacheIf_axi4_conv #(
    parameter int DW_WR = 32,
    parameter int DW_RD = 32,
    parameter int AW = 32,
    parameter int LEN = 16,
    parameter int WFIFO_DEPTH = 16,
    parameter int RFIFO_DEPTH = 16,
    parameter int RCHAN_IS_AXIS = 0,
    parameter int WCHAN_IS_AXIS = 0
) (
    input                   clk,
    input                   rstn,

    input   [8:0]           burst_len_i,
    input   [LEN-1:0]       len_i,
    input   [7:0]           id_i,
    input                   start_i,
    input                   stop_rd,
    input                   stop_wr,
    input   [AW-1:0]        start_rd_addr_i,
    input   [AW-1:0]        start_wr_addr_i,
    input                   clr_fifo_i,
    output  logic           done_o,

    //Memory read
    input                   mem_re,
    input   [AW-1:0]        mem_rad,
    output                  mem_rreq_rdy,
    output  [DW_RD-1:0]     mem_rdat,
    output                  mem_rdat_rdy,
    input                   rdfifo_full_n,

    //Memory write
    input   [DW_WR/8-1:0]   mem_bwe,
    input   [AW-1:0]        mem_wad,
    input   [DW_WR-1:0]     mem_wdat,
    output                  mem_wreq_rdy,

    //axi4 write address channel signals
    output                  axi4_awvalid,
    input                   axi4_awready,
    output  [AW-1 : 0]      axi4_awaddr,
    output  [7 : 0]         axi4_awlen,
    output  [2 : 0]         axi4_awsize,
    output  [1 : 0]         axi4_awburst,
    output  [7 : 0]         axi4_awid,

    //axi4 write data channel signals
    output                  axi4_wvalid,
    input                   axi4_wready,
    output  [DW_WR-1:0]     axi4_wdata,
    output  [DW_WR/8-1:0]   axi4_wstrb,
    output                  axi4_wlast,
    output  [7 : 0]         axi4_wid,

    //axi4 write response channel signals
    input                   axi4_bvalid,
    output                  axi4_bready,
    input                   axi4_bresp,

    //axi4 read address channel signals
    output                  axi4_arvalid,
    input                   axi4_arready,
    output  [AW-1 : 0]      axi4_araddr,
    output  [7 : 0]         axi4_arlen,
    output  [2 : 0]         axi4_arsize,
    output  [1 : 0]         axi4_arburst,
    output  [7 : 0]         axi4_arid,

    //axi4 write data channel signals
    input                   axi4_rvalid,
    output                  axi4_rready,
    input   [DW_RD-1:0]     axi4_rdata,
    input                   axi4_rlast
);

    wire   rdone, wdone;

    cacheIf_axi4_wchan #(
        .DW         (DW_WR),
        .AW         (AW),
        .LEN        (LEN),
        .FIFO_DEPTH (WFIFO_DEPTH),
        .IS_AXIS    (WCHAN_IS_AXIS)
    ) wchan (
        .clk            (clk),
        .rstn           (rstn),
        .burst_len_i    (burst_len_i),
        .len_i          (len_i),
        .id_i           (id_i),
        .start_addr_i   (start_wr_addr_i),
        .start_i        (start_i),
        .stop_i         (stop_wr),
        .clr_fifo_i     (clr_fifo_i),
        .done_o         (wdone),

        .mem_bwe        (mem_bwe),
        .mem_wad        (mem_wad),
        .mem_wdat       (mem_wdat),
        .mem_wreq_rdy   (mem_wreq_rdy),

        .axi4_awvalid   (axi4_awvalid),
        .axi4_awready   (axi4_awready),
        .axi4_awaddr    (axi4_awaddr),
        .axi4_awlen     (axi4_awlen),
        .axi4_awsize    (axi4_awsize),
        .axi4_awburst   (axi4_awburst),
        .axi4_awid      (axi4_awid),
        .axi4_wvalid    (axi4_wvalid),
        .axi4_wready    (axi4_wready),
        .axi4_wdata     (axi4_wdata),
        .axi4_wstrb     (axi4_wstrb),
        .axi4_wlast     (axi4_wlast),
        .axi4_wid       (axi4_wid),
        .axi4_bvalid    (axi4_bvalid),
        .axi4_bready    (axi4_bready),
        .axi4_bresp     (axi4_bresp)
    );

    cacheIf_axi4_rchan #(
        .DW         (DW_RD),
        .AW         (AW),
        .LEN        (LEN),
        .FIFO_DEPTH (RFIFO_DEPTH),
        .IS_AXIS    (RCHAN_IS_AXIS)
    ) rchan (
        .clk            (clk),
        .rstn           (rstn),
        .burst_len_i    (burst_len_i),
        .len_i          (len_i),
        .id_i           (id_i),
        .start_addr_i   (start_rd_addr_i),
        .start_i        (start_i),
        .stop_i         (stop_rd),
        .clr_fifo_i     (clr_fifo_i),
        .done_o         (rdone),

        .mem_re         (mem_re),
        .mem_rad        (mem_rad),
        .mem_rreq_rdy   (mem_rreq_rdy),
        .mem_rdat       (mem_rdat),
        .mem_rdat_rdy   (mem_rdat_rdy),
        .rdfifo_full_n  (rdfifo_full_n),

        .axi4_arvalid   (axi4_arvalid),
        .axi4_arready   (axi4_arready),
        .axi4_araddr    (axi4_araddr),
        .axi4_arlen     (axi4_arlen),
        .axi4_arsize    (axi4_arsize),
        .axi4_arburst   (axi4_arburst),
        .axi4_arid      (axi4_arid),
        .axi4_rvalid    (axi4_rvalid),
        .axi4_rready    (axi4_rready),
        .axi4_rdata     (axi4_rdata),
        .axi4_rlast     (axi4_rlast)
    );

    //assing done_o = rdone & wdone;
    always_comb begin
        done_o = rdone & wdone;
    end

endmodule