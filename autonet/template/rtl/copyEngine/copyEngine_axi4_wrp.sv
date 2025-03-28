


module copyEngine_axi4_wrp #(
	parameter ID			= 0,
    //risc interface
    parameter RISC_AW       = 32,
    parameter RISC_DW       = 32,
    //copyEngine, cacheIf_axi4_conv
    parameter WDATA_WIDTH   = 32,
    parameter RDATA_WIDTH   = 32,
    parameter ADDR_WIDTH    = 32,
    parameter LEN           = 16,
    parameter WFIFO_DEPTH   = 16,
    parameter RFIFO_DEPTH   = 16,
    parameter RCHAN_IS_AXIS = 0,
    parameter WCHAN_IS_AXIS = 0
) (

    //common interface
    input                               rstn,
    input                               clk,
    //Risc interface
    input                               riscRe,
    input                               riscWe,
    input        [RISC_AW-1:0]          riscAdr,
    input        [RISC_DW-1:0]          riscWDat,
    output logic                        riscRdy,
    output logic                        riscRVld,
    output logic [RISC_DW-1:0]          riscRDat,
    output logic                        done_o,
    //--
    output logic 			copy_o,
    output logic [ADDR_WIDTH-1:0]	len_o,

    //axi4 write address channel signals
    output logic                        axi4_awvalid,
    input                               axi4_awready,
    output logic [ADDR_WIDTH-1 : 0]     axi4_awaddr,
    output logic [7 : 0]                axi4_awlen,
    output logic [2 : 0]                axi4_awsize,
    output logic [1 : 0]                axi4_awburst,

    //axi4 write data channel signals
    output logic                        axi4_wvalid,
    input                               axi4_wready,
    output logic [WDATA_WIDTH-1:0]      axi4_wdata,
    output logic [WDATA_WIDTH/8-1:0]    axi4_wstrb,
    output logic                        axi4_wlast,

    //axi4 write response channel signals
    input                               axi4_bvalid,
    output logic                        axi4_bready,
    input                               axi4_bresp,

    //axi4 read address channel signals
    output logic                        axi4_arvalid,
    input                               axi4_arready,
    output logic [ADDR_WIDTH-1 : 0]     axi4_araddr,
    output logic [7 : 0]                axi4_arlen,
    output logic [2 : 0]                axi4_arsize,
    output logic [1 : 0]                axi4_arburst,

    //axi4 write data channel signals
    input                               axi4_rvalid,
    output logic                        axi4_rready,
    input        [RDATA_WIDTH-1:0]      axi4_rdata,
    input                               axi4_rlast


);

    //--------------------------------------------------
    //parameter
    //--------------------------------------------------
    //localparam WR_CMD_SRC_DW_SEL     = 0;
    //localparam WR_CMD_DST_DW_SEL     = 1;
    localparam WR_CMD_COPY           = 0;
    localparam WR_CMD_SET            = 1;
    localparam WR_CMD_SET_VAL        = 2;
    localparam WR_CMD_FLUSH          = 3;
    localparam WR_CMD_LEN            = 4;
    localparam WR_CMD_SRC            = 5;
    localparam WR_CMD_DST            = 6;
    localparam WR_CMD_BL             = 7;
    localparam RD_CMD_DONE           = 8;
    localparam WR_CMD_STOP           = 9;

    //--------------------------------------------------
    //signals
    //--------------------------------------------------
    logic                     clr_conv_fifo;
    logic                     dma_done;
    logic                     set;
    logic                     set_r;
    logic                     copy;
    logic                     copy_r;
    logic [7:0]               setVal;
    logic [7:0]               setVal_r;
    logic [ADDR_WIDTH-1:0]    src;
    logic [ADDR_WIDTH-1:0]    src_r;
    logic [ADDR_WIDTH-1:0]    dst;
    logic [ADDR_WIDTH-1:0]    dst_r;
    logic [LEN-1:0]           len;
    logic [LEN-1:0]           len_r;
    logic                     conv_done;
    logic [8:0]               burst_len_r, burst_len;
    logic                     stop, stop_r;
    logic                     stop_axi4_wr;

    //Memory read
    logic                     mem_re_r;
    logic [ADDR_WIDTH-1:0]    mem_rad_r;
    logic                     mem_rreq_rdy;
    logic [RDATA_WIDTH-1:0]   mem_rdat;
    logic                     mem_rdat_rdy;
    logic                     rdfifo_full_n;

    //Memory write
    logic [WDATA_WIDTH/8-1:0] mem_bwe_r;
    logic [ADDR_WIDTH-1:0]    mem_wad_r;
    logic [WDATA_WIDTH-1:0]   mem_wdat_r;
    logic                     mem_wreq_rdy;

    //--------------------------------------------------
    //risc interface
    //--------------------------------------------------
    always @ (posedge clk or negedge rstn) begin
        if (~rstn) begin
            copy_r          <= 0;
            set_r           <= 0;
            setVal_r        <= 0;
            len_r           <= 0;
            src_r           <= 0;
            dst_r           <= 0;
            burst_len_r     <= 'd1;
            stop_r          <= 0;

            riscRVld        <= 0;
            riscRDat        <= 0;
        end
        else begin
            copy_r          <= copy;
            set_r           <= set;
            setVal_r        <= setVal;
            len_r           <= len;
            src_r           <= src;
            dst_r           <= dst;
            burst_len_r     <= burst_len;
            stop_r          <= stop;

			riscRVld <= 0;	
			if (riscAdr[9:8] == ID) begin
				riscRVld <= riscRe;
			end 	
            case (riscAdr[7:0])
                RD_CMD_DONE: riscRDat <= done_o;
            endcase
        end
    end

    always_comb begin
        done_o          = conv_done & dma_done;
        copy            = 0;
        set             = 0;
        setVal          = setVal_r;
        len             = len_r;
        src             = src_r;
        dst             = dst_r;
        clr_conv_fifo   = 0;
        riscRdy         = done_o | stop_r;
        burst_len       = burst_len_r;
        stop            = (riscWe && (riscAdr[7:0]==WR_CMD_STOP));

        if (riscWe & riscRdy & (riscAdr[9:8] == ID)) begin
            case (riscAdr[7:0])
                WR_CMD_COPY:          copy            = 1;
                WR_CMD_SET:           set             = 1;
                WR_CMD_SET_VAL:       setVal          = riscWDat[7:0];
                WR_CMD_LEN:           len             = riscWDat[LEN-1:0];
                WR_CMD_SRC:           src             = riscWDat[ADDR_WIDTH-1:0];
                WR_CMD_DST:           dst             = riscWDat[ADDR_WIDTH-1:0];
                WR_CMD_BL:            burst_len       = riscWDat[8:0];
            endcase
        end
    end

    //--------------------------------------------------
    //copyEngine
    //--------------------------------------------------
    copyEngine_v3 #(
        .WDATA_WIDTH    (WDATA_WIDTH),
        .RDATA_WIDTH    (RDATA_WIDTH),
        .ADDR_WIDTH     (ADDR_WIDTH),
        .LEN            (LEN),
        .CONV_32_64     (0)
    ) inst_copyEngine (
        .rstn           (rstn),
        .clk            (clk),
        .src_dw_sel_i   ('0),
        .dst_dw_sel_i   ('0),
        .copy_i         (copy_r),
        .set_i          (set_r),
        .setVal_i       (setVal_r),
        .flush_i        ('0),
        .stop_i         (stop_r),
        .len_i          (len_r[LEN-1:0]),
        .src_i          (src_r),
        .dst_i          (dst_r),
        .done_o         (dma_done),
        .mem_re_r       (mem_re_r),
        .mem_rad_r      (mem_rad_r),
        .mem_rreq_rdy   (mem_rreq_rdy),
        .mem_rdat       (mem_rdat),
        .mem_rdat_rdy   (mem_rdat_rdy),
        .rdfifo_full_n  (rdfifo_full_n),
        .mem_bwe_r      (mem_bwe_r),
        .mem_wad_r      (mem_wad_r),
        .mem_wdat_r     (mem_wdat_r),
        .mem_wreq_rdy   (mem_wreq_rdy),
        .stop_axi4_r    (stop_axi4_wr),
        .flush_r        (),
        .cmd_adr_r      (),
        .cmd_rdy        (1'b1)
    );

    //--------------------------------------------------
    //cacheIf_axi4_conv
    //--------------------------------------------------
    cacheIf_axi4_conv #(
        .DW_WR              (WDATA_WIDTH),
        .DW_RD              (RDATA_WIDTH),
        .AW                 (ADDR_WIDTH),
        .LEN                (LEN),
        .WFIFO_DEPTH        (WFIFO_DEPTH),
        .RFIFO_DEPTH        (RFIFO_DEPTH),
        .RCHAN_IS_AXIS      (RCHAN_IS_AXIS),
        .WCHAN_IS_AXIS      (WCHAN_IS_AXIS)
    ) inst_cacheIf_axi4_conv (
        .clk                (clk),
        .rstn               (rstn),

        .id_i               ('0),
        .burst_len_i        (burst_len_r),
        .len_i              (len_r),
        .start_i            (set_r | copy_r),
        .clr_fifo_i         (clr_conv_fifo),
        .start_rd_addr_i    (src_r),
        .start_wr_addr_i    (dst_r),
        .stop_rd            (stop_r),
        .stop_wr            (stop_axi4_wr),
        .done_o             (conv_done),

        .mem_bwe            (mem_bwe_r),
        .mem_wad            (mem_wad_r),
        .mem_wdat           (mem_wdat_r),
        .mem_wreq_rdy       (mem_wreq_rdy),
        .mem_re             (mem_re_r),
        .mem_rad            (mem_rad_r),
        .mem_rreq_rdy       (mem_rreq_rdy),
        .mem_rdat           (mem_rdat),
        .mem_rdat_rdy       (mem_rdat_rdy),
        .rdfifo_full_n      (rdfifo_full_n),

        .axi4_awvalid       (axi4_awvalid),
        .axi4_awready       (axi4_awready),
        .axi4_awaddr        (axi4_awaddr),
        .axi4_awlen         (axi4_awlen),
        .axi4_awsize        (axi4_awsize),
        .axi4_awburst       (axi4_awburst),
        .axi4_wvalid        (axi4_wvalid),
        .axi4_wready        (axi4_wready),
        .axi4_wdata         (axi4_wdata),
        .axi4_wstrb         (axi4_wstrb),
        .axi4_wlast         (axi4_wlast),
        .axi4_bvalid        (axi4_bvalid),
        .axi4_bready        (axi4_bready),
        .axi4_bresp         (axi4_bresp),
        .axi4_arvalid       (axi4_arvalid),
        .axi4_arready       (axi4_arready),
        .axi4_araddr        (axi4_araddr),
        .axi4_arlen         (axi4_arlen),
        .axi4_arsize        (axi4_arsize),
        .axi4_arburst       (axi4_arburst),
        .axi4_rvalid        (axi4_rvalid),
        .axi4_rready        (axi4_rready),
        .axi4_rdata         (axi4_rdata),
        .axi4_rlast         (axi4_rlast)
    );

	assign copy_o = copy_r; 
	assign len_o  = len_r; 

endmodule