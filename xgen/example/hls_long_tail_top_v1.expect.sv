//Apply the patch from openhevc_fill_ref_sample.patch
////////////////////////////////////////////////////////////////////////////////
// Company            : ViShare Technology Limited
// Designed by        : Edward Leung
// Date Created       : 2023-07-03
// Description        : Top of HLS long tail function.
// Version            : v1.0 - First version.
//                      v1.1 - With xmem interface from HLS.
////////////////////////////////////////////////////////////////////////////////

//param_list = import hls_long_tail_pkg::*; import fill_ref_sample_pkg::*;

//`include "common.vh"

//`ifdef ENABLE_DEC
    import fill_ref_sample_pkg::*;
//`endif

 	
module hls_long_tail_top_v1 import hls_long_tail_pkg::*, xcache_param_pkg::*; //import decoupled_system_pkg::*;
#(
    parameter CORE_ID        = 0,
    parameter AXI_ADDR_WIDTH = 32,
    parameter AXI_DATA_WIDTH = 256,
    parameter AXI_LEN_WIDTH  = 8,
    parameter AXI_ID_WIDTH   = 8,
    parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8
)
(
    input                                 clk,
    input                                 rstn,
    //Main Riscv
    input                                 rv0_re,
    input        [ 3 : 0]                 rv0_we,
    input        [31 : 0]                 rv0_addr,
    input        [31 : 0]                 rv0_wdata,
    output logic                          rv0_ready,
    output logic                          rv0_valid,
    output logic [31 : 0]                 rv0_rdata,
    //Slave Riscv
    input                                 rv1_re,
    input        [ 3 : 0]                 rv1_we,
    input        [31 : 0]                 rv1_addr,
    input        [31 : 0]                 rv1_wdata,
    output logic                          rv1_ready,
    output logic                          rv1_valid,
    output logic [31 : 0]                 rv1_rdata,
	//connecting to dcache use interface arbiter
    input 	 	                      	  hls_user_rdy,
    output logic                          hls_user_re,
    output logic                          hls_user_we,
    output logic [3  : 0]			   	  hls_user_we_mask,
    output logic [31 : 0]          	   	  hls_user_adr,
    output logic [31 : 0]          	   	  hls_user_wdat,
    output logic                   	   	  hls_user_csr_flush,
    input 		 [31 : 0]         	   	  hls_user_rdat,
    input 		                 	   	  hls_user_rdat_vld,
    //DecodeBin
    output logic [ 8 : 0]                 decBin_ctx,
    output logic                          decBin_get,
    input                                 decBin_rdy,
    input                                 decBin_bin,
    input                                 decBin_vld,
    //From dataflow HLS
    output logic                          hls_rdy0,
    input                                 hls_ce0,
    input        [ 3 : 0]                 hls_we0,
    input        [31 : 0]                 hls_address0,
    input        [31 : 0]                 hls_d0,
    //Output xmem registers
    output logic                          transquant_bypass_o,
    output logic [7:0]                    pred_mode_o,
    output logic [7:0]                    qp_offset_cb_o,
    output logic [7:0]                    qp_offset_cr_o,
    output logic [7:0]                    intra_pred_mode_o,
    output logic [7:0]                    intra_pred_mode_c_o,
    output logic [7:0]                    qp_y_o,
    output logic [7:0]                    scan_idx_o,
    /*
	//Dataflow interface
    input                                 dataflow_rdy,
    output logic                          dataflow_re,
    output logic                          dataflow_we,
    output logic [MPORT_ADDR_WIDTH-1:0]   dataflow_addr,
    output logic [MPORT_STRB_WIDTH-1:0]   dataflow_strb,
    output logic [MPORT_DATA_WIDTH-1:0]   dataflow_din,
    input                                 dataflow_dout_vld,
    input        [MPORT_DATA_WIDTH-1:0]   dataflow_dout,
    output logic                          dataflow_flush,
    output logic [MPORT_ADDR_WIDTH-1:0]   dataflow_flush_cnt,
	*/
	
    //AXI4 interface 0 (write channel)
    input                                 axi_awready,
    output logic                          axi_awvalid,
    output logic [AXI_ADDR_WIDTH-1 : 0]   axi_awaddr,
    output logic [AXI_LEN_WIDTH-1 : 0]    axi_awlen,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_awid,
    output logic [2 : 0]                  axi_awsize,
    output logic [1 : 0]                  axi_awburst,
    output logic                          axi_awlock,
    output logic [3 : 0]                  axi_awcache,
    output logic [2 : 0]                  axi_awprot,
    output logic [3 : 0]                  axi_awqos,
    output logic [3 : 0]                  axi_awregion,
    output logic                          axi_awuser,
    input                                 axi_wready,
    output logic                          axi_wvalid,
    output logic [AXI_DATA_WIDTH - 1 : 0] axi_wdata,
    output logic [AXI_STRB_WIDTH - 1 : 0] axi_wstrb,
    output logic                          axi_wlast,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_wid,
    output logic                          axi_wuser,
    output logic                          axi_bready,
    input                                 axi_bvalid,
    input        [1 : 0]                  axi_bresp,
    input        [AXI_ID_WIDTH-1 : 0]     axi_bid,
    input                                 axi_buser, 
    //AXI4 interface (read channel)
    input                                 axi_arready,
    output logic                          axi_arvalid,
    output logic [AXI_ADDR_WIDTH-1 : 0]   axi_araddr,
    output logic [AXI_LEN_WIDTH-1 : 0]    axi_arlen,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_arid,
    output logic [2 : 0]                  axi_arsize,
    output logic [1 : 0]                  axi_arburst,
    output logic                          axi_arlock,
    output logic [3 : 0]                  axi_arcache,
    output logic [2 : 0]                  axi_arprot,
    output logic [3 : 0]                  axi_arqos,
    output logic [3 : 0]                  axi_arregion,
    output logic                          axi_aruser,
    input                                 axi_rvalid,
    output logic                          axi_rready,
    input        [AXI_DATA_WIDTH-1 : 0]   axi_rdata,
    input                                 axi_rlast,
    input        [1 : 0]                  axi_rresp,
    input        [AXI_ID_WIDTH-1 : 0]     axi_rid,
    input                                 axi_ruser,
	
    //AXI4 interface 1 (write channel)
    input                                 axi_awready_1,
    output logic                          axi_awvalid_1,
    output logic [AXI_ADDR_WIDTH-1 : 0]   axi_awaddr_1,
    output logic [AXI_LEN_WIDTH-1 : 0]    axi_awlen_1,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_awid_1,
    output logic [2 : 0]                  axi_awsize_1,
    output logic [1 : 0]                  axi_awburst_1,
    output logic                          axi_awlock_1,
    output logic [3 : 0]                  axi_awcache_1,
    output logic [2 : 0]                  axi_awprot_1,
    output logic [3 : 0]                  axi_awqos_1,
    output logic [3 : 0]                  axi_awregion_1,
    output logic                          axi_awuser_1,
    input                                 axi_wready_1,
    output logic                          axi_wvalid_1,
    output logic [AXI_DATA_WIDTH - 1 : 0] axi_wdata_1,
    output logic [AXI_STRB_WIDTH - 1 : 0] axi_wstrb_1,
    output logic                          axi_wlast_1,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_wid_1,
    output logic                          axi_wuser_1,
    output logic                          axi_bready_1,
    input                                 axi_bvalid_1,
    input        [1 : 0]                  axi_bresp_1,
    input        [AXI_ID_WIDTH-1 : 0]     axi_bid_1,
    input                                 axi_buser_1, 
    //AXI4 interface 1 (read channel)
    input                                 axi_arready_1,
    output logic                          axi_arvalid_1,
    output logic [AXI_ADDR_WIDTH-1 : 0]   axi_araddr_1,
    output logic [AXI_LEN_WIDTH-1 : 0]    axi_arlen_1,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_arid_1,
    output logic [2 : 0]                  axi_arsize_1,
    output logic [1 : 0]                  axi_arburst_1,
    output logic                          axi_arlock_1,
    output logic [3 : 0]                  axi_arcache_1,
    output logic [2 : 0]                  axi_arprot_1,
    output logic [3 : 0]                  axi_arqos_1,
    output logic [3 : 0]                  axi_arregion_1,
    output logic                          axi_aruser_1,
    input                                 axi_rvalid_1,
    output logic                          axi_rready_1,
    input        [AXI_DATA_WIDTH-1 : 0]   axi_rdata_1,
    input                                 axi_rlast_1,
    input        [1 : 0]                  axi_rresp_1,
    input        [AXI_ID_WIDTH-1 : 0]     axi_rid_1,
    input                                 axi_ruser_1,
	
    //AXI4 interface 2 (write channel)
    input                                 axi_awready_2,
    output logic                          axi_awvalid_2,
    output logic [AXI_ADDR_WIDTH-1 : 0]   axi_awaddr_2,
    output logic [AXI_LEN_WIDTH-1 : 0]    axi_awlen_2,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_awid_2,
    output logic [2 : 0]                  axi_awsize_2,
    output logic [1 : 0]                  axi_awburst_2,
    output logic                          axi_awlock_2,
    output logic [3 : 0]                  axi_awcache_2,
    output logic [2 : 0]                  axi_awprot_2,
    output logic [3 : 0]                  axi_awqos_2,
    output logic [3 : 0]                  axi_awregion_2,
    output logic                          axi_awuser_2,
    input                                 axi_wready_2,
    output logic                          axi_wvalid_2,
    output logic [AXI_DATA_WIDTH - 1 : 0] axi_wdata_2,
    output logic [AXI_STRB_WIDTH - 1 : 0] axi_wstrb_2,
    output logic                          axi_wlast_2,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_wid_2,
    output logic                          axi_wuser_2,
    output logic                          axi_bready_2,
    input                                 axi_bvalid_2,
    input        [1 : 0]                  axi_bresp_2,
    input        [AXI_ID_WIDTH-1 : 0]     axi_bid_2,
    input                                 axi_buser_2, 
    //AXI4 interface 2 (read channel)
    input                                 axi_arready_2,
    output logic                          axi_arvalid_2,
    output logic [AXI_ADDR_WIDTH-1 : 0]   axi_araddr_2,
    output logic [AXI_LEN_WIDTH-1 : 0]    axi_arlen_2,
    output logic [AXI_ID_WIDTH-1 : 0]     axi_arid_2,
    output logic [2 : 0]                  axi_arsize_2,
    output logic [1 : 0]                  axi_arburst_2,
    output logic                          axi_arlock_2,
    output logic [3 : 0]                  axi_arcache_2,
    output logic [2 : 0]                  axi_arprot_2,
    output logic [3 : 0]                  axi_arqos_2,
    output logic [3 : 0]                  axi_arregion_2,
    output logic                          axi_aruser_2,
    input                                 axi_rvalid_2,
    output logic                          axi_rready_2,
    input        [AXI_DATA_WIDTH-1 : 0]   axi_rdata_2,
    input                                 axi_rlast_2,
    input        [1 : 0]                  axi_rresp_2,
    input        [AXI_ID_WIDTH-1 : 0]     axi_rid_2,
    input                                 axi_ruser_2
);

localparam HLS_ARG_WIDTH    = 32;
localparam HLS_ARG_VECTOR   = 8;
localparam HLS_RET_WIDTH    = 32;
localparam HLS_RET_VECTOR   = 1;
localparam XMEM_ADDR_WIDTH  = 20;
localparam XMEM_DATA_WIDTH  = 32;
localparam DMA_ADDR_WIDTH  = 20;
localparam DMA_DATA_WIDTH  = 32;

//Riscv IO
logic                            rv_re    [2];
logic [ 3 : 0]                   rv_we    [2];
logic [31 : 0]                   rv_addr  [2];
logic [31 : 0]                   rv_wdata [2];
logic                            rv_ready [2];
logic                            rv_valid [2];
logic [31 : 0]                   rv_rdata [2];
//HLS ap_ctrl

logic                            ap_arb_start	[HLS_NUM];
logic                            ap_start 		[HLS_NUM];
logic [HLS_ARG_WIDTH - 1 : 0]    ap_arg   		[HLS_NUM][HLS_ARG_VECTOR];
logic                            ap_ready 		[HLS_NUM];
logic                            ap_idle  		[HLS_NUM];
logic                            ap_done  		[HLS_NUM];
logic [HLS_RET_WIDTH - 1 : 0]    ap_return		[HLS_NUM][HLS_RET_VECTOR];
//XMEM bus
logic                            xmem_rdy;
logic                            xmem_re;
logic                            xmem_re_r;
logic [                  3 : 0]  xmem_we;
logic [XMEM_ADDR_WIDTH - 1 : 0]  xmem_ad;
logic [XMEM_ADDR_WIDTH - 1 : 0]  xmem_ad_r;
logic [XMEM_DATA_WIDTH - 1 : 0]  xmem_di;
logic [XMEM_DATA_WIDTH - 1 : 0]  xmem_di_r;
logic [XMEM_DATA_WIDTH - 1 : 0]  xmem_do;
//DMA bus
logic                            dma_rdy;
logic                            dma_re;
logic                            dma_re_r;
logic                            dma_we;
logic [DMA_ADDR_WIDTH - 1 : 0]   dma_ad;
logic [DMA_ADDR_WIDTH - 1 : 0]   dma_ad_r;
logic [DMA_DATA_WIDTH - 1 : 0]   dma_di;
logic [DMA_DATA_WIDTH - 1 : 0]   dma_do;
//DecodeBin request fifo
logic [7 : 0]                    fifo[8];
logic [7 : 0]                    fifo_din;
logic [7 : 0]                    fifo_dout;
logic [2 : 0]                    fifo_tail;
logic [2 : 0]                    fifo_head;
logic [3 : 0]                    fifo_size;
logic                            fifo_empty;
logic                            fifo_push;
logic                            fifo_pop;


//-----------------------------------------------------------------------------------
//DMA 
//-----------------------------------------------------------------------------------
localparam RISC_DWIDTH 	= 32;
//localparam DMA_NUM      = 3; 
localparam DMA_NUM      = 4;
localparam L_DMA_NUM    = (DMA_NUM==1) ? 1 : $clog2(DMA_NUM);

localparam AXI_ARB_ID_WIDTH = $clog2(DMA_NUM) + 1;

//dma_axis_axi4
localparam DMA_AXIS_AXI4_AWIDTH  = AXI_ADDR_WIDTH;
localparam DMA_AXIS_AXI4_DWIDTH  = AXI_DATA_WIDTH;
localparam DMA_AXIS_AXI4_T_DW    = 8;//AXI_DATA_WIDTH;
localparam DMA_AXIS_AXI4_REGS_AW = 4;
localparam DMA_AXIS_AXI4_RAM_STYLE = "distributed";
localparam DMA_AXIS_AXI4_FIFO_DEPTH = 1024 / (DMA_AXIS_AXI4_DWIDTH / DMA_AXIS_AXI4_T_DW);

//--
//(* mark_debug = "true" *)
logic 										dma_finish		[DMA_NUM];
logic                               		dma_regs_we   	[DMA_NUM];
logic [DMA_AXIS_AXI4_REGS_AW-1 : 0] 		dma_regs_addr 	[DMA_NUM];
logic [DMA_DATA_WIDTH-1 : 0]           		dma_regs_wdata	[DMA_NUM];
logic                               		dma_regs_rdy  	[DMA_NUM];
logic [DMA_DATA_WIDTH-1 : 0]           		dma_regs_rdata	[DMA_NUM];


logic 										axis_src1_TVALID;
logic 										axis_src1_TREADY;
logic [7:0] 								axis_src1_TDATA;

logic 										axis_src2_TVALID;
logic 										axis_src2_TREADY;
logic [7:0]									axis_src2_TDATA;

logic 										axis_dst2_TVALID;
logic 										axis_dst2_TREADY;
logic [7:0] 								axis_dst2_TDATA;
logic 										axis_dst2_TSTRB;
logic 										axis_dst2_TKEEP;
logic 										axis_dst2_TLAST;
logic 										axis_dst2_TLAST_r;

logic 										axis_src3_TVALID;
logic 										axis_src3_TREADY;
logic [7:0]									axis_src3_TDATA;


//dual port bank in scalar range
logic 						scalar_argVld		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic 						scalar_argAck 		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [XMEM_AW-1:0]			scalar_adr			[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [SCALAR_BANK_DW-1:0]	scalar_wdat			[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [SCALAR_BANK_DW-1:0]	scalar_rdat			[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];


//single port bank in array range
logic 						array_argVld		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic 						array_argAck		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [XMEM_AW-1:0]			array_adr			[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [ARRAY_BANK_DW-1:0]	array_wdat			[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [ARRAY_BANK_DW-1:0]	array_rdat			[BANK_NUM[MEM_TYPE_ARRAY]];

//wide port bank in cyclic range
logic 						cyclic_argVld		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic 						cyclic_argAck		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [XMEM_AW-1:0]			cyclic_adr			[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [CYCLIC_BANK_DW-1:0]	cyclic_wdat			[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [CYCLIC_BANK_DW-1:0]	cyclic_rdat			[BANK_NUM[MEM_TYPE_CYCLIC]];



//-----------------------------------------------------------------------------------







//----------------------
// RISCV 0 (Main RISCV)
//----------------------
assign rv_re   [0] = rv0_re;
assign rv_we   [0] = rv0_we;
assign rv_addr [0] = rv0_addr;
assign rv_wdata[0] = rv0_wdata;
assign rv0_ready   = rv_ready[0];
assign rv0_valid   = rv_valid[0];
assign rv0_rdata   = rv_rdata[0];

//-----------------------
// RISCV 1 (Slave RISCV)
//-----------------------
assign rv_re   [1] = rv1_re;
assign rv_we   [1] = rv1_we;
assign rv_addr [1] = rv1_addr;
assign rv_wdata[1] = rv1_wdata;
assign rv1_ready   = rv_ready[1];
assign rv1_valid   = rv_valid[1];
assign rv1_rdata   = rv_rdata[1];


//-------------
// AP CTRL bus
//-------------
riscv_ap_ctrl_bus_v1
#(
    .RV_NUM          ( 2               ),
    .HLS_NUM         ( HLS_NUM         ),
    .HLS_ARG_WIDTH   ( HLS_ARG_WIDTH   ),
    .HLS_ARG_VECTOR  ( HLS_ARG_VECTOR  ),
    .HLS_RET_WIDTH   ( HLS_RET_WIDTH   ),
    .HLS_RET_VECTOR  ( HLS_RET_VECTOR  ),
    .XMEM_ADDR_WIDTH ( XMEM_ADDR_WIDTH ),
    .XMEM_DATA_WIDTH ( XMEM_DATA_WIDTH )
)
inst_ap_ctrl_bus (
    .clk       ( clk       		),
    .rstn      ( rstn      		),
    .rv_re     ( rv_re     		),
    .rv_we     ( rv_we     		),
    .rv_addr   ( rv_addr   		),
    .rv_wdata  ( rv_wdata  		),
    .rv_ready  ( rv_ready  		),
    .rv_valid  ( rv_valid  		),
    .rv_rdata  ( rv_rdata  		),
    .ap_start  ( ap_arb_start	),
    .ap_arg    ( ap_arg    		),
    .ap_ready  ( ap_ready  		),
    .ap_idle   ( ap_idle   		),
    .ap_done   ( ap_done   		),
    .ap_return ( ap_return 		),
    .xmem_rdy  ( xmem_rdy  		),
    .xmem_re   ( xmem_re   		),
    .xmem_we   ( xmem_we   		),
    .xmem_ad   ( xmem_ad   		),
    .xmem_di   ( xmem_di   		),
    .xmem_do   ( xmem_do   		),
    .dma_rdy   ( dma_rdy   		),
    .dma_re    ( dma_re    		),
    .dma_we    ( dma_we    		),
    .dma_ad    ( dma_ad    		),
    .dma_di    ( dma_di    		),
    .dma_do    ( dma_do    		)    
);

//-----------------------------------
// FIFO to buffer decode bin request
//-----------------------------------
always_ff @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        fifo       <= '{default:'0};
        fifo_tail  <= 0;
        fifo_head  <= 0;
        fifo_size  <= 0;
        fifo_empty <= 1;
    end
    else begin
        if (fifo_push) begin
            fifo_tail <= fifo_tail + 1;
            fifo[fifo_tail] <= fifo_din;
        end
        if (fifo_pop) begin
            fifo_head <= fifo_head + 1;
        end
        if (fifo_push & ~fifo_pop) begin
            fifo_size  <= fifo_size + 1;
            fifo_empty <= 0;
        end
        else if (~fifo_push & fifo_pop) begin
            fifo_size <= fifo_size - 1;
            if (fifo_size == 1)
                fifo_empty <= 1;
        end
    end
end
assign fifo_push = decBin_get & decBin_rdy;
assign fifo_pop  = decBin_vld & ~fifo_empty;
assign fifo_dout = fifo[fifo_head];

//------------
// RISCV XMEM
//------------
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        xmem_re_r <= 0;
        xmem_ad_r <= 0;
        xmem_di_r <= 0;
    end
    else begin
        xmem_re_r <= xmem_re;
        xmem_ad_r <= xmem_ad;
        if (xmem_we != 0)
            xmem_di_r <= xmem_di;
    end
end
//assign xmem_rdy = 1;

//--------------------------------------------------
// Macro convert riscv address to xmem memory
//--------------------------------------------------
//xmem_we is 4-bits write-enable.
//xmem_ad is byte-addrss.
`define riscv_xmem_we0(offset, sig_width)         ((xmem_we << ((xmem_ad - offset) % (sig_width / 8))) & {(sig_width/8){1'b1}})
`define riscv_xmem_address0(offset, sig_width)    ((xmem_ad - offset) / (sig_width / 8))
`define riscv_xmem_d0(offset, sig_width)          ((xmem_di << (((xmem_ad - offset) % (sig_width / 8)) * 8)) & {sig_width{1'b1}})
`define riscv_xmem_q0(q0, offset, sig_width)      (q0 >> (((xmem_ad_r - offset) % (sig_width / 8)) * 8))

//------------
// RISCV DMA
//------------
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        dma_re_r <= 0;
        dma_ad_r <= 0;
    end
    else begin
        dma_re_r <= dma_re;
        dma_ad_r <= dma_ad;
    end
end

//-----------------------------------
// HLS is always ready to write xmem
//-----------------------------------
assign hls_rdy0 = 1;

//--------------------------------
// Long tail function connections
//--------------------------------
//(* mark_debug = "true" *)
logic [31:0] chksum_src;    //so debug
//(* mark_debug = "true" *)
logic [31:0] chksum_src_cnt;    //so debug


//(* mark_debug = "true" *)
logic [31:0] chksum_dst;    //so debug
//(* mark_debug = "true" *)
logic [31:0] chksum_dst_cnt;    //so debug

//(* mark_debug = "true" *)
logic upd_chksum_src_cnt;    //so debug
//(* mark_debug = "true" *)
logic upd_chksum_dst_cnt;    //so debug

logic [31:0][7:0] axi_wdata_t;
//(* mark_debug = "true" *)
logic [31:0] chksum_axi_dst;
logic [31:0] chksum_axi_dst_r;

logic [7:0] tcnt;	//so debug
logic [7:0] tcnt_r;	//so debug

logic regs_rdy_o_1;
logic start_o_1;
logic stop_o_1;


//---------------------------------------
//HLS module
//---------------------------------------
`include "hls_long_tail_instantiate.vh"



//---------------------------------------
//Custom connection module
//---------------------------------------

custom_connection inst_custom_connection (
	.clk				( clk			),
	.rstn				( rstn			),
	//connected to hls function
	.ap_arb_start		( ap_arb_start	),
	.ap_start			( ap_start		),
	.ap_ready			( ap_ready		),
	.ap_idle			( ap_idle		),
	.ap_done			( ap_done		),
	//dual port bank in scalar range
	.scalar_argVld		( scalar_argVld	),
	.scalar_argAck		( scalar_argAck	),
	.scalar_adr			( scalar_adr	),
	.scalar_wdat		( scalar_wdat	),
	.scalar_rdat		( scalar_rdat	),
	//single port bank in array range
	.array_argVld		( array_argVld	),
	.array_argAck		( array_argAck	),
	.array_adr			( array_adr		),
	.array_wdat			( array_wdat	),
	.array_rdat			( array_rdat	),
	//wide port bank in cyclic range
	.cyclic_argVld		( cyclic_argVld	),
	.cyclic_argAck		( cyclic_argAck	),
	.cyclic_adr			( cyclic_adr	),
	.cyclic_wdat		( cyclic_wdat	),
	.cyclic_rdat		( cyclic_rdat	),




    //hls function connection 
	.fill_ref_samples_mtdma_top_wrp_numIntraNeighbor(fill_ref_samples_mtdma_top_wrp_numIntraNeighbor),
	.fill_ref_samples_mtdma_top_wrp_totalUnits(fill_ref_samples_mtdma_top_wrp_totalUnits),
	.fill_ref_samples_mtdma_top_wrp_aboveUnits(fill_ref_samples_mtdma_top_wrp_aboveUnits),
	.fill_ref_samples_mtdma_top_wrp_leftUnits(fill_ref_samples_mtdma_top_wrp_leftUnits),
	.fill_ref_samples_mtdma_top_wrp_unitWidth(fill_ref_samples_mtdma_top_wrp_unitWidth),
	.fill_ref_samples_mtdma_top_wrp_unitHeight(fill_ref_samples_mtdma_top_wrp_unitHeight),
	.fill_ref_samples_mtdma_top_wrp_log2TrSize(fill_ref_samples_mtdma_top_wrp_log2TrSize),
	.fill_ref_samples_mtdma_top_wrp_bNeighborFlags(fill_ref_samples_mtdma_top_wrp_bNeighborFlags),
	.fill_ref_samples_mtdma_top_wrp_topPixel_address0(fill_ref_samples_mtdma_top_wrp_topPixel_address0),
	.fill_ref_samples_mtdma_top_wrp_topPixel_ce0(fill_ref_samples_mtdma_top_wrp_topPixel_ce0),
	.fill_ref_samples_mtdma_top_wrp_topPixel_q0(fill_ref_samples_mtdma_top_wrp_topPixel_q0),
	.fill_ref_samples_mtdma_top_wrp_topPixel_we0(fill_ref_samples_mtdma_top_wrp_topPixel_we0),
	.fill_ref_samples_mtdma_top_wrp_topPixel_d0(fill_ref_samples_mtdma_top_wrp_topPixel_d0),
	.fill_ref_samples_mtdma_top_wrp_leftPixel_address0(fill_ref_samples_mtdma_top_wrp_leftPixel_address0),
	.fill_ref_samples_mtdma_top_wrp_leftPixel_ce0(fill_ref_samples_mtdma_top_wrp_leftPixel_ce0),
	.fill_ref_samples_mtdma_top_wrp_leftPixel_q0(fill_ref_samples_mtdma_top_wrp_leftPixel_q0),
	.fill_ref_samples_mtdma_top_wrp_leftPixel_we0(fill_ref_samples_mtdma_top_wrp_leftPixel_we0),
	.fill_ref_samples_mtdma_top_wrp_leftPixel_d0(fill_ref_samples_mtdma_top_wrp_leftPixel_d0),
	.fill_ref_samples_mtdma_top_wrp_adiLineBuffer_address0(fill_ref_samples_mtdma_top_wrp_adiLineBuffer_address0),
	.fill_ref_samples_mtdma_top_wrp_adiLineBuffer_ce0(fill_ref_samples_mtdma_top_wrp_adiLineBuffer_ce0),
	.fill_ref_samples_mtdma_top_wrp_adiLineBuffer_q0(fill_ref_samples_mtdma_top_wrp_adiLineBuffer_q0),
	.fill_ref_samples_mtdma_top_wrp_adiLineBuffer_we0(fill_ref_samples_mtdma_top_wrp_adiLineBuffer_we0),
	.fill_ref_samples_mtdma_top_wrp_adiLineBuffer_d0(fill_ref_samples_mtdma_top_wrp_adiLineBuffer_d0),
	.fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_address0(fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_address0),
	.fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_ce0(fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_ce0),
	.fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_q0(fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_q0),
	.fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_we0(fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_we0),
	.fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_d0(fill_ref_samples_mtdma_top_wrp_intraNeighbourBuf_d0),
	.hevc_find_frame_end_hls_state64_i(hevc_find_frame_end_hls_state64_i),
	.hevc_find_frame_end_hls_state64_o(hevc_find_frame_end_hls_state64_o),
	.hevc_find_frame_end_hls_state64_o_ap_vld(hevc_find_frame_end_hls_state64_o_ap_vld),
	.hevc_find_frame_end_hls_frame_start_found_i(hevc_find_frame_end_hls_frame_start_found_i),
	.hevc_find_frame_end_hls_frame_start_found_o(hevc_find_frame_end_hls_frame_start_found_o),
	.hevc_find_frame_end_hls_frame_start_found_o_ap_vld(hevc_find_frame_end_hls_frame_start_found_o_ap_vld),
	.ff_hevc_get_sub_cu_zscan_id_hls_log2_ctb_size(ff_hevc_get_sub_cu_zscan_id_hls_log2_ctb_size),
	.ff_hevc_get_sub_cu_zscan_id_hls_zscan_id(ff_hevc_get_sub_cu_zscan_id_hls_zscan_id),
	.ff_hevc_get_sub_cu_zscan_id_hls_zscan_id_ap_vld(ff_hevc_get_sub_cu_zscan_id_hls_zscan_id_ap_vld),
	.ff_hevc_set_neighbour_available_hls_cand_up(ff_hevc_set_neighbour_available_hls_cand_up),
	.ff_hevc_set_neighbour_available_hls_cand_up_ap_vld(ff_hevc_set_neighbour_available_hls_cand_up_ap_vld),
	.ff_hevc_set_neighbour_available_hls_cand_left(ff_hevc_set_neighbour_available_hls_cand_left),
	.ff_hevc_set_neighbour_available_hls_cand_left_ap_vld(ff_hevc_set_neighbour_available_hls_cand_left_ap_vld),
	.ff_hevc_set_neighbour_available_hls_cand_up_left(ff_hevc_set_neighbour_available_hls_cand_up_left),
	.ff_hevc_set_neighbour_available_hls_cand_up_left_ap_vld(ff_hevc_set_neighbour_available_hls_cand_up_left_ap_vld),
	.ff_hevc_set_neighbour_available_hls_cand_up_right_sap(ff_hevc_set_neighbour_available_hls_cand_up_right_sap),
	.ff_hevc_set_neighbour_available_hls_cand_up_right_sap_ap_vld(ff_hevc_set_neighbour_available_hls_cand_up_right_sap_ap_vld),
	.ff_hevc_set_neighbour_available_hls_cand_up_right(ff_hevc_set_neighbour_available_hls_cand_up_right),
	.ff_hevc_set_neighbour_available_hls_cand_up_right_ap_vld(ff_hevc_set_neighbour_available_hls_cand_up_right_ap_vld),
	.ff_hevc_set_neighbour_available_hls_cand_bottom_left(ff_hevc_set_neighbour_available_hls_cand_bottom_left),
	.ff_hevc_set_neighbour_available_hls_cand_bottom_left_ap_vld(ff_hevc_set_neighbour_available_hls_cand_bottom_left_ap_vld),
	.ff_hevc_set_neighbour_available_hls_log2_ctb_size(ff_hevc_set_neighbour_available_hls_log2_ctb_size),
	.ff_hevc_set_neighbour_available_hls_ctb_up_flag(ff_hevc_set_neighbour_available_hls_ctb_up_flag),
	.ff_hevc_set_neighbour_available_hls_ctb_left_flag(ff_hevc_set_neighbour_available_hls_ctb_left_flag),
	.ff_hevc_set_neighbour_available_hls_ctb_up_left_flag(ff_hevc_set_neighbour_available_hls_ctb_up_left_flag),
	.ff_hevc_set_neighbour_available_hls_ctb_up_right_flag(ff_hevc_set_neighbour_available_hls_ctb_up_right_flag),
	.ff_hevc_set_neighbour_available_hls_end_of_tiles_x(ff_hevc_set_neighbour_available_hls_end_of_tiles_x),
	.ff_hevc_set_neighbour_available_hls_end_of_tiles_y(ff_hevc_set_neighbour_available_hls_end_of_tiles_y),
	.ff_hevc_skip_flag_decode_hls_log2_ctb_size(ff_hevc_skip_flag_decode_hls_log2_ctb_size),
	.ff_hevc_skip_flag_decode_hls_ctb_left_flag(ff_hevc_skip_flag_decode_hls_ctb_left_flag),
	.ff_hevc_skip_flag_decode_hls_ctb_up_flag(ff_hevc_skip_flag_decode_hls_ctb_up_flag),
	.hls_transform_tree_hls1_tu_chroma_mode_c(hls_transform_tree_hls1_tu_chroma_mode_c),
	.hls_transform_tree_hls1_tu_chroma_mode_c_ap_vld(hls_transform_tree_hls1_tu_chroma_mode_c_ap_vld),
	.hls_transform_tree_hls1_tu_intra_pred_mode(hls_transform_tree_hls1_tu_intra_pred_mode),
	.hls_transform_tree_hls1_tu_intra_pred_mode_ap_vld(hls_transform_tree_hls1_tu_intra_pred_mode_ap_vld),
	.hls_transform_tree_hls1_tu_intra_pred_mode_c(hls_transform_tree_hls1_tu_intra_pred_mode_c),
	.hls_transform_tree_hls1_tu_intra_pred_mode_c_ap_vld(hls_transform_tree_hls1_tu_intra_pred_mode_c_ap_vld),
	
	.hls_transform_tree_hls1_pu_chroma_mode_c_0(hls_transform_tree_hls1_pu_chroma_mode_c_0),
	.hls_transform_tree_hls1_pu_chroma_mode_c_1(hls_transform_tree_hls1_pu_chroma_mode_c_1),
	.hls_transform_tree_hls1_pu_chroma_mode_c_2(hls_transform_tree_hls1_pu_chroma_mode_c_2),
	.hls_transform_tree_hls1_pu_chroma_mode_c_3(hls_transform_tree_hls1_pu_chroma_mode_c_3),

	.hls_transform_tree_hls1_pu_intra_pred_mode_0(hls_transform_tree_hls1_pu_intra_pred_mode_0),
	.hls_transform_tree_hls1_pu_intra_pred_mode_1(hls_transform_tree_hls1_pu_intra_pred_mode_1),
	.hls_transform_tree_hls1_pu_intra_pred_mode_2(hls_transform_tree_hls1_pu_intra_pred_mode_2),
	.hls_transform_tree_hls1_pu_intra_pred_mode_3(hls_transform_tree_hls1_pu_intra_pred_mode_3),
	
	.hls_transform_tree_hls1_pu_intra_pred_mode_c_0(hls_transform_tree_hls1_pu_intra_pred_mode_c_0),
	.hls_transform_tree_hls1_pu_intra_pred_mode_c_1(hls_transform_tree_hls1_pu_intra_pred_mode_c_1),
	.hls_transform_tree_hls1_pu_intra_pred_mode_c_2(hls_transform_tree_hls1_pu_intra_pred_mode_c_2),
	.hls_transform_tree_hls1_pu_intra_pred_mode_c_3(hls_transform_tree_hls1_pu_intra_pred_mode_c_3),
	
	.hls_transform_tree_hls1_log2_trafo_size(hls_transform_tree_hls1_log2_trafo_size),
	.hls_transform_tree_hls1_intra_split_flag(hls_transform_tree_hls1_intra_split_flag),
	.hls_transform_tree_hls1_log2_max_trafo_size(hls_transform_tree_hls1_log2_max_trafo_size),
	.hls_transform_tree_hls1_log2_min_tb_size(hls_transform_tree_hls1_log2_min_tb_size),
	.hls_transform_tree_hls1_max_trafo_depth(hls_transform_tree_hls1_max_trafo_depth),
	.hls_transform_tree_hls1_max_transform_hierarchy_depth_inter(hls_transform_tree_hls1_max_transform_hierarchy_depth_inter),
	.hls_transform_tree_hls1_pred_mode(hls_transform_tree_hls1_pred_mode),
	.hls_transform_tree_hls1_part_mode(hls_transform_tree_hls1_part_mode),
	.hls_transform_tree_hls1_chroma_array_type(hls_transform_tree_hls1_chroma_array_type),
	.hls_transform_tree_hls1_split_transform_flag(hls_transform_tree_hls1_split_transform_flag),
	.hls_transform_tree_hls1_split_transform_flag_ap_vld(hls_transform_tree_hls1_split_transform_flag_ap_vld),
	.hls_transform_tree_hls1_chroma_format_idc(hls_transform_tree_hls1_chroma_format_idc),
	.hls_transform_tree_hls1_cbf_data(hls_transform_tree_hls1_cbf_data),
	.hls_transform_tree_hls1_cbf_data_ap_vld(hls_transform_tree_hls1_cbf_data_ap_vld),
	.hls_transform_tree_hls3_pred_mode(hls_transform_tree_hls3_pred_mode),
	.hls_transform_tree_hls3_cbf_data(hls_transform_tree_hls3_cbf_data),
	.hls_transform_tree_hls3_chroma_format_idc(hls_transform_tree_hls3_chroma_format_idc),
	.hls_transform_tree_hls3_cbf_luma(hls_transform_tree_hls3_cbf_luma),
	.hls_transform_tree_hls3_cbf_luma_ap_vld(hls_transform_tree_hls3_cbf_luma_ap_vld),
	.access_cbf_read_min_tb_width(access_cbf_read_min_tb_width),
	.hls_transform_tree_hls4_cbf_luma(hls_transform_tree_hls4_cbf_luma),
	.hls_transform_tree_hls4_log2_trafo_size(hls_transform_tree_hls4_log2_trafo_size),
	.hls_transform_tree_hls4_log2_min_tb_size(hls_transform_tree_hls4_log2_min_tb_size),
	.hls_transform_tree_hls4_min_tb_width(hls_transform_tree_hls4_min_tb_width),
	.hls_transform_tree_hls4_log2_ctb_size(hls_transform_tree_hls4_log2_ctb_size),
	.hls_update_deblock_param_hls_log2_trafo_size(hls_update_deblock_param_hls_log2_trafo_size),
	.hls_update_deblock_param_hls_log2_min_tb_size(hls_update_deblock_param_hls_log2_min_tb_size),
	.hls_update_deblock_param_hls_min_tb_width(hls_update_deblock_param_hls_min_tb_width),
	.get_qPy_pred_hls_first_qp_group_i(get_qPy_pred_hls_first_qp_group_i),
	.get_qPy_pred_hls_first_qp_group_o(get_qPy_pred_hls_first_qp_group_o),
	.get_qPy_pred_hls_first_qp_group_o_ap_vld(get_qPy_pred_hls_first_qp_group_o_ap_vld),
	.get_qPy_pred_hls_qPy_pred(get_qPy_pred_hls_qPy_pred),
	.get_qPy_pred_hls_log2_ctb_size(get_qPy_pred_hls_log2_ctb_size),
	.get_qPy_pred_hls_diff_cu_qp_delta_depth(get_qPy_pred_hls_diff_cu_qp_delta_depth),
	.get_qPy_pred_hls_log2_min_cb_size(get_qPy_pred_hls_log2_min_cb_size),
	.get_qPy_pred_hls_min_cb_width(get_qPy_pred_hls_min_cb_width),
	.get_qPy_pred_hls_slice_qp(get_qPy_pred_hls_slice_qp),
	.coding_quadtree_1_hls_more_data(coding_quadtree_1_hls_more_data),
	.coding_quadtree_1_hls_more_data_ap_vld(coding_quadtree_1_hls_more_data),
	.coding_quadtree_1_hls_log2_min_cb_size(coding_quadtree_1_hls_log2_min_cb_size),
	.coding_quadtree_1_hls_min_cb_width(coding_quadtree_1_hls_min_cb_width),
	.coding_quadtree_1_hls_width(coding_quadtree_1_hls_width),
	.coding_quadtree_1_hls_height(coding_quadtree_1_hls_height),
	.coding_quadtree_1_hls_tu_is_cu_qp_delta_coded(coding_quadtree_1_hls_tu_is_cu_qp_delta_coded),
	.coding_quadtree_1_hls_tu_is_cu_qp_delta_coded_ap_vld(coding_quadtree_1_hls_tu_is_cu_qp_delta_coded_ap_vld),
	.coding_quadtree_1_hls_tu_cu_qp_delta(coding_quadtree_1_hls_tu_cu_qp_delta),
	.coding_quadtree_1_hls_tu_cu_qp_delta_ap_vld(coding_quadtree_1_hls_tu_cu_qp_delta_ap_vld),
	.coding_quadtree_1_hls_tu_is_cu_chroma_qp_offset_coded(coding_quadtree_1_hls_tu_is_cu_chroma_qp_offset_coded),
	.coding_quadtree_1_hls_tu_is_cu_chroma_qp_offset_coded_ap_vld(coding_quadtree_1_hls_tu_is_cu_chroma_qp_offset_coded_ap_vld),
	.coding_quadtree_1_hls_depth(coding_quadtree_1_hls_depth),
	.coding_quadtree_1_hls_depth_ap_vld(coding_quadtree_1_hls_depth_ap_vld),
	.coding_quadtree_1_hls_split_cu_flag(coding_quadtree_1_hls_split_cu_flag),
	.coding_quadtree_1_hls_split_cu_flag_ap_vld(coding_quadtree_1_hls_split_cu_flag_ap_vld),
	.coding_quadtree_1_hls_cb_size_split(coding_quadtree_1_hls_cb_size_split),
	.coding_quadtree_1_hls_cb_size_split_ap_vld(coding_quadtree_1_hls_cb_size_split_ap_vld),
	.coding_quadtree_1_hls_x1(coding_quadtree_1_hls_x1),
	.coding_quadtree_1_hls_x1_ap_vld(coding_quadtree_1_hls_x1_ap_vld),
	.coding_quadtree_1_hls_y1(coding_quadtree_1_hls_y1),
	.coding_quadtree_1_hls_y1_ap_vld(coding_quadtree_1_hls_y1_ap_vld),
	.coding_quadtree_1_hls_log2_cb_size_minus_one(coding_quadtree_1_hls_log2_cb_size_minus_one),
	.coding_quadtree_1_hls_log2_cb_size_minus_one_ap_vld(coding_quadtree_1_hls_log2_cb_size_minus_one_ap_vld),
	.coding_quadtree_1_hls_cb_depth_plus_one(coding_quadtree_1_hls_cb_depth_plus_one),
	.coding_quadtree_1_hls_cb_depth_plus_one_ap_vld(coding_quadtree_1_hls_cb_depth_plus_one_ap_vld),
	.coding_quadtree_1_hls_qp_block_mask(coding_quadtree_1_hls_qp_block_mask),
	.coding_quadtree_1_hls_qp_block_mask_ap_vld(coding_quadtree_1_hls_qp_block_mask_ap_vld),
	.coding_quadtree_1_hls_log2_ctb_size(coding_quadtree_1_hls_log2_ctb_size),
	.coding_quadtree_1_hls_ctb_left_flag(coding_quadtree_1_hls_ctb_left_flag),
	.coding_quadtree_1_hls_ctb_up_flag(coding_quadtree_1_hls_ctb_up_flag),
	.coding_quadtree_1_hls_cu_qp_delta_enabled_flag(coding_quadtree_1_hls_cu_qp_delta_enabled_flag),
	.coding_quadtree_1_hls_diff_cu_qp_delta_depth(coding_quadtree_1_hls_diff_cu_qp_delta_depth),
	.coding_quadtree_1_hls_cu_chroma_qp_offset_enabled_flag(coding_quadtree_1_hls_cu_chroma_qp_offset_enabled_flag),
	.coding_quadtree_1_hls_diff_cu_chroma_qp_offset_depth(coding_quadtree_1_hls_diff_cu_chroma_qp_offset_depth),
	.coding_quadtree_3_hls_more_data(coding_quadtree_3_hls_more_data),
	.coding_quadtree_3_hls_more_data_ap_vld(coding_quadtree_3_hls_more_data_ap_vld),
	.coding_quadtree_3_hls_qPy_pred(coding_quadtree_3_hls_qPy_pred),
	.coding_quadtree_3_hls_qPy_pred_ap_vld(coding_quadtree_3_hls_qPy_pred_ap_vld),
	.coding_quadtree_3_hls_qp_y(coding_quadtree_3_hls_qp_y),
	.coding_quadtree_3_hls_width(coding_quadtree_3_hls_width),
	.coding_quadtree_3_hls_height(coding_quadtree_3_hls_height),
	.coding_quadtree_3_hls_qp_block_mask(coding_quadtree_3_hls_qp_block_mask),
	.coding_quadtree_3_hls_x1(coding_quadtree_3_hls_x1),
	.coding_quadtree_3_hls_y1(coding_quadtree_3_hls_y1),
	.coding_quadtree_3_hls_cb_size_split(coding_quadtree_3_hls_cb_size_split),
	.coding_quadtree_4_hls_more_data(coding_quadtree_4_hls_more_data),
	.coding_quadtree_4_hls_more_data_ap_vld(coding_quadtree_4_hls_more_data_ap_vld),
	.coding_quadtree_4_hls_log2_ctb_size(coding_quadtree_4_hls_log2_ctb_size),
	.coding_quadtree_4_hls_width(coding_quadtree_4_hls_width),
	.coding_quadtree_4_hls_height(coding_quadtree_4_hls_height),
	.hls_transform_unit_hls_scan_idx(hls_transform_unit_hls_scan_idx),
	.hls_transform_unit_hls_scan_idx_ap_vld(hls_transform_unit_hls_scan_idx_ap_vld),
	.hls_transform_unit_hls_scan_idx_c(hls_transform_unit_hls_scan_idx_c),
	.hls_transform_unit_hls_scan_idx_c_ap_vld(hls_transform_unit_hls_scan_idx_c_ap_vld),
	.hls_transform_unit_hls_log2_trafo_size_c(hls_transform_unit_hls_log2_trafo_size_c),
	.hls_transform_unit_hls_log2_trafo_size_c_ap_vld(hls_transform_unit_hls_log2_trafo_size_c_ap_vld),
	.hls_transform_unit_hls_pred_mode(hls_transform_unit_hls_pred_mode),
	.hls_transform_unit_hls_log2_trafo_size(hls_transform_unit_hls_log2_trafo_size),
	.hls_transform_unit_hls_tu_intra_pred_mode(hls_transform_unit_hls_tu_intra_pred_mode),
	.hls_transform_unit_hls_tu_intra_pred_mode_c(hls_transform_unit_hls_tu_intra_pred_mode_c),
	.hls_coding_unit_sub_hls_cb_size(hls_coding_unit_sub_hls_cb_size),
	.hls_coding_unit_sub_hls_cb_size_ap_vld(hls_coding_unit_sub_hls_cb_size_ap_vld),
	.hls_coding_unit_sub_hls_length_r(hls_coding_unit_sub_hls_length_r),
	.hls_coding_unit_sub_hls_length_r_ap_vld(hls_coding_unit_sub_hls_length_r_ap_vld),
	.hls_coding_unit_sub_hls_idx(hls_coding_unit_sub_hls_idx),
	.hls_coding_unit_sub_hls_idx_ap_vld(hls_coding_unit_sub_hls_idx_ap_vld),
	.hls_coding_unit_sub_hls_x(hls_coding_unit_sub_hls_x),
	.hls_coding_unit_sub_hls_x_ap_vld(hls_coding_unit_sub_hls_x_ap_vld),
	.hls_coding_unit_sub_hls_y(hls_coding_unit_sub_hls_y),
	.hls_coding_unit_sub_hls_y_ap_vld(hls_coding_unit_sub_hls_y_ap_vld),
	.hls_coding_unit_sub_hls_pu_intra_pred_mode_0(hls_coding_unit_sub_hls_pu_intra_pred_mode_0),
	.hls_coding_unit_sub_hls_pu_intra_pred_mode_0_ap_vld(hls_coding_unit_sub_hls_pu_intra_pred_mode_0_ap_vld),
	.hls_coding_unit_sub_hls_pu_intra_pred_mode_1(hls_coding_unit_sub_hls_pu_intra_pred_mode_1),
	.hls_coding_unit_sub_hls_pu_intra_pred_mode_1_ap_vld(hls_coding_unit_sub_hls_pu_intra_pred_mode_1_ap_vld),
	.hls_coding_unit_sub_hls_pu_intra_pred_mode_2(hls_coding_unit_sub_hls_pu_intra_pred_mode_2),
	.hls_coding_unit_sub_hls_pu_intra_pred_mode_2_ap_vld(hls_coding_unit_sub_hls_pu_intra_pred_mode_2_ap_vld),
	.hls_coding_unit_sub_hls_pu_intra_pred_mode_3(hls_coding_unit_sub_hls_pu_intra_pred_mode_3),
	.hls_coding_unit_sub_hls_pu_intra_pred_mode_3_ap_vld(hls_coding_unit_sub_hls_pu_intra_pred_mode_3_ap_vld),
	.hls_coding_unit_sub_hls_qPy_pred(hls_coding_unit_sub_hls_qPy_pred),
	.hls_coding_unit_sub_hls_qPy_pred_ap_vld(hls_coding_unit_sub_hls_qPy_pred_ap_vld),
	.hls_coding_unit_sub_hls_cu_transquant_bypass_flag(hls_coding_unit_sub_hls_cu_transquant_bypass_flag),
	.hls_coding_unit_sub_hls_cu_transquant_bypass_flag_ap_vld(hls_coding_unit_sub_hls_cu_transquant_bypass_flag_ap_vld),
	.hls_coding_unit_sub_hls_skip_flag_start(hls_coding_unit_sub_hls_skip_flag_start),
	.hls_coding_unit_sub_hls_skip_flag_start_ap_vld(hls_coding_unit_sub_hls_skip_flag_start_ap_vld),
	.hls_coding_unit_sub_hls_log2_min_cb_size(hls_coding_unit_sub_hls_log2_min_cb_size),
	.hls_coding_unit_sub_hls_log2_ctb_size(hls_coding_unit_sub_hls_log2_ctb_size),
	.hls_coding_unit_sub_hls_diff_cu_qp_delta_depth(hls_coding_unit_sub_hls_diff_cu_qp_delta_depth),
	.hls_coding_unit_sub_hls_qp_y(hls_coding_unit_sub_hls_qp_y),
	.hls_coding_unit_sub_hls_transquant_bypass_enable_flag(hls_coding_unit_sub_hls_transquant_bypass_enable_flag),
	.hls_coding_unit_sub_hls_min_cb_width(hls_coding_unit_sub_hls_min_cb_width),
	.hls_coding_unit_sub_hls_pred_mode(hls_coding_unit_sub_hls_pred_mode),
	.hls_coding_unit_sub_hls_pred_mode_ap_vld(hls_coding_unit_sub_hls_pred_mode_ap_vld),
	.hls_coding_unit_sub_hls_part_mode(hls_coding_unit_sub_hls_part_mode),
	.hls_coding_unit_sub_hls_part_mode_ap_vld(hls_coding_unit_sub_hls_part_mode_ap_vld),
	.hls_coding_unit_sub_hls_intra_split_flag(hls_coding_unit_sub_hls_intra_split_flag),
	.hls_coding_unit_sub_hls_intra_split_flag_ap_vld(hls_coding_unit_sub_hls_intra_split_flag_ap_vld),
	.hls_coding_unit_sub_hls_pcm_flag(hls_coding_unit_sub_hls_pcm_flag),
	.hls_coding_unit_sub_hls_pcm_flag_ap_vld(hls_coding_unit_sub_hls_pcm_flag_ap_vld),
	.hls_coding_unit_sub_hls_slice_type(hls_coding_unit_sub_hls_slice_type),
	.hls_coding_unit_sub_hls_ctb_left_flag(hls_coding_unit_sub_hls_ctb_left_flag),
	.hls_coding_unit_sub_hls_ctb_up_flag(hls_coding_unit_sub_hls_ctb_up_flag),
	.hls_coding_unit_sub_hls_amp_enabled_flag(hls_coding_unit_sub_hls_amp_enabled_flag),
	.hls_coding_unit_sub_hls_pcm_enabled_flag(hls_coding_unit_sub_hls_pcm_enabled_flag),
	.hls_coding_unit_sub_hls_log2_min_pcm_cb_size(hls_coding_unit_sub_hls_log2_min_pcm_cb_size),
	.hls_coding_unit_sub_hls_log2_max_pcm_cb_size(hls_coding_unit_sub_hls_log2_max_pcm_cb_size),
	.ff_hevc_deblocking_boundary_strengths_hls1_slice_or_tiles_up_boundary(ff_hevc_deblocking_boundary_strengths_hls1_slice_or_tiles_up_boundary),
	.ff_hevc_deblocking_boundary_strengths_hls1_log2_min_pu_size(ff_hevc_deblocking_boundary_strengths_hls1_log2_min_pu_size),
	.ff_hevc_deblocking_boundary_strengths_hls1_cord_p_pu(ff_hevc_deblocking_boundary_strengths_hls1_cord_p_pu),
	.ff_hevc_deblocking_boundary_strengths_hls1_cord_p_pu_ap_vld(ff_hevc_deblocking_boundary_strengths_hls1_cord_p_pu_ap_vld),
	.ff_hevc_deblocking_boundary_strengths_hls1_cord_q_pu(ff_hevc_deblocking_boundary_strengths_hls1_cord_q_pu),
	.ff_hevc_deblocking_boundary_strengths_hls1_cord_q_pu_ap_vld(ff_hevc_deblocking_boundary_strengths_hls1_cord_q_pu_ap_vld),
	.ff_hevc_deblocking_boundary_strengths_hls2_bs(ff_hevc_deblocking_boundary_strengths_hls2_bs),
	.ff_hevc_deblocking_boundary_strengths_hls2_bs_ap_vld(ff_hevc_deblocking_boundary_strengths_hls2_bs_ap_vld),
	.ff_hevc_deblocking_boundary_strengths_hls2_cord_tu_xmem(ff_hevc_deblocking_boundary_strengths_hls2_cord_tu_xmem),
	.ff_hevc_deblocking_boundary_strengths_hls2_cord_tu_xmem_ap_vld(ff_hevc_deblocking_boundary_strengths_hls2_cord_tu_xmem_ap_vld),
	.ff_hevc_deblocking_boundary_strengths_hls2_cord_q_tu_xmem(ff_hevc_deblocking_boundary_strengths_hls2_cord_q_tu_xmem),
	.ff_hevc_deblocking_boundary_strengths_hls2_cord_q_tu_xmem_ap_vld(ff_hevc_deblocking_boundary_strengths_hls2_cord_q_tu_xmem_ap_vld),
	.ff_hevc_deblocking_boundary_strengths_hls2_cord_p_tu_xmem(ff_hevc_deblocking_boundary_strengths_hls2_cord_p_tu_xmem),
	.ff_hevc_deblocking_boundary_strengths_hls2_cord_p_tu_xmem_ap_vld(ff_hevc_deblocking_boundary_strengths_hls2_cord_p_tu_xmem_ap_vld),
	.hls_prepare_deblock_param_hls_min_tb_width(hls_prepare_deblock_param_hls_min_tb_width),
	.hls_prepare_deblock_param_hls_log2_trafo_size(hls_prepare_deblock_param_hls_log2_trafo_size),
	.hls_prepare_deblock_param_hls_log2_min_tb_size(hls_prepare_deblock_param_hls_log2_min_tb_size),
	.hls_decode_neighbour_hls_first_qp_group(hls_decode_neighbour_hls_first_qp_group),
	.hls_decode_neighbour_hls_first_qp_group_ap_vld(hls_decode_neighbour_hls_first_qp_group_ap_vld),
	.hls_decode_neighbour_hls_end_of_tiles_x(hls_decode_neighbour_hls_end_of_tiles_x),
	.hls_decode_neighbour_hls_end_of_tiles_x_ap_vld(hls_decode_neighbour_hls_end_of_tiles_x_ap_vld),
	.hls_decode_neighbour_hls_end_of_tiles_y(hls_decode_neighbour_hls_end_of_tiles_y),
	.hls_decode_neighbour_hls_end_of_tiles_y_ap_vld(hls_decode_neighbour_hls_end_of_tiles_y_ap_vld),
	.hls_decode_neighbour_hls_slice_or_tiles_left_boundary(hls_decode_neighbour_hls_slice_or_tiles_left_boundary),
	.hls_decode_neighbour_hls_slice_or_tiles_left_boundary_ap_vld(hls_decode_neighbour_hls_slice_or_tiles_left_boundary_ap_vld),
	.hls_decode_neighbour_hls_slice_or_tiles_up_boundary(hls_decode_neighbour_hls_slice_or_tiles_up_boundary),
	.hls_decode_neighbour_hls_slice_or_tiles_up_boundary_ap_vld(hls_decode_neighbour_hls_slice_or_tiles_up_boundary_ap_vld),
	.hls_decode_neighbour_hls_ctb_left_flag(hls_decode_neighbour_hls_ctb_left_flag),
	.hls_decode_neighbour_hls_ctb_left_flag_ap_vld(hls_decode_neighbour_hls_ctb_left_flag_ap_vld),
	.hls_decode_neighbour_hls_ctb_up_flag(hls_decode_neighbour_hls_ctb_up_flag),
	.hls_decode_neighbour_hls_ctb_up_flag_ap_vld(hls_decode_neighbour_hls_ctb_up_flag_ap_vld),
	.hls_decode_neighbour_hls_ctb_up_right_flag(hls_decode_neighbour_hls_ctb_up_right_flag),
	.hls_decode_neighbour_hls_ctb_up_right_flag_ap_vld(hls_decode_neighbour_hls_ctb_up_right_flag_ap_vld),
	.hls_decode_neighbour_hls_ctb_up_left_flag(hls_decode_neighbour_hls_ctb_up_left_flag),
	.hls_decode_neighbour_hls_ctb_up_left_flag_ap_vld(hls_decode_neighbour_hls_ctb_up_left_flag_ap_vld),
	.hls_decode_neighbour_hls_x_ctb(hls_decode_neighbour_hls_x_ctb),
	.hls_decode_neighbour_hls_y_ctb(hls_decode_neighbour_hls_y_ctb),
	.hls_decode_neighbour_hls_ctb_addr_ts(hls_decode_neighbour_hls_ctb_addr_ts),
	.hls_decode_neighbour_hls_log2_ctb_size(hls_decode_neighbour_hls_log2_ctb_size),
	.hls_decode_neighbour_hls_ctb_width(hls_decode_neighbour_hls_ctb_width),
	.hls_decode_neighbour_hls_slice_addr(hls_decode_neighbour_hls_slice_addr),
	.hls_decode_neighbour_hls_entropy_coding_sync_enabled_flag(hls_decode_neighbour_hls_entropy_coding_sync_enabled_flag),
	.hls_decode_neighbour_hls_tiles_enabled_flag(hls_decode_neighbour_hls_tiles_enabled_flag),
	.hls_decode_neighbour_hls_num_tile_columns(hls_decode_neighbour_hls_num_tile_columns),
	.hls_decode_neighbour_hls_column_width_address0(hls_decode_neighbour_hls_column_width_address0),
	.hls_decode_neighbour_hls_column_width_ce0(hls_decode_neighbour_hls_column_width_ce0),
	.hls_decode_neighbour_hls_column_width_q0(hls_decode_neighbour_hls_column_width_q0),
	.hls_decode_neighbour_hls_width(hls_decode_neighbour_hls_width),
	.hls_decode_neighbour_hls_height(hls_decode_neighbour_hls_height),
	.intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_0(intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_0),
	.intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_0_ap_vld(intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_0_ap_vld),
	.intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_1(intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_1),
	.intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_1_ap_vld(intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_1_ap_vld),
	.intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_2(intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_2),
	.intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_2_ap_vld(intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_2_ap_vld),
	.intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_3(intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_3),
	.intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_3_ap_vld(intra_prediction_unit_1_hls_prev_intra_luma_pred_flag_3_ap_vld),
	.intra_prediction_unit_1_hls_part_mode(intra_prediction_unit_1_hls_part_mode),
	.intra_prediction_unit_1_hls_pb_size(intra_prediction_unit_1_hls_pb_size),
	.intra_prediction_unit_1_hls_pb_size_ap_vld(intra_prediction_unit_1_hls_pb_size_ap_vld),
	.intra_prediction_unit_1_hls_side(intra_prediction_unit_1_hls_side),
	.intra_prediction_unit_1_hls_side_ap_vld(intra_prediction_unit_1_hls_side_ap_vld),
	
	
	.intra_prediction_unit_2_hls_prev_intra_luma_pred_flag_0(intra_prediction_unit_2_hls_prev_intra_luma_pred_flag_0),
	.intra_prediction_unit_2_hls_prev_intra_luma_pred_flag_1(intra_prediction_unit_2_hls_prev_intra_luma_pred_flag_1),
	.intra_prediction_unit_2_hls_prev_intra_luma_pred_flag_2(intra_prediction_unit_2_hls_prev_intra_luma_pred_flag_2),
	.intra_prediction_unit_2_hls_prev_intra_luma_pred_flag_3(intra_prediction_unit_2_hls_prev_intra_luma_pred_flag_3),
	
	
	.intra_prediction_unit_2_hls_log2_min_pu_size(intra_prediction_unit_2_hls_log2_min_pu_size),
	.intra_prediction_unit_2_hls_log2_ctb_size(intra_prediction_unit_2_hls_log2_ctb_size),
	.intra_prediction_unit_2_hls_cand_up_flag(intra_prediction_unit_2_hls_cand_up_flag),
	.intra_prediction_unit_2_hls_cand_up_flag_ap_vld(intra_prediction_unit_2_hls_cand_up_flag_ap_vld),
	.intra_prediction_unit_2_hls_cand_left_flag(intra_prediction_unit_2_hls_cand_left_flag),
	.intra_prediction_unit_2_hls_cand_left_flag_ap_vld(intra_prediction_unit_2_hls_cand_left_flag_ap_vld),
	.intra_prediction_unit_2_hls_ctb_up_flag(intra_prediction_unit_2_hls_ctb_up_flag),
	.intra_prediction_unit_2_hls_ctb_left_flag(intra_prediction_unit_2_hls_ctb_left_flag),
	.intra_prediction_unit_2_hls_pb_size(intra_prediction_unit_2_hls_pb_size),
	.intra_prediction_unit_2_hls_log2_rounded_min_pu_width(intra_prediction_unit_2_hls_log2_rounded_min_pu_width),
	
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_0(intra_prediction_unit_2_hls_pu_intra_pred_mode_0),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_1(intra_prediction_unit_2_hls_pu_intra_pred_mode_1),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_2(intra_prediction_unit_2_hls_pu_intra_pred_mode_2),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_3(intra_prediction_unit_2_hls_pu_intra_pred_mode_3),
	
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_0_o(intra_prediction_unit_2_hls_pu_intra_pred_mode_0_o),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_0_o_ap_vld(intra_prediction_unit_2_hls_pu_intra_pred_mode_0_o_ap_vld),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_1_o(intra_prediction_unit_2_hls_pu_intra_pred_mode_1_o),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_1_o_ap_vld(intra_prediction_unit_2_hls_pu_intra_pred_mode_1_o_ap_vld),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_2_o(intra_prediction_unit_2_hls_pu_intra_pred_mode_2_o),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_2_o_ap_vld(intra_prediction_unit_2_hls_pu_intra_pred_mode_2_o_ap_vld),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_3_o(intra_prediction_unit_2_hls_pu_intra_pred_mode_3_o),
	.intra_prediction_unit_2_hls_pu_intra_pred_mode_3_o_ap_vld(intra_prediction_unit_2_hls_pu_intra_pred_mode_3_o_ap_vld),
	.intra_prediction_unit_2_hls_side(intra_prediction_unit_2_hls_side),
	.intra_prediction_unit_2_hls_tab_ipm_start_address0(intra_prediction_unit_2_hls_tab_ipm_start_address0),
	.intra_prediction_unit_2_hls_tab_ipm_start_ce0(intra_prediction_unit_2_hls_tab_ipm_start_ce0),
	.intra_prediction_unit_2_hls_tab_ipm_start_we0(intra_prediction_unit_2_hls_tab_ipm_start_we0),
	.intra_prediction_unit_2_hls_tab_ipm_start_d0(intra_prediction_unit_2_hls_tab_ipm_start_d0),
	.intra_prediction_unit_2_hls_size_in_pus(intra_prediction_unit_2_hls_size_in_pus),
	.intra_prediction_unit_2_hls_size_in_pus_ap_vld(intra_prediction_unit_2_hls_size_in_pus_ap_vld),
	.intra_prediction_unit_3_hls_side(intra_prediction_unit_3_hls_side),
	.intra_prediction_unit_3_hls_chroma_array_type(intra_prediction_unit_3_hls_chroma_array_type),
	.intra_prediction_unit_3_hls_pu_chroma_mode_c_0(intra_prediction_unit_3_hls_pu_chroma_mode_c_0),
	.intra_prediction_unit_3_hls_pu_chroma_mode_c_0_ap_vld(intra_prediction_unit_3_hls_pu_chroma_mode_c_0_ap_vld),
	.intra_prediction_unit_3_hls_pu_chroma_mode_c_1(intra_prediction_unit_3_hls_pu_chroma_mode_c_1),
	.intra_prediction_unit_3_hls_pu_chroma_mode_c_1_ap_vld(intra_prediction_unit_3_hls_pu_chroma_mode_c_1_ap_vld),
	.intra_prediction_unit_3_hls_pu_chroma_mode_c_2(intra_prediction_unit_3_hls_pu_chroma_mode_c_2),
	.intra_prediction_unit_3_hls_pu_chroma_mode_c_2_ap_vld(intra_prediction_unit_3_hls_pu_chroma_mode_c_2_ap_vld),
	.intra_prediction_unit_3_hls_pu_chroma_mode_c_3(intra_prediction_unit_3_hls_pu_chroma_mode_c_3),
	.intra_prediction_unit_3_hls_pu_chroma_mode_c_3_ap_vld(intra_prediction_unit_3_hls_pu_chroma_mode_c_3_ap_vld),
	
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_0(intra_prediction_unit_3_hls_pu_intra_pred_mode_0),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_1(intra_prediction_unit_3_hls_pu_intra_pred_mode_1),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_2(intra_prediction_unit_3_hls_pu_intra_pred_mode_2),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_3(intra_prediction_unit_3_hls_pu_intra_pred_mode_3),
	
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_c_0(intra_prediction_unit_3_hls_pu_intra_pred_mode_c_0),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_c_0_ap_vld(intra_prediction_unit_3_hls_pu_intra_pred_mode_c_0_ap_vld),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_c_1(intra_prediction_unit_3_hls_pu_intra_pred_mode_c_1),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_c_1_ap_vld(intra_prediction_unit_3_hls_pu_intra_pred_mode_c_1_ap_vld),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_c_2(intra_prediction_unit_3_hls_pu_intra_pred_mode_c_2),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_c_2_ap_vld(intra_prediction_unit_3_hls_pu_intra_pred_mode_c_2_ap_vld),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_c_3(intra_prediction_unit_3_hls_pu_intra_pred_mode_c_3),
	.intra_prediction_unit_3_hls_pu_intra_pred_mode_c_3_ap_vld(intra_prediction_unit_3_hls_pu_intra_pred_mode_c_3_ap_vld),
	.intra_prediction_unit_3_hls_max_trafo_depth(intra_prediction_unit_3_hls_max_trafo_depth),
	.intra_prediction_unit_3_hls_max_trafo_depth_ap_vld(intra_prediction_unit_3_hls_max_trafo_depth_ap_vld),
	.intra_prediction_unit_3_hls_max_transform_hierarchy_depth_intra(intra_prediction_unit_3_hls_max_transform_hierarchy_depth_intra),
	.intra_prediction_unit_3_hls_intra_split_flag(intra_prediction_unit_3_hls_intra_split_flag),
	.calculate_transposed_value_hls_log2_rounded_min_pu_width(calculate_transposed_value_hls_log2_rounded_min_pu_width),
	.calculate_transposed_value_hls_log2_rounded_min_pu_height(calculate_transposed_value_hls_log2_rounded_min_pu_height),
	.calculate_transposed_value_hls_log2_min_pu_size(calculate_transposed_value_hls_log2_min_pu_size),
	.calculate_transposed_value_hls_Transpose_tab_mvf_pred_flag_CTU_address0(calculate_transposed_value_hls_Transpose_tab_mvf_pred_flag_CTU_address0),
	.calculate_transposed_value_hls_Transpose_tab_mvf_pred_flag_CTU_ce0(calculate_transposed_value_hls_Transpose_tab_mvf_pred_flag_CTU_ce0),
	.calculate_transposed_value_hls_Transpose_tab_mvf_pred_flag_CTU_we0(calculate_transposed_value_hls_Transpose_tab_mvf_pred_flag_CTU_we0),
	.calculate_transposed_value_hls_Transpose_tab_mvf_pred_flag_CTU_d0(calculate_transposed_value_hls_Transpose_tab_mvf_pred_flag_CTU_d0),
	.init_intra_neighbors_hls_hshift_address0(init_intra_neighbors_hls_hshift_address0),
	.init_intra_neighbors_hls_hshift_ce0(init_intra_neighbors_hls_hshift_ce0),
	.init_intra_neighbors_hls_hshift_q0(init_intra_neighbors_hls_hshift_q0),
	.init_intra_neighbors_hls_vshift_address0(init_intra_neighbors_hls_vshift_address0),
	.init_intra_neighbors_hls_vshift_ce0(init_intra_neighbors_hls_vshift_ce0),
	.init_intra_neighbors_hls_vshift_q0(init_intra_neighbors_hls_vshift_q0),
	.init_intra_neighbors_hls_log2_min_pu_size(init_intra_neighbors_hls_log2_min_pu_size),
	.init_intra_neighbors_hls_log2_min_tb_size(init_intra_neighbors_hls_log2_min_tb_size),
	.init_intra_neighbors_hls_log2_ctb_size(init_intra_neighbors_hls_log2_ctb_size),
	.init_intra_neighbors_hls_log2_rounded_min_pu_width(init_intra_neighbors_hls_log2_rounded_min_pu_width),
	.init_intra_neighbors_hls_log2_rounded_min_pu_height(init_intra_neighbors_hls_log2_rounded_min_pu_height),
	.init_intra_neighbors_hls_tb_mask(init_intra_neighbors_hls_tb_mask),
	.init_intra_neighbors_hls_width(init_intra_neighbors_hls_width),
	.init_intra_neighbors_hls_height(init_intra_neighbors_hls_height),
	.init_intra_neighbors_hls_constrained_intra_pred_flag(init_intra_neighbors_hls_constrained_intra_pred_flag),
	.init_intra_neighbors_hls_cand_bottom_left(init_intra_neighbors_hls_cand_bottom_left),
	.init_intra_neighbors_hls_cand_left(init_intra_neighbors_hls_cand_left),
	.init_intra_neighbors_hls_cand_up_left(init_intra_neighbors_hls_cand_up_left),
	.init_intra_neighbors_hls_cand_up(init_intra_neighbors_hls_cand_up),
	.init_intra_neighbors_hls_cand_up_right(init_intra_neighbors_hls_cand_up_right),
	.init_intra_neighbors_hls_numIntraNeighbor(init_intra_neighbors_hls_numIntraNeighbor),
	.init_intra_neighbors_hls_numIntraNeighbor_ap_vld(init_intra_neighbors_hls_numIntraNeighbor_ap_vld),
	.init_intra_neighbors_hls_totalUnits(init_intra_neighbors_hls_totalUnits),
	.init_intra_neighbors_hls_totalUnits_ap_vld(init_intra_neighbors_hls_totalUnits_ap_vld),
	.init_intra_neighbors_hls_aboveUnits(init_intra_neighbors_hls_aboveUnits),
	.init_intra_neighbors_hls_aboveUnits_ap_vld(init_intra_neighbors_hls_aboveUnits_ap_vld),
	.init_intra_neighbors_hls_leftUnits(init_intra_neighbors_hls_leftUnits),
	.init_intra_neighbors_hls_leftUnits_ap_vld(init_intra_neighbors_hls_leftUnits_ap_vld),
	.init_intra_neighbors_hls_unitWidth(init_intra_neighbors_hls_unitWidth),
	.init_intra_neighbors_hls_unitWidth_ap_vld(init_intra_neighbors_hls_unitWidth_ap_vld),
	.init_intra_neighbors_hls_unitHeight(init_intra_neighbors_hls_unitHeight),
	.init_intra_neighbors_hls_unitHeight_ap_vld(init_intra_neighbors_hls_unitHeight_ap_vld),
	.init_intra_neighbors_hls_log2TrSize(init_intra_neighbors_hls_log2TrSize),
	.init_intra_neighbors_hls_log2TrSize_ap_vld(init_intra_neighbors_hls_log2TrSize_ap_vld),
	.init_intra_neighbors_hls_bNeighborFlags(init_intra_neighbors_hls_bNeighborFlags),
	.init_intra_neighbors_hls_bNeighborFlags_ap_vld(init_intra_neighbors_hls_bNeighborFlags_ap_vld),
	.init_intra_neighbors_hls_Transpose_tab_mvf_pred_flag_CTU_address0(init_intra_neighbors_hls_Transpose_tab_mvf_pred_flag_CTU_address0),
	.init_intra_neighbors_hls_Transpose_tab_mvf_pred_flag_CTU_ce0(init_intra_neighbors_hls_Transpose_tab_mvf_pred_flag_CTU_ce0),
	.init_intra_neighbors_hls_Transpose_tab_mvf_pred_flag_CTU_q0(init_intra_neighbors_hls_Transpose_tab_mvf_pred_flag_CTU_q0),
	.innerloop_ff_hevc_extract_rbsp_1_hls_zero_i(innerloop_ff_hevc_extract_rbsp_1_hls_zero_i),
	.innerloop_ff_hevc_extract_rbsp_1_hls_zero_o(innerloop_ff_hevc_extract_rbsp_1_hls_zero_o),
	.innerloop_ff_hevc_extract_rbsp_1_hls_zero_o_ap_vld(innerloop_ff_hevc_extract_rbsp_1_hls_zero_o_ap_vld),
	.innerloop_ff_hevc_extract_rbsp_1_hls_loop_init(innerloop_ff_hevc_extract_rbsp_1_hls_loop_init),
	.innerloop_ff_hevc_extract_rbsp_1_hls_loop_len(innerloop_ff_hevc_extract_rbsp_1_hls_loop_len),
	.innerloop_ff_hevc_extract_rbsp_1_hls_loop_inc(innerloop_ff_hevc_extract_rbsp_1_hls_loop_inc),
	.innerloop_ff_hevc_extract_rbsp_1_hls_loop_cnt(innerloop_ff_hevc_extract_rbsp_1_hls_loop_cnt),
	.innerloop_ff_hevc_extract_rbsp_1_hls_loop_cnt_ap_vld(innerloop_ff_hevc_extract_rbsp_1_hls_loop_cnt_ap_vld),
	.innerloop_ff_hevc_extract_rbsp_2_hls_si_loop_i(innerloop_ff_hevc_extract_rbsp_2_hls_si_loop_i),
	.innerloop_ff_hevc_extract_rbsp_2_hls_si_loop_o(innerloop_ff_hevc_extract_rbsp_2_hls_si_loop_o),
	.innerloop_ff_hevc_extract_rbsp_2_hls_si_loop_o_ap_vld(innerloop_ff_hevc_extract_rbsp_2_hls_si_loop_o_ap_vld),
	.innerloop_ff_hevc_extract_rbsp_2_hls_di_loop_i(innerloop_ff_hevc_extract_rbsp_2_hls_di_loop_i),
	.innerloop_ff_hevc_extract_rbsp_2_hls_di_loop_o(innerloop_ff_hevc_extract_rbsp_2_hls_di_loop_o),
	.innerloop_ff_hevc_extract_rbsp_2_hls_di_loop_o_ap_vld(innerloop_ff_hevc_extract_rbsp_2_hls_di_loop_o_ap_vld),
	.innerloop_ff_hevc_extract_rbsp_2_hls_zero_i(innerloop_ff_hevc_extract_rbsp_2_hls_zero_i),
	.innerloop_ff_hevc_extract_rbsp_2_hls_zero_o(innerloop_ff_hevc_extract_rbsp_2_hls_zero_o),
	.innerloop_ff_hevc_extract_rbsp_2_hls_zero_o_ap_vld(innerloop_ff_hevc_extract_rbsp_2_hls_zero_o_ap_vld),
	.innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_i(innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_i),
	.innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_o(innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_o),
	.innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_o_ap_vld(innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_o_ap_vld),
	.innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_pos_address0(innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_pos_address0),
	.innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_pos_ce0(innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_pos_ce0),
	.innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_pos_we0(innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_pos_we0),
	.innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_pos_d0(innerloop_ff_hevc_extract_rbsp_2_hls_skipped_bytes_pos_d0),
	.innerloop_ff_hevc_extract_rbsp_2_hls_loop_init(innerloop_ff_hevc_extract_rbsp_2_hls_loop_init),
	.innerloop_ff_hevc_extract_rbsp_2_hls_loop_len(innerloop_ff_hevc_extract_rbsp_2_hls_loop_len),
	.innerloop_ff_hevc_extract_rbsp_2_hls_loop_inc(innerloop_ff_hevc_extract_rbsp_2_hls_loop_inc),
	.innerloop_ff_hevc_extract_rbsp_2_hls_loop_cnt(innerloop_ff_hevc_extract_rbsp_2_hls_loop_cnt),
	.innerloop_ff_hevc_extract_rbsp_2_hls_loop_cnt_ap_vld(innerloop_ff_hevc_extract_rbsp_2_hls_loop_cnt_ap_vld)
);



//---------------------------------------
//Xmem
//---------------------------------------
xmem inst_xmem (
	.clk			( clk			),
	.rstn			( rstn			),
	//risc interface
	.risc_we		( xmem_we		),
	.risc_re		( xmem_re		),
	.risc_adr		( xmem_ad		),
	.risc_di		( xmem_di		),
	.risc_rdy		( xmem_rdy		),
    .risc_do_vld    ( 				),
	.risc_do		( xmem_do		),

	//For dualport bank (SCALAR range)
	.scalar_argVld	( scalar_argVld	),
	.scalar_argAck	( scalar_argAck	),
	.scalar_adr		( scalar_adr	),
	.scalar_wdat	( scalar_wdat	),
	.scalar_rdat	( scalar_rdat	),

	//For single port bank (ARRAY range)
	.array_argVld	( array_argVld	),
	.array_argAck	( array_argAck	),
	.array_adr		( array_adr		),
	.array_wdat		( array_wdat	),
	.array_rdat		( array_rdat	),

	//For cyclic port bank (CYCLIC range)
	.cyclic_argVld	( cyclic_argVld	),
	.cyclic_argAck	( cyclic_argAck	),
	.cyclic_adr		( cyclic_adr	),
	.cyclic_wdat	( cyclic_wdat	),
	.cyclic_rdat	( cyclic_rdat	)
);



//-----------------------------------
// HLS with DMA
//-----------------------------------
`ifdef ENABLE_DEC
	`include "hls_dma_instantiate.vh"
`else 
	assign dma_rdy = 0;
	assign dma_do = 0;
	 //AXI4 interface 0
	assign axi_awvalid = 0;
	assign axi_awaddr = 0;
	assign axi_awlen = 0;
	assign axi_awid = 0;
	assign axi_awsize = 0;
	assign axi_awburst = 0;
	assign axi_awlock = 0;
	assign axi_awcache = 0;
	assign axi_awprot = 0;
	assign axi_awqos = 0;
	assign axi_awregion = 0;
	assign axi_awuser = 0;
	assign axi_wvalid = 0;
	assign axi_wdata = 0;
	assign axi_wstrb = 0;
	assign axi_wlast = 0;
	assign axi_wid = 0;
	assign axi_wuser = 0;
	assign axi_bready = 0;
	assign axi_arvalid = 0;
	assign axi_araddr = 0;
	assign axi_arlen = 0;
	assign axi_arid = 0;
	assign axi_arsize = 0;
	assign axi_arburst = 0;
	assign axi_arlock = 0;
	assign axi_arcache = 0;
	assign axi_arprot = 0;
	assign axi_arqos = 0;
	assign axi_arregion = 0;
	assign axi_aruser = 0;
	assign axi_rready = 0;
	//AXI4 interface 1
	assign axi_awvalid_1 = 0;
	assign axi_awaddr_1 = 0;
	assign axi_awlen_1 = 0;
	assign axi_awid_1 = 0;
	assign axi_awsize_1 = 0;
	assign axi_awburst_1 = 0;
	assign axi_awlock_1 = 0;
	assign axi_awcache_1 = 0;
	assign axi_awprot_1 = 0;
	assign axi_awqos_1 = 0;
	assign axi_awregion_1 = 0;
	assign axi_awuser_1 = 0;
	assign axi_wvalid_1 = 0;
	assign axi_wdata_1 = 0;
	assign axi_wstrb_1 = 0;
	assign axi_wlast_1 = 0;
	assign axi_wid_1 = 0;
	assign axi_wuser_1 = 0;
	assign axi_bready_1 = 0;
	assign axi_arvalid_1 = 0;
	assign axi_araddr_1 = 0;
	assign axi_arlen_1 = 0;
	assign axi_arid_1 = 0;
	assign axi_arsize_1 = 0;
	assign axi_arburst_1 = 0;
	assign axi_arlock_1 = 0;
	assign axi_arcache_1 = 0;
	assign axi_arprot_1 = 0;
	assign axi_arqos_1 = 0;
	assign axi_arregion_1 = 0;
	assign axi_aruser_1 = 0;
	assign axi_rready_1 = 0;
	//AXI4 interface 2
	assign axi_awvalid_2 = 0;
	assign axi_awaddr_2 = 0;
	assign axi_awlen_2 = 0;
	assign axi_awid_2 = 0;
	assign axi_awsize_2 = 0;
	assign axi_awburst_2 = 0;
	assign axi_awlock_2 = 0;
	assign axi_awcache_2 = 0;
	assign axi_awprot_2 = 0;
	assign axi_awqos_2 = 0;
	assign axi_awregion_2 = 0;
	assign axi_awuser_2 = 0;
	assign axi_wvalid_2 = 0;
	assign axi_wdata_2 = 0;
	assign axi_wstrb_2 = 0;
	assign axi_wlast_2 = 0;
	assign axi_wid_2 = 0;
	assign axi_wuser_2 = 0;
	assign axi_bready_2 = 0;
	assign axi_arvalid_2 = 0;
	assign axi_araddr_2 = 0;
	assign axi_arlen_2 = 0;
	assign axi_arid_2 = 0;
	assign axi_arsize_2 = 0;
	assign axi_arburst_2 = 0;
	assign axi_arlock_2 = 0;
	assign axi_arcache_2 = 0;
	assign axi_arprot_2 = 0;
	assign axi_arqos_2 = 0;
	assign axi_arregion_2 = 0;
	assign axi_aruser_2 = 0;
	assign axi_rready_2 = 0;	
`endif 

//-----------------------------------
// Output registers
//-----------------------------------
`ifdef ENABLE_DEC
	assign transquant_bypass_o = 0; //reserved?
	assign pred_mode_o         = pred_mode;
	assign qp_offset_cb_o      = 0; //reserved?
	assign qp_offset_cr_o      = 0; //reserved?
	assign intra_pred_mode_o   = tu_intra_pred_mode;
	assign intra_pred_mode_c_o = tu_intra_pred_mode_c;
	assign qp_y_o              = qp_y;
	assign scan_idx_o          = scan_idx;
`else 
	assign transquant_bypass_o = 0; //reserved?
	assign pred_mode_o         = 0;
	assign qp_offset_cb_o      = 0; //reserved?
	assign qp_offset_cr_o      = 0; //reserved?
	assign intra_pred_mode_o   = 0;
	assign intra_pred_mode_c_o = 0;
	assign qp_y_o              = 0;
	assign scan_idx_o          = 0;
`endif 


endmodule
