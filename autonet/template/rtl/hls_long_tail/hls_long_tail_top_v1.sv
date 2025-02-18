////////////////////////////////////////////////////////////////////////////////
// Company            : ViShare Technology Limited
// Designed by        : Edward Leung
// Date Created       : 2023-07-03
// Description        : Top of HLS long tail function.
// Version            : v1.0 - First version.
//                      v1.1 - With xmem interface from HLS.
//                      v1.2 - Add profiling cycle for HLS in riscv_ap_ctrl_bus.
//                             Add function arbiter.
//                      v1.3 - Riscv can access xmem1.
//                      v1.4 - Lock signal for cache arbiter among HLS.
//                      v1.5 - Output all HLS cache interface and is selected by top level arbiter
//                      v1.6 - Use xcache
////////////////////////////////////////////////////////////////////////////////

//param_list = ${param_list}

`include "common.vh"

//Add fifo between parent and function arbiter to improve II
//`define FUNC_PARENT_FIFO

module hls_long_tail_top_v1 ${param_list}
#(
    parameter START_CORE     = 0,
    parameter CORE_NUM       = 1,
    parameter ENABLE_DMA     = 1,
    parameter ENABLE_PROFILE = 0,
    parameter EN_RISCV_XMEM1 = 0,
    //XCACHE
    parameter AXI_ADDR_WIDTH  = 32,
    parameter AXI_DATA_WIDTH  = 256,
    parameter AXI_LEN_WIDTH   = 8,
    parameter AXI_ID_WIDTH    = 8,
    parameter AXI_STRB_WIDTH  = AXI_DATA_WIDTH / 8,
    //AXIS DMA
    parameter AXI2_ADDR_WIDTH = 32,
    parameter AXI2_DATA_WIDTH = 256,
    parameter AXI2_LEN_WIDTH  = 8,
    parameter AXI2_ID_WIDTH   = 8,
    parameter AXI2_STRB_WIDTH = AXI2_DATA_WIDTH / 8
)
(
    input                                 clk,
    input                                 rstn,
    //Riscv core
    input                                 rv_re                   [CORE_NUM],
    input        [ 3 : 0]                 rv_we                   [CORE_NUM],
    input        [31 : 0]                 rv_addr                 [CORE_NUM],
    input        [31 : 0]                 rv_wdata                [CORE_NUM],
    output logic                          rv_ready                [CORE_NUM],
    output logic                          rv_valid                [CORE_NUM],
    output logic [31 : 0]                 rv_rdata                [CORE_NUM],
    //Riscv core (xcache content access)
    input        [ 7 : 0]                 rv_xcache_part          [CORE_NUM],
    input                                 rv_xcache_re            [CORE_NUM],
    input        [ 3 : 0]                 rv_xcache_we            [CORE_NUM],
    input        [31 : 0]                 rv_xcache_addr          [CORE_NUM],
    input        [31 : 0]                 rv_xcache_wdata         [CORE_NUM],
    output logic                          rv_xcache_ready         [CORE_NUM],
    output logic                          rv_xcache_valid         [CORE_NUM],
    output logic [31 : 0]                 rv_xcache_rdata         [CORE_NUM],
    //Riscv -> HLS function arbiter (RISCV is Parent)
    output logic                          rv_prnt_reqRdy_o        [CORE_NUM],
    input                                 rv_prnt_reqVld_i        [CORE_NUM],
    input        [31 : 0]                 rv_prnt_reqChild_i      [CORE_NUM],
    input        [31 : 0]                 rv_prnt_reqPc_i         [CORE_NUM],
    input        [255 : 0]                rv_prnt_reqArgs_i       [CORE_NUM],
    input                                 rv_prnt_reqReturn_i     [CORE_NUM],
    input                                 rv_prnt_retRdy_i        [CORE_NUM],
    output logic                          rv_prnt_retVld_o        [CORE_NUM],
    output logic [31 : 0]                 rv_prnt_retChild_o      [CORE_NUM],
    output logic [31 : 0]                 rv_prnt_retDat_o        [CORE_NUM],
    //Riscv -> HLS function arbiter (RISCV is Child)
    input                                 rv_chld_reqRdy_i        [CORE_NUM],
    output logic                          rv_chld_reqVld_o        [CORE_NUM],
    output logic [31 : 0]                 rv_chld_reqParent_o     [CORE_NUM],
    output logic [255 : 0]                rv_chld_reqArgs_o       [CORE_NUM],
    output logic [31 : 0]                 rv_chld_reqPc_o         [CORE_NUM],
    output logic                          rv_chld_reqReturn_o     [CORE_NUM],
    output logic                          rv_chld_retRdy_o        [CORE_NUM],
    input                                 rv_chld_retVld_i        [CORE_NUM],
    input        [31 : 0]                 rv_chld_retParent_i     [CORE_NUM],
    input        [31 : 0]                 rv_chld_retDat_i        [CORE_NUM],
    //Function arbiter (Longtail HLS is parent)
    input                                 df_chld_reqRdy_i,
    output logic                          df_chld_reqVld_o,
    output logic [31 : 0]                 df_chld_reqParent_o,
    output logic [255 : 0]                df_chld_reqArgs_o,
    output logic [31 : 0]                 df_chld_reqPc_o,
    output logic                          df_chld_reqReturn_o,
    output logic                          df_chld_retRdy_o,
    input                                 df_chld_retVld_i,
    input        [31 : 0]                 df_chld_retParent_i,
    input        [31 : 0]                 df_chld_retDat_i,
`ifdef HLS_RISCV_L1CACHE
    //connecting to riscv L1 dcache
    input                                 dcArb_hls_user_rdy      [CORE_NUM],
    output logic                          dcArb_hls_user_re       [CORE_NUM],
    output logic                          dcArb_hls_user_we       [CORE_NUM],
    output logic [3  : 0]                 dcArb_hls_user_we_mask  [CORE_NUM],
    output logic [31 : 0]                 dcArb_hls_user_adr      [CORE_NUM],
    output logic [31 : 0]                 dcArb_hls_user_wdat     [CORE_NUM],
    output logic                          dcArb_hls_user_csr_flush[CORE_NUM],
    input        [31 : 0]                 dcArb_hls_user_rdat     [CORE_NUM],
    input                                 dcArb_hls_user_rdat_vld [CORE_NUM],
    //Copy Engine to riscv L1 dacache
    output logic                          cpEng_dc_re             [CORE_NUM],
    output logic [31 : 0]                 cpEng_dc_rad            [CORE_NUM],
    input                                 cpEng_dc_rrdy           [CORE_NUM],
    input        [31 : 0]                 cpEng_dc_rdat           [CORE_NUM],
    input                                 cpEng_dc_rdat_vld       [CORE_NUM],
    output logic [3 : 0]                  cpEng_dc_bwe            [CORE_NUM],
    output logic [31 : 0]                 cpEng_dc_wad            [CORE_NUM],
    output logic [31 : 0]                 cpEng_dc_wdat           [CORE_NUM],
    input                                 cpEng_dc_wrdy           [CORE_NUM],
`else `ifdef HLS_LOCAL_DCACHE
    //connecting to local dacache
    input                                 dcArb_hls_user_rdy      [HLS_CACHE],
    output logic                          dcArb_hls_user_ap_ce    [HLS_CACHE],
    output logic                          dcArb_hls_user_re       [HLS_CACHE],
    output logic                          dcArb_hls_user_we       [HLS_CACHE],
    output logic [3  : 0]                 dcArb_hls_user_we_mask  [HLS_CACHE],
    output logic [31 : 0]                 dcArb_hls_user_adr      [HLS_CACHE],
    output logic [31 : 0]                 dcArb_hls_user_wdat     [HLS_CACHE],
    output logic                          dcArb_hls_user_csr_flush[HLS_CACHE],
    input        [31 : 0]                 dcArb_hls_user_rdat     [HLS_CACHE],
    input                                 dcArb_hls_user_rdat_vld [HLS_CACHE],
    //Copy Engine to local dacache
    output logic                          cpEng_dc_re,
    output logic [31 : 0]                 cpEng_dc_rad,
    input                                 cpEng_dc_rrdy,
    input        [31 : 0]                 cpEng_dc_rdat,
    input                                 cpEng_dc_rdat_vld,
    output logic [3 : 0]                  cpEng_dc_bwe,
    output logic [31 : 0]                 cpEng_dc_wad,
    output logic [31 : 0]                 cpEng_dc_wdat,
    input                                 cpEng_dc_wrdy,
`endif `endif
    //DecodeBin
    output logic [CABAC_NUM_BITS - 1 : 0] decBin_sel              [CORE_NUM],
    output logic [ 8 : 0]                 decBin_ctx              [CORE_NUM],
    output logic                          decBin_get              [CORE_NUM],
    input                                 decBin_rdy              [CORE_NUM],
    input                                 decBin_bin              [CORE_NUM],
    input                                 decBin_vld              [CORE_NUM],
    //Xmem access from dataflow HLS
    output logic                          hls_xmem1_rdy0          [CORE_NUM],
    input                                 hls_xmem1_ce0           [CORE_NUM],
    input        [ 7 : 0]                 hls_xmem1_we0           [CORE_NUM],
    input        [31 : 0]                 hls_xmem1_address0      [CORE_NUM],
    input        [63 : 0]                 hls_xmem1_d0            [CORE_NUM],
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
    //AXI4 interface (write channel) for DMA
    input                                 dma_axi_awready,
    output logic                          dma_axi_awvalid,
    output logic [AXI2_ADDR_WIDTH-1 : 0]  dma_axi_awaddr,
    output logic [AXI2_LEN_WIDTH-1 : 0]   dma_axi_awlen,
    output logic [AXI2_ID_WIDTH-1 : 0]    dma_axi_awid,
    output logic [2 : 0]                  dma_axi_awsize,
    output logic [1 : 0]                  dma_axi_awburst,
    output logic                          dma_axi_awlock,
    output logic [3 : 0]                  dma_axi_awcache,
    output logic [2 : 0]                  dma_axi_awprot,
    output logic [3 : 0]                  dma_axi_awqos,
    output logic [3 : 0]                  dma_axi_awregion,
    output logic                          dma_axi_awuser,
    input                                 dma_axi_wready,
    output logic                          dma_axi_wvalid,
    output logic [AXI2_DATA_WIDTH - 1 : 0]dma_axi_wdata,
    output logic [AXI2_STRB_WIDTH - 1 : 0]dma_axi_wstrb,
    output logic                          dma_axi_wlast,
    output logic [AXI2_ID_WIDTH-1 : 0]    dma_axi_wid,
    output logic                          dma_axi_wuser,
    output logic                          dma_axi_bready,
    input                                 dma_axi_bvalid,
    input        [1 : 0]                  dma_axi_bresp,
    input        [AXI2_ID_WIDTH-1 : 0]    dma_axi_bid,
    input                                 dma_axi_buser,
    //AXI4 interface (read channel) for DMA
    input                                 dma_axi_arready,
    output logic                          dma_axi_arvalid,
    output logic [AXI2_ADDR_WIDTH-1 : 0]  dma_axi_araddr,
    output logic [AXI2_LEN_WIDTH-1 : 0]   dma_axi_arlen,
    output logic [AXI2_ID_WIDTH-1 : 0]    dma_axi_arid,
    output logic [2 : 0]                  dma_axi_arsize,
    output logic [1 : 0]                  dma_axi_arburst,
    output logic                          dma_axi_arlock,
    output logic [3 : 0]                  dma_axi_arcache,
    output logic [2 : 0]                  dma_axi_arprot,
    output logic [3 : 0]                  dma_axi_arqos,
    output logic [3 : 0]                  dma_axi_arregion,
    output logic                          dma_axi_aruser,
    input                                 dma_axi_rvalid,
    output logic                          dma_axi_rready,
    input        [AXI2_DATA_WIDTH-1 : 0]  dma_axi_rdata,
    input                                 dma_axi_rlast,
    input        [1 : 0]                  dma_axi_rresp,
    input        [AXI2_ID_WIDTH-1 : 0]    dma_axi_rid,
    input                                 dma_axi_ruser,
    //AXI4 interface (write channel) for xcache
    input                                 xcache_axi_awready [2],
    output logic                          xcache_axi_awvalid [2],
    output logic [AXI_ADDR_WIDTH-1 : 0]   xcache_axi_awaddr  [2],
    output logic [AXI_LEN_WIDTH-1 : 0]    xcache_axi_awlen   [2],
    output logic [AXI_ID_WIDTH-1 : 0]     xcache_axi_awid    [2],
    output logic [2 : 0]                  xcache_axi_awsize  [2],
    output logic [1 : 0]                  xcache_axi_awburst [2],
    output logic                          xcache_axi_awlock  [2],
    output logic [3 : 0]                  xcache_axi_awcache [2],
    output logic [2 : 0]                  xcache_axi_awprot  [2],
    output logic [3 : 0]                  xcache_axi_awqos   [2],
    output logic [3 : 0]                  xcache_axi_awregion[2],
    output logic                          xcache_axi_awuser  [2],
    input                                 xcache_axi_wready  [2],
    output logic                          xcache_axi_wvalid  [2],
    output logic [AXI_DATA_WIDTH - 1 : 0] xcache_axi_wdata   [2],
    output logic [AXI_STRB_WIDTH - 1 : 0] xcache_axi_wstrb   [2],
    output logic                          xcache_axi_wlast   [2],
    output logic [AXI_ID_WIDTH-1 : 0]     xcache_axi_wid     [2],
    output logic                          xcache_axi_wuser   [2],
    output logic                          xcache_axi_bready  [2],
    input                                 xcache_axi_bvalid  [2],
    input        [1 : 0]                  xcache_axi_bresp   [2],
    input        [AXI_ID_WIDTH-1 : 0]     xcache_axi_bid     [2],
    input                                 xcache_axi_buser   [2],
    //AXI4 interface (read channel) for xcache
    input                                 xcache_axi_arready [2],
    output logic                          xcache_axi_arvalid [2],
    output logic [AXI_ADDR_WIDTH-1 : 0]   xcache_axi_araddr  [2],
    output logic [AXI_LEN_WIDTH-1 : 0]    xcache_axi_arlen   [2],
    output logic [AXI_ID_WIDTH-1 : 0]     xcache_axi_arid    [2],
    output logic [2 : 0]                  xcache_axi_arsize  [2],
    output logic [1 : 0]                  xcache_axi_arburst [2],
    output logic                          xcache_axi_arlock  [2],
    output logic [3 : 0]                  xcache_axi_arcache [2],
    output logic [2 : 0]                  xcache_axi_arprot  [2],
    output logic [3 : 0]                  xcache_axi_arqos   [2],
    output logic [3 : 0]                  xcache_axi_arregion[2],
    output logic                          xcache_axi_aruser  [2],
    input                                 xcache_axi_rvalid  [2],
    output logic                          xcache_axi_rready  [2],
    input        [AXI_DATA_WIDTH-1 : 0]   xcache_axi_rdata   [2],
    input                                 xcache_axi_rlast   [2],
    input        [1 : 0]                  xcache_axi_rresp   [2],
    input        [AXI_ID_WIDTH-1 : 0]     xcache_axi_rid     [2],
    input                                 xcache_axi_ruser   [2]
);

localparam CORE_NUM_BIT             = (CORE_NUM == 1)? 1 : $$clog2(CORE_NUM);
localparam HLS_IDX_BITS             = (HLS_NUM == 1)? 1 : $$clog2(HLS_NUM);
localparam HLS_ARG_WIDTH            = 32;
localparam HLS_ARG_VECTOR           = 8;
localparam HLS_RET_WIDTH            = 32;
localparam HLS_RET_VECTOR           = 1;
localparam XCACHE_ADDR_WIDTH        = 32;
localparam XCACHE_DATA_WIDTH        = 32;
localparam XMEM_ADDR_WIDTH          = 32;
localparam XMEM_DATA_WIDTH          = 32;
localparam DMA_ADDR_WIDTH           = 20;
localparam DMA_DATA_WIDTH           = 32;
//Function arbiter parameters
localparam PARENT                   = CORE_NUM + HLS_PARENT;        //Riscv, parent HLS
localparam CHILD                    = CORE_NUM + 1 + 1 + HLS_NUM;   //Riscv, cmdr, copyEngine, all HLS
localparam RV_PARENT_ID             = 0;
localparam HLS_PARENT_ID            = CORE_NUM;
localparam HLS_CHILD_ID             = 0;
localparam CPY_CHILD_ID             = HLS_NUM;
localparam DF_CHILD_ID              = HLS_NUM + 1;
localparam RV_CHILD_ID              = HLS_NUM + 2;
//DMA parameters
localparam RISC_DWIDTH              = 32;
localparam DMA_NUM                  = 2;	//previous: 4 	(so: changed)
localparam L_DMA_NUM                = (DMA_NUM==1) ? 1 : $$clog2(DMA_NUM);
localparam AXI_ARB_ID_WIDTH         = $$clog2(DMA_NUM) + 1;
localparam DMA_AXIS_AXI4_AWIDTH     = AXI2_ADDR_WIDTH;
localparam DMA_AXIS_AXI4_DWIDTH     = AXI2_DATA_WIDTH;
localparam DMA_AXIS_AXI4_T_DW       = 8;//AXI_DATA_WIDTH;
localparam DMA_AXIS_AXI4_REGS_AW    = 4;
localparam DMA_AXIS_AXI4_RAM_STYLE  = "distributed";
localparam DMA_AXIS_AXI4_FIFO_DEPTH = 1024 / (DMA_AXIS_AXI4_DWIDTH / DMA_AXIS_AXI4_T_DW);
//Localparam used by function arbiter
`include "func_arbiter_param.vh"

//HLS ap_ctrl
logic                                ap_ce       [HLS_NUM];
logic                                ap_arb_start[HLS_NUM];
logic                                ap_arb_start_r[HLS_NUM];
logic                                ap_arb_ret  [HLS_NUM];
logic                                ap_start    [HLS_NUM];
logic 								 ap_running  [HLS_NUM];
logic 								 ap_running_r[HLS_NUM];
logic [HLS_ARG_WIDTH - 1 : 0]        ap_arg      [HLS_NUM][HLS_ARG_VECTOR];
logic                                ap_ready    [HLS_NUM];
logic                                ap_idle     [HLS_NUM];
logic                                ap_done     [HLS_NUM];
logic                                ap_busy     [HLS_NUM];
logic [HLS_RET_WIDTH - 1 : 0]        ap_return   [HLS_NUM][HLS_RET_VECTOR];
logic [7 : 0]                        ap_parent   [HLS_NUM];
logic                                ap_req_ret  [HLS_NUM];
logic [7 : 0]                        ap_core     [HLS_NUM];
logic [7 : 0]                        ap_part     [HLS_NUM];
logic                                ap_xmem_ready[HLS_NUM];
logic                                ap_ret_ready [HLS_NUM];
//For profiling
logic                                ap_hls_req   [HLS_PARENT];
logic [31 : 0]                       ap_hls_id    [HLS_PARENT];
logic                                ap_hls_retReq[HLS_PARENT];
logic                                ap_hls_retPop[HLS_PARENT];
//XCACHE
logic [3 : 0]                        xcache_cfg;
logic [XCACHE_ADDR_WIDTH - 1 : 0]    xcache_cfg_ad;
logic [XCACHE_DATA_WIDTH - 1 : 0]    xcache_cfg_di;
logic                                xcache_rdy;
logic [7:0]                          xcache_part;
logic                                xcache_re;
logic [3 : 0]                        xcache_we;
logic [XCACHE_ADDR_WIDTH - 1 : 0]    xcache_ad;
logic [XCACHE_DATA_WIDTH - 1 : 0]    xcache_di;
logic [XCACHE_DATA_WIDTH - 1 : 0]    xcache_do;
logic                                xcache_do_vld;
//XMME (v1) bus
logic                                xmem1_rdy;
logic                                xmem1_re;
logic [3 : 0]                        xmem1_we;
logic [XMEM_ADDR_WIDTH - 1 : 0]      xmem1_ad;
logic [XMEM_DATA_WIDTH - 1 : 0]      xmem1_di;
logic [XMEM_DATA_WIDTH - 1 : 0]      xmem1_do;
//DMA bus
logic                                dma_rdy;
logic                                dma_re;
logic                                dma_re_r;
logic                                dma_we;
logic [DMA_ADDR_WIDTH - 1 : 0]       dma_ad;
logic [DMA_ADDR_WIDTH - 1 : 0]       dma_ad_r;
logic [DMA_DATA_WIDTH - 1 : 0]       dma_di;
logic [DMA_DATA_WIDTH - 1 : 0]       dma_do;
//DecodeBin request
logic [CABAC_NUM_BITS - 1 : 0]       decBin_sel_c[CORE_NUM];
logic [8 : 0]                        decBin_ctx_c[CORE_NUM];
logic                                decBin_get_c[CORE_NUM];
logic                                decBin_rdy_c[CORE_NUM];
//Function arbiter
logic [CMD_FIFO_DW - 1 : 0]          parent_cmdfifo_din_i    [PARENT];
logic                                parent_cmdfifo_full_n_o [PARENT];
logic                                parent_cmdfifo_write_i  [PARENT];
`ifdef FUNC_PARENT_FIFO
logic [CMD_FIFO_DW - 1 : 0]          parent2_cmdfifo_din_i    [PARENT];
logic                                parent2_cmdfifo_full_n_o [PARENT];
logic                                parent2_cmdfifo_write_i  [PARENT];
`endif
logic [CHILD-1:0]                    child_ap_ce_o;
logic [CHILD-1:0]                    child_ap_done_i;
logic                                child_retReq_o;
logic                                child_rdy_i             [CHILD];
logic [CHILD - 1 : 0]                child_callVld_o;
logic [LOG_PARENT - 1 : 0]           child_parent_o;
logic [ARG_W - 1 : 0]                child_pc_o;
logic [TOTAL_ARGS_W - 1 : 0]         child_args_o;

logic                                xmemStart;
logic [LOG_CHILD-1:0]                xmemStartFunc;
logic                                xmemCancel_p1;
logic                                xmemCancel_p2;

logic                                child_retRdy_o          [CHILD];
logic                                child_retVld_i          [CHILD];
logic [31 : 0]                       child_retDin_i          [CHILD];
logic [LOG_PARENT - 1 : 0]           child_parentMod_i       [CHILD];
logic [PARENT - 1 : 0]               parent_retFifo_pop_i;
logic [PARENT - 1 : 0]               parent_retFifo_empty_n_o;
logic [FULL_RET_DW - 1 : 0]          parent_retFifo_dout_o   [PARENT];
//CopyEngine
logic                                copyEngine_copy_i;
logic                                copyEngine_set_i;
logic [7 : 0]                        copyEngine_setVal_i;
logic [31 : 0]                       copyEngine_len_i;
logic [31 : 0]                       copyEngine_src_i;
logic [31 : 0]                       copyEngine_dst_i;
logic                                copyEngine_done_o;
logic                                copyEngine_mem_re_r;
logic [31 : 0]                       copyEngine_mem_rad_r;
logic                                copyEngine_mem_rreq_rdy;
logic [63 : 0]                       copyEngine_mem_rdat;
logic                                copyEngine_mem_rdat_rdy;
logic [7 : 0]                        copyEngine_mem_bwe_r;
logic [31 : 0]                       copyEngine_mem_wad_r;
logic [63 : 0]                       copyEngine_mem_wdat_r;
logic                                copyEngine_mem_wreq_rdy;
logic [LOG_PARENT-1:0]               copyEngine_parent, copyEngine_parent_r;
logic                                copyEngine_run, copyEngine_run_r;
logic [CORE_NUM_BIT-1:0]             copyEngine_core, copyEngine_core_r;
logic                                copyEngine_ret, copyEngine_ret_r;
//DMA
logic                                dma_finish      [DMA_NUM];
logic                                dma_regs_we     [DMA_NUM];
logic [DMA_AXIS_AXI4_REGS_AW -1 : 0] dma_regs_addr   [DMA_NUM];
logic [DMA_DATA_WIDTH -1 : 0]        dma_regs_wdata  [DMA_NUM];
logic                                dma_regs_rdy    [DMA_NUM];
logic [DMA_DATA_WIDTH -1 : 0]        dma_regs_rdata  [DMA_NUM];

//Dcache
integer                              hls_user_idx;
`ifdef HLS_RISCV_L1CACHE
logic                                hls_user_rdy     [CORE_NUM];
logic                                hls_user_re      [CORE_NUM];
logic                                hls_user_we      [CORE_NUM];
logic [3  : 0]                       hls_user_we_mask [CORE_NUM];
logic [31 : 0]                       hls_user_adr     [CORE_NUM];
logic [31 : 0]                       hls_user_wdat    [CORE_NUM];
logic [31 : 0]                       hls_user_rdat    [CORE_NUM];
logic                                hls_user_rdat_vld[CORE_NUM];
`else
logic                                hls_user_rdy     [HLS_CACHE];
logic                                hls_user_ap_ce   [HLS_CACHE];
logic                                hls_user_re      [HLS_CACHE];
logic                                hls_user_we      [HLS_CACHE];
logic [3  : 0]                       hls_user_we_mask [HLS_CACHE];
logic [31 : 0]                       hls_user_adr     [HLS_CACHE];
logic [31 : 0]                       hls_user_wdat    [HLS_CACHE];
logic [31 : 0]                       hls_user_rdat    [HLS_CACHE];
logic                                hls_user_rdat_vld[HLS_CACHE];
`endif
logic                                dc_ready         [HLS_NUM];
logic                                dc_enable        [HLS_NUM];
logic                                dc_lock_set      [HLS_NUM];
logic                                dc_lock_clr      [HLS_NUM];
logic                                dc_lock_req      [HLS_NUM];
logic                                dc_locking       [CORE_NUM];
logic [HLS_IDX_BITS - 1 : 0]         dc_lock_id       [CORE_NUM];
//Stack to store dcache select
logic [HLS_IDX_BITS : 0]             sel_stack        [CORE_NUM][8];
logic [3 : 0]                        sel_stack_ptr    [CORE_NUM];
//dual port bank in scalar range
logic                                scalar_argVld  [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic                                scalar_argAck  [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [XMEM_AW - 1 : 0]              scalar_adr     [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [SCALAR_BANK_DW - 1 : 0]       scalar_wdat    [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [SCALAR_BANK_DW - 1 : 0]       scalar_rdat    [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic                                scalar_rdat_vld[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];     //so added
//single port bank in array range
logic                                array_argRdy   [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic                                array_ap_ce    [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic                                array_argVld   [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic                                array_argAck   [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [XMEM_AW - 1 : 0]              array_adr      [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [ARRAY_BANK_DW - 1 : 0]        array_wdat     [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [ARRAY_BANK_DW - 1 : 0]        array_rdat     [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic                                array_rdat_vld [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];      //so added
//wide port bank in cyclic range
logic                                cyclic_argRdy  [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic                                cyclic_ap_ce   [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic                                cyclic_argVld  [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic                                cyclic_argAck  [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [XMEM_AW - 1 : 0]              cyclic_adr     [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [CYCLIC_BANK_DW - 1 : 0]       cyclic_wdat    [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [CYCLIC_BANK_DW - 1 : 0]       cyclic_rdat    [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic                                cyclic_rdat_vld[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];    //so added

//Test HLS with random ap_ce=0
`ifdef HLS_AP_CE_TEST
initial begin
    $$display("%m HLS_AP_CE_TEST eanbled!");
end
logic [HLS_NUM-1:0] rand_ap_busy = 0;
always @ (posedge clk) begin
    rand_ap_busy <= $$random;
end
`endif

//Test custom_connect with random reload
`ifdef CUSTOM_CONN_RELOAD_TEST
initial begin
    $$display("%m CUSTOM_CONN_RELOAD_TEST eanbled!");
end
logic [HLS_NUM-1:0] rand_reload = 0;
always @ (posedge clk) begin
    rand_reload <= $$random;
end
`endif

//--------------------------------------------------
// Macro to connect HLS ap_ce
//--------------------------------------------------
`ifdef HLS_AP_CE_TEST
`define HLS_AP_CE(HLS)\
    ap_ce[HLS] = dc_ready[HLS] & ap_ret_ready[HLS] & HLS``_ready & ~(rand_ap_busy[HLS] & ~ap_idle[HLS]);\
    ap_xmem_ready[HLS] = HLS``_ready;
`else
`define HLS_AP_CE(HLS)\
    ap_ce[HLS] = dc_ready[HLS] & ap_ret_ready[HLS] & HLS``_ready;\
    ap_xmem_ready[HLS] = HLS``_ready;
`endif

//--------------------------------------------------
// Macro to connect HLS decodeBin interface
//--------------------------------------------------
`define DEC_BIN_ITF(HLS)\
    if ( HLS``_get_inline_mem_addr_o_ap_vld && ap_core[HLS] == i ) begin\
        decBin_get_c[i] = 1;\
        decBin_ctx_c[i] = HLS``_get_inline_mem_addr_o;\
        decBin_sel_c[i] = ap_part[HLS];\
    end\
    HLS``_get_inline_mem_addr_o_ap_rdy = decBin_rdy_c[ap_core[HLS]];\
    HLS``_get_inline_mem_data_i        = decBin_bin[ap_core[HLS]];\
    HLS``_get_inline_mem_data_i_ap_vld = decBin_vld[ap_core[HLS]];

`ifdef HLS_RISCV_L1CACHE
//--------------------------------------------------------
// Macro to connect HLS dcache interface (RISCV L1 cache)
//-------------------------------------------------------
//If dcache is locked by other, not ready if lock requesting.
//read & write
`define DCACHE_RW_ITF(HLS)\
    dc_enable[HLS] = 1;\
    dc_lock_set[HLS] = HLS``_dcache_ce0 && (HLS``_dcache_address0 == 0) && (HLS``_dcache_we0 != 0) && HLS``_dcache_d0[1];\
    dc_lock_clr[HLS] = HLS``_dcache_ce0 && (HLS``_dcache_address0 == 0) && (HLS``_dcache_we0 != 0) && ~HLS``_dcache_d0[1];\
    if(HLS``_dcache_ce0 && ap_core[HLS] == i) begin\
        hls_user_adr    [i] = HLS``_dcache_address0 * 4;\
        hls_user_re     [i] = ~(|HLS``_dcache_we0);\
        hls_user_we     [i] = |HLS``_dcache_we0;\
        hls_user_we_mask[i] = HLS``_dcache_we0;\
        hls_user_wdat   [i] = HLS``_dcache_d0;\
    end\
    dc_ready[HLS] = (hls_user_rdy[ap_core[HLS]] && (dc_lock_id[ap_core[HLS]] == HLS)) || (dc_lock_req[HLS] == 0);\
    HLS``_dcache_q0 = hls_user_rdat[ap_core[HLS]];
//read only
`define DCACHE_RO_ITF(HLS)\
    dc_enable[HLS] = 1;\
    if(HLS``_dcache_ce0 && ap_core[HLS] == i) begin\
        hls_user_adr[i] = HLS``_dcache_address0 * 4;\
        hls_user_re [i] = 1;\
    end\
    dc_ready[HLS] = (hls_user_rdy[ap_core[HLS]] && (dc_lock_id[ap_core[HLS]] == HLS)) || (dc_lock_req[HLS] == 0);\
    HLS``_dcache_q0 = hls_user_rdat[ap_core[HLS]];
//write only
`define DCACHE_WO_ITF(HLS)\
    dc_enable[HLS] = 1;\
    dc_lock_set[HLS] = HLS``_dcache_ce0 && (HLS``_dcache_address0 == 0) && (HLS``_dcache_we0 != 0) && HLS``_dcache_d0[1];\
    dc_lock_clr[HLS] = HLS``_dcache_ce0 && (HLS``_dcache_address0 == 0) && (HLS``_dcache_we0 != 0) && ~HLS``_dcache_d0[1];\
    if(HLS``_dcache_ce0 && ap_core[HLS] == i) begin\
        hls_user_adr    [i] = HLS``_dcache_address0 * 4;\
        hls_user_we     [i] = |HLS``_dcache_we0;\
        hls_user_we_mask[i] = HLS``_dcache_we0;\
        hls_user_wdat   [i] = HLS``_dcache_d0;\
    end\
    dc_ready[HLS] = (hls_user_rdy[ap_core[HLS]] && (dc_lock_id[ap_core[HLS]] == HLS)) || (dc_lock_req[HLS] == 0);
`else `ifdef HLS_LOCAL_DCACHE
//--------------------------------------------------
// Macro to connect HLS dcache interface (Local cache)
//--------------------------------------------------
//read & write
`define DCACHE_RW_ITF(HLS)\
    if (i == 0) begin\
        hls_user_ap_ce  [hls_user_idx] = ap_ce[HLS];\
        hls_user_re     [hls_user_idx] = HLS``_dcache_ce0 & (HLS``_dcache_we0 == 0);\
        hls_user_we     [hls_user_idx] = HLS``_dcache_ce0 & (HLS``_dcache_we0 != 0);\
        hls_user_we_mask[hls_user_idx] = HLS``_dcache_we0;\
        hls_user_adr    [hls_user_idx] = HLS``_dcache_address0 * 4;\
        hls_user_wdat   [hls_user_idx] = HLS``_dcache_d0;\
        HLS``_dcache_q0 = hls_user_rdat[hls_user_idx];\
        dc_ready[HLS]   = hls_user_rdy[hls_user_idx];\
        hls_user_idx    = hls_user_idx + 1;\
    end
//read only
`define DCACHE_RO_ITF(HLS)\
    if (i == 0) begin\
        hls_user_ap_ce[hls_user_idx] = ap_ce[HLS];\
        hls_user_re   [hls_user_idx] = HLS``_dcache_ce0;\
        hls_user_adr  [hls_user_idx] = HLS``_dcache_address0 * 4;\
        HLS``_dcache_q0 = hls_user_rdat[hls_user_idx];\
        dc_ready[HLS] = hls_user_rdy[hls_user_idx];\
        hls_user_idx = hls_user_idx + 1;\
    end
//write only
`define DCACHE_WO_ITF(HLS)\
    if (i == 0) begin\
        hls_user_ap_ce  [hls_user_idx] = ap_ce[HLS];\
        hls_user_we     [hls_user_idx] = HLS``_dcache_ce0;\
        hls_user_we_mask[hls_user_idx] = HLS``_dcache_we0;\
        hls_user_adr    [hls_user_idx] = HLS``_dcache_address0 * 4;\
        hls_user_wdat   [hls_user_idx] = HLS``_dcache_d0;\
        dc_ready[HLS] = hls_user_rdy[hls_user_idx];\
        hls_user_idx = hls_user_idx + 1;\
    end
`else
//--------------------------------------------------
// Macro to connect HLS dcache interface (No any cache)
//--------------------------------------------------
//read & write
`define DCACHE_RW_ITF(HLS)\
    if (i == 0) begin\
        HLS``_dcache_q0 = 0;\
    end
//read only
`define DCACHE_RO_ITF(HLS)\
    if (i == 0) begin\
        HLS``_dcache_q0 = 0;\
    end
//write only
`define DCACHE_WO_ITF(HLS)
`endif `endif

//--------------------------------------------------
// Macro to connect RISCV function arbiter
//--------------------------------------------------
//used rv_prnt_reqChild_i bit9 to select child id larger than HLS_NUM
//edward 2024-10-10: set bit8 to match software with offset 256
localparam CHILD_MAP_BIT = 8;
`define RISCV_FUNC_ARBITER\
    for (int i = 0; i < CORE_NUM; i = i + 1) begin\
        parent_cmdfifo_write_i[RV_PARENT_ID + i]                              = rv_prnt_reqVld_i[i];\
        parent_cmdfifo_din_i  [RV_PARENT_ID + i][ARGS_MSB:ARGS_LSB]           = rv_prnt_reqArgs_i[i];\
        parent_cmdfifo_din_i  [RV_PARENT_ID + i][CHILD_PC_MSB:CHILD_PC_LSB]   = rv_prnt_reqPc_i[i];\
        parent_cmdfifo_din_i  [RV_PARENT_ID + i][CHILD_MOD_MSB:CHILD_MOD_LSB] = rv_prnt_reqChild_i[i][CHILD_MAP_BIT]? (rv_prnt_reqChild_i[i][CHILD_MAP_BIT-1:0] + HLS_NUM) : rv_prnt_reqChild_i[i][CHILD_MAP_BIT-1:0];\
        parent_cmdfifo_din_i  [RV_PARENT_ID + i][RETREQ_BIT]                  = rv_prnt_reqReturn_i[i];\
        parent_retFifo_pop_i  [RV_PARENT_ID + i]                              = rv_prnt_retRdy_i[i] & parent_retFifo_empty_n_o[RV_PARENT_ID + i];\
        rv_prnt_reqRdy_o  [i] = parent_cmdfifo_full_n_o [RV_PARENT_ID + i];\
        rv_prnt_retVld_o  [i] = parent_retFifo_empty_n_o[RV_PARENT_ID + i];\
        rv_prnt_retChild_o[i] = parent_retFifo_dout_o[RV_PARENT_ID + i]  >> 32;\
        rv_prnt_retDat_o  [i] = parent_retFifo_dout_o[RV_PARENT_ID + i]  ;\
    end

//---------------------------------------
//HLS module
//---------------------------------------
`include "hls_long_tail_instantiate.vh"

//---------------------------------------
//Custom connection module
//---------------------------------------
`include "custom_connection_instantiate.vh"

//---------------------------------------
// HLS with DMA
//---------------------------------------
`include "hls_dma_instantiate.vh"

//---------------------------------------
//XMEM 1 connection
//---------------------------------------
`include "xmem1_conn.vh"

//---------------------------------------
// AP CTRL bus
//---------------------------------------
riscv_ap_ctrl_bus_v1
#(
    .ENABLE_PROFILE  ( ENABLE_PROFILE  ),
    .RV_NUM          ( CORE_NUM        ),
    .RV_CHILD_ID     ( RV_CHILD_ID     ),
    .HLS_PARENT      ( HLS_PARENT      ),
    .HLS_NUM         ( HLS_NUM         ),
    .HLS_ARG_WIDTH   ( HLS_ARG_WIDTH   ),
    .HLS_ARG_VECTOR  ( HLS_ARG_VECTOR  ),
    .HLS_RET_WIDTH   ( HLS_RET_WIDTH   ),
    .HLS_RET_VECTOR  ( HLS_RET_VECTOR  ),
    .XMEM_ADDR_WIDTH ( XMEM_ADDR_WIDTH ),
    .XMEM_DATA_WIDTH ( XMEM_DATA_WIDTH ),
    .ENABLE_XMEM1_RW ( EN_RISCV_XMEM1  )
)
inst_ap_ctrl_bus (
    .clk            ( clk               ),
    .rstn           ( rstn              ),
    .rv_re          ( rv_re             ),
    .rv_we          ( rv_we             ),
    .rv_addr        ( rv_addr           ),
    .rv_wdata       ( rv_wdata          ),
    .rv_ready       ( rv_ready          ),
    .rv_valid       ( rv_valid          ),
    .rv_rdata       ( rv_rdata          ),    
    .ap_rv_req      ( rv_prnt_reqVld_i  ),  //for profiling
    .ap_rv_id       ( rv_prnt_reqChild_i),  //for profiling
    .ap_hls_req     ( ap_hls_req        ),  //for profiling
    .ap_hls_id      ( ap_hls_id         ),  //for profiling
    .ap_hls_retReq  ( ap_hls_retReq     ),  //for profiling
    .ap_hls_retPop  ( ap_hls_retPop     ),  //for profiling
    .ap_arb_start   ( ap_arb_start      ),  //for profiling
    .ap_start       ( ap_start          ),  //for profiling
    .ap_done        ( ap_done           ),  //for profiling
    .ap_busy        ( ap_busy           ),  //for profiling
    .ap_core        ( ap_core           ),  //for profiling
    .ap_dc_ready    ( dc_ready          ),  //for profiling    
    .ap_xmem_ready  ( ap_xmem_ready     ),  //for profiling
    .ap_ret_ready   ( ap_ret_ready      ),  //for profiling    
    .xmem2_rdy      ( 1'b1              ),
    .xmem2_re       (                   ),
    .xmem2_we       ( xcache_cfg        ),
    .xmem2_ad       ( xcache_cfg_ad     ),
    .xmem2_di       ( xcache_cfg_di     ),
    .xmem2_do       ( 32'd0             ),
    .xmem1_rdy      ( xmem1_rdy         ),  //for debug
    .xmem1_re       ( xmem1_re          ),  //for debug
    .xmem1_we       ( xmem1_we          ),  //for debug
    .xmem1_ad       ( xmem1_ad          ),  //for debug
    .xmem1_di       ( xmem1_di          ),  //for debug
    .xmem1_do       ( xmem1_do          ),  //for debug
    .dma_rdy        ( dma_rdy           ),
    .dma_re         ( dma_re            ),
    .dma_we         ( dma_we            ),
    .dma_ad         ( dma_ad            ),
    .dma_di         ( dma_di            ),
    .dma_do         ( dma_do            )
);
always_comb begin
    for (int i = 0; i < HLS_PARENT; i = i + 1) begin
        ap_hls_req   [i] = parent_cmdfifo_write_i[HLS_PARENT_ID + i];
        ap_hls_id    [i] = parent_cmdfifo_din_i[HLS_PARENT_ID + i][CHILD_MOD_MSB:CHILD_MOD_LSB];
        ap_hls_retReq[i] = parent_cmdfifo_din_i[HLS_PARENT_ID + i][RETREQ_BIT];
        ap_hls_retPop[i] = parent_retFifo_pop_i[HLS_PARENT_ID + i] & parent_retFifo_empty_n_o[HLS_PARENT_ID + i];
    end
end


//---------------------------------------
// RISCV XCACHE access bus
//---------------------------------------
riscv_xcache_bus_v1
#(
    .RV_NUM      ( CORE_NUM          ),
    .ADDR_WIDTH  ( XCACHE_ADDR_WIDTH ),
    .DATA_WIDTH  ( XCACHE_DATA_WIDTH ) 
)
inst_riscv_xcache_bus (
    .clk        ( clk             ),
    .rstn       ( rstn            ),
    .rv_part    ( rv_xcache_part  ),
    .rv_re      ( rv_xcache_re    ),
    .rv_we      ( rv_xcache_we    ),
    .rv_addr    ( rv_xcache_addr  ),
    .rv_wdata   ( rv_xcache_wdata ),
    .rv_ready   ( rv_xcache_ready ),
    .rv_valid   ( rv_xcache_valid ),
    .rv_rdata   ( rv_xcache_rdata ),
    .mem_rdy    ( xcache_rdy      ),
    .mem_part   ( xcache_part     ),
    .mem_re     ( xcache_re       ),
    .mem_we     ( xcache_we       ),
    .mem_ad     ( xcache_ad       ),
    .mem_di     ( xcache_di       ),
    .mem_do     ( xcache_do       ),
    .mem_do_vld ( xcache_do_vld   )
);


//---------------------------------------
// Function arbiter
//---------------------------------------
func_arbiter #(
    .PARENT           ( PARENT           ),
    .CHILD            ( CHILD            ),
    .CMD_FIFO_DW      ( CMD_FIFO_DW      ),
    .LOG_PARENT       ( LOG_PARENT       ),
    .LOG_CHILD        ( LOG_CHILD        )
)
inst_func_arbiter (
    .rstn                     ( rstn                     ),
    .clk                      ( clk                      ),
`ifdef FUNC_PARENT_FIFO
    .parent_cmdfifo_din_i     ( parent2_cmdfifo_din_i    ),
    .parent_cmdfifo_full_n_o  ( parent2_cmdfifo_full_n_o ),
    .parent_cmdfifo_write_i   ( parent2_cmdfifo_write_i  ),
`else
    .parent_cmdfifo_din_i     ( parent_cmdfifo_din_i     ),
    .parent_cmdfifo_full_n_o  ( parent_cmdfifo_full_n_o  ),
    .parent_cmdfifo_write_i   ( parent_cmdfifo_write_i   ),
`endif
    .child_ap_ce_o            ( child_ap_ce_o            ),
    .child_ap_done_i          ( child_ap_done_i          ),
    .child_retReq_o           ( child_retReq_o           ),
    .child_rdy_i              ( child_rdy_i              ),
    .child_callVld_o          ( child_callVld_o          ),
    .child_parent_o           ( child_parent_o           ),
    .child_pc_o               ( child_pc_o               ),
    .child_args_o             ( child_args_o             ),
    .xmemStart                (                          ),
    .xmemStartFunc            (                          ),
    .xmemCancel_p1            (                          ),
    .xmemCancel_p2            (                          ),
    .child_retRdy_o           ( child_retRdy_o           ),
    .child_retVld_i           ( child_retVld_i           ),
    .child_retDin_i           ( child_retDin_i           ),
    .child_parentMod_i        ( child_parentMod_i        ),
    .parent_retFifo_pop_i     ( parent_retFifo_pop_i     ),
    .parent_retFifo_empty_n_o ( parent_retFifo_empty_n_o ),
    .parent_retFifo_dout_o    ( parent_retFifo_dout_o    )
);
`ifdef FUNC_PARENT_FIFO
generate
for (genvar p = 0; p < PARENT; p = p + 1) begin : INST_PARENT_FIFO
    wire parent_fifo_empty;
    wire parent_fifo_full;
    register_fifo_v1 #(
        .DEPTH          ( 16          ),
        .DATA_BITS      ( CMD_FIFO_DW ),
        .FULL_THRESHOLD ( 2           )
    )
    inst_parent_fifo (
        .clk   ( clk                        ),
        .rstn  ( rstn                       ),
        .push  ( parent_cmdfifo_write_i [p] ),
        .pop   ( parent2_cmdfifo_write_i[p] ),
        .din   ( parent_cmdfifo_din_i   [p] ),
        .dout  ( parent2_cmdfifo_din_i  [p] ),
        .full  ( parent_fifo_full           ),
        .empty ( parent_fifo_empty          )
    );
    assign parent_cmdfifo_full_n_o[p] = ~parent_fifo_full;
    assign parent2_cmdfifo_write_i[p] = parent2_cmdfifo_full_n_o[p] & ~parent_fifo_empty;
end
endgenerate
`endif

//---------------------------------------
// Function arbiter CHILD connection
//---------------------------------------
always_comb begin
    child_ap_done_i = '{default:'0};
    //HLS (return)
    for (int i = 0; i < HLS_NUM; i = i + 1) begin
        //Child ready
        //*** edward 2024-09-30 ****
        //*** Temporary not support pipelined HLS ***
        //*** To handle pipeline, ap_core/ap_part is must be inputted to HLS to access dcache/xmem ***
        child_rdy_i[i + HLS_CHILD_ID] = ~ap_busy[i];
        //Child return
        child_retVld_i   [i + HLS_CHILD_ID] = ap_done[i] & ap_req_ret[i];
        child_retDin_i   [i + HLS_CHILD_ID] = ap_return[i][0];
        child_parentMod_i[i + HLS_CHILD_ID] = ap_parent[i];
        //Stall HLS if function return arbiter is busy
        ap_ret_ready[i] = child_retRdy_o[i + HLS_CHILD_ID];
    end
    //copyEngine
    //edward 2024-10-10: copyEngine with memset (param[3]=1)
    //edward 2024-10-10: param[4] is used to select dcache core.
    copyEngine_copy_i = 0;
    copyEngine_set_i = 0;
    copyEngine_setVal_i = child_args_o[1*32 +: 32];
    copyEngine_run = copyEngine_run_r;
    copyEngine_len_i = child_args_o[0*32 +: 32];
    copyEngine_src_i = child_args_o[1*32 +: 32];
    copyEngine_dst_i = child_args_o[2*32 +: 32];
    copyEngine_parent = copyEngine_parent_r;
    copyEngine_core = copyEngine_core_r;
    copyEngine_ret = copyEngine_ret_r;
    child_rdy_i       [CPY_CHILD_ID] = copyEngine_done_o;
    child_retVld_i    [CPY_CHILD_ID] = 0;
    child_retDin_i    [CPY_CHILD_ID] = 1;
    child_parentMod_i [CPY_CHILD_ID] = copyEngine_parent_r;
    if (copyEngine_run_r && copyEngine_done_o) begin
        copyEngine_run    = 0;
        child_retVld_i   [CPY_CHILD_ID] = copyEngine_ret_r;
    end
    if (child_callVld_o[CPY_CHILD_ID] && ~copyEngine_run && copyEngine_done_o) begin
        copyEngine_copy_i = ~child_args_o[3*32];
        copyEngine_set_i  = child_args_o[3*32];
        copyEngine_parent = child_parent_o;
        copyEngine_core   = child_args_o[4*32 +: 32];
        copyEngine_ret    = child_retReq_o;
        copyEngine_run    = 1;
    end
    //Commander
    df_chld_reqParent_o = child_parent_o;
    df_chld_reqPc_o     = child_pc_o;
    df_chld_reqArgs_o   = child_args_o;
    df_chld_reqReturn_o = child_retReq_o;
    df_chld_reqVld_o    = child_callVld_o [DF_CHILD_ID];
    df_chld_retRdy_o    = child_retRdy_o  [DF_CHILD_ID];
    child_rdy_i      [DF_CHILD_ID] = df_chld_reqRdy_i;
    child_retVld_i   [DF_CHILD_ID] = df_chld_retVld_i;
    child_parentMod_i[DF_CHILD_ID] = df_chld_retParent_i;
    child_retDin_i   [DF_CHILD_ID] = df_chld_retDat_i;
    //Riscv is child
    for (int i = 0; i < CORE_NUM; i = i + 1) begin
        //riscv connected to CHILD (riscv is child)
        rv_chld_reqParent_o[i] = child_parent_o;
        rv_chld_reqPc_o    [i] = child_pc_o;
        rv_chld_reqArgs_o  [i] = child_args_o;
        rv_chld_reqReturn_o[i] = child_retReq_o;
        rv_chld_reqVld_o   [i] = child_callVld_o [RV_CHILD_ID + i];
        rv_chld_retRdy_o   [i] = child_retRdy_o  [RV_CHILD_ID + i];
        child_rdy_i      [RV_CHILD_ID + i] = rv_chld_reqRdy_i[i];
        child_retVld_i   [RV_CHILD_ID + i] = rv_chld_retVld_i[i];
        child_parentMod_i[RV_CHILD_ID + i] = rv_chld_retParent_i[i];
        child_retDin_i   [RV_CHILD_ID + i] = rv_chld_retDat_i[i];
    end

end
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        ap_arb_start        <= '{default:'0};
        ap_arb_ret          <= '{default:'0};
        ap_parent           <= '{default:'0};
        ap_req_ret          <= '{default:'0};
        ap_core             <= '{default:'0};
        ap_part             <= '{default:'0};
        ap_busy             <= '{default:'0};
        ap_arb_start_r      <= '{default:'0};
        copyEngine_parent_r <= 0;
        copyEngine_run_r    <= 0;
        copyEngine_core_r   <= 0;
        copyEngine_ret_r    <= 0;        
    end
    else begin
        ap_arb_start_r <= ap_arb_start;
        //HLS ap start
        //edward 2024-09-30: busy signal used for function arbiter.
        for (int i = 0; i < HLS_NUM; i = i + 1) begin
            if (child_callVld_o[i + HLS_CHILD_ID] & child_rdy_i[i + HLS_CHILD_ID]) begin
                ap_arb_start[i] <= 1;
                ap_busy     [i] <= 1;
                ap_parent   [i][LOG_PARENT-1:0] <= child_parent_o;
                //For HLS-HLS intercall, PC is used as core id and xmem partition.
                ap_core     [i][CORE_NUM_BIT-1:0] <= child_pc_o[7:0] - START_CORE;
                ap_part     [i][LOG2_MAX_PARTITION-1:0] <= child_pc_o[15:8];
                ap_req_ret  [i] <= child_retReq_o;
                for (int j = 0; j < ARG_NUM; j = j + 1) begin
                    ap_arg[i][j] <= child_args_o[j * 32 +: 32];
                end
            end
            else begin
                if (ap_ready[i]) begin
                    ap_arb_start[i] <= 0;
                end
                if (ap_done[i]) begin
                    ap_busy[i] <= 0;
                end
            end
        end
        //edward 2024-10-24: Return from child to ask custom_connection to re-read parent xmem that may be updated by child.
        //edward 2024-11-04: Only ask custom_connection to re-read if request return.
        ap_arb_ret <= '{default:'0};
        for (int i = 0; i < HLS_NUM; i = i + 1) begin
            if (ap_done[i] && ap_ce[i] && (ap_parent[i] >= HLS_PARENT_ID) && ap_req_ret[i]) begin
                ap_arb_ret[HLS_PARENT_IDX[ap_parent[i] - HLS_PARENT_ID]] <= 1;
            end
`ifdef CUSTOM_CONN_RELOAD_TEST
            if (rand_reload[i] & ~ap_idle[i] & ~ap_ready[i] & ~ap_done[i]) begin
                ap_arb_ret[HLS_PARENT_IDX[ap_parent[i] - HLS_PARENT_ID]] <= 1;
            end
`endif
        end
        //CopyEngine
        copyEngine_parent_r <= copyEngine_parent;
        copyEngine_run_r    <= copyEngine_run;
        copyEngine_core_r   <= copyEngine_core;
        copyEngine_ret_r    <= copyEngine_ret;
    end
end

//---------------------------------------
// CopyEngine cache connection
//---------------------------------------
always_comb begin
`ifdef HLS_RISCV_L1CACHE
    for (int i = 0; i < CORE_NUM; i = i + 1) begin
        //Output
        cpEng_dc_re  [i] = (copyEngine_core_r == i)? copyEngine_mem_re_r : 0;
        cpEng_dc_rad [i] = {copyEngine_mem_rad_r,2'b0};
        cpEng_dc_bwe [i] = (copyEngine_core_r == i)? copyEngine_mem_bwe_r : 0;
        cpEng_dc_wad [i] = {copyEngine_mem_wad_r,2'b0};
        cpEng_dc_wdat[i] = copyEngine_mem_wdat_r;
        //Input
        copyEngine_mem_rreq_rdy = cpEng_dc_rrdy    [copyEngine_core_r];
        copyEngine_mem_rdat     = cpEng_dc_rdat    [copyEngine_core_r];
        copyEngine_mem_rdat_rdy = cpEng_dc_rdat_vld[copyEngine_core_r];
        copyEngine_mem_wreq_rdy = cpEng_dc_wrdy    [copyEngine_core_r];
    end
`else `ifdef HLS_LOCAL_DCACHE
    //Output
    cpEng_dc_re   = copyEngine_mem_re_r;
    cpEng_dc_rad  = {copyEngine_mem_rad_r,2'b0};
    cpEng_dc_bwe  = copyEngine_mem_bwe_r;
    cpEng_dc_wad  = {copyEngine_mem_wad_r,2'b0};
    cpEng_dc_wdat = copyEngine_mem_wdat_r;
    //Input
    copyEngine_mem_rreq_rdy = cpEng_dc_rrdy;
    copyEngine_mem_rdat     = cpEng_dc_rdat;
    copyEngine_mem_rdat_rdy = cpEng_dc_rdat_vld;
    copyEngine_mem_wreq_rdy = cpEng_dc_wrdy;
`else
    //TODO: connect copyEngine to xcache?
    copyEngine_mem_rreq_rdy = 0;
    copyEngine_mem_rdat     = 0;
    copyEngine_mem_rdat_rdy = 0;
    copyEngine_mem_wreq_rdy = 0;
`endif `endif
end

//---------------------------------------
// CopyEngine
//---------------------------------------
copyEngine  #(
    .DATA_WIDTH     ( 64                       ),
    .ADDR_WIDTH     ( 32                       ),
    .LEN            ( 32                       ),
    .FULL_WORD_SIZE ( 64 / 8                   )
) copyEngine (
    .rstn           ( rstn                     ),
    .clk            ( clk                      ),
    .src_dw_sel_i   ( 1'b0                     ),
    .dst_dw_sel_i   ( 1'b0                     ),
    .copy_i         ( copyEngine_copy_i        ),
    .set_i          ( copyEngine_set_i         ),
    .setVal_i       ( copyEngine_setVal_i      ),
    .flush_i        ( 1'b0                     ),
    .len_i          ( copyEngine_len_i         ),
    .src_i          ( copyEngine_src_i         ),
    .dst_i          ( copyEngine_dst_i         ),
    .done_o         ( copyEngine_done_o        ),
    .mem_re_r       ( copyEngine_mem_re_r      ),
    .mem_rad_r      ( copyEngine_mem_rad_r     ),
    .mem_rreq_rdy   ( copyEngine_mem_rreq_rdy  ),
    .mem_rdat       ( copyEngine_mem_rdat      ),
    .mem_rdat_rdy   ( copyEngine_mem_rdat_rdy  ),
    .mem_bwe_r      ( copyEngine_mem_bwe_r     ),
    .mem_wad_r      ( copyEngine_mem_wad_r     ),
    .mem_wdat_r     ( copyEngine_mem_wdat_r    ),
    .mem_wreq_rdy   ( copyEngine_mem_wreq_rdy  ),
    .flush_r        (                          ),
    .cmd_adr_r      (                          ),
    .cmd_rdy        ( 1'b0                     )
);

//---------------------------------------
// Dcache Interface
//---------------------------------------
`ifdef HLS_RISCV_L1CACHE
assign hls_user_rdy             = dcArb_hls_user_rdy;
assign dcArb_hls_user_re        = hls_user_re;
assign dcArb_hls_user_we        = hls_user_we;
assign dcArb_hls_user_we_mask   = hls_user_we_mask;
assign dcArb_hls_user_adr       = hls_user_adr;
assign dcArb_hls_user_wdat      = hls_user_wdat;
assign dcArb_hls_user_csr_flush = '{default:'0};
assign hls_user_rdat            = dcArb_hls_user_rdat;
assign hls_user_rdat_vld        = dcArb_hls_user_rdat_vld;
`else `ifdef HLS_LOCAL_DCACHE
assign hls_user_rdy             = dcArb_hls_user_rdy;
assign dcArb_hls_user_ap_ce     = hls_user_ap_ce;
assign dcArb_hls_user_re        = hls_user_re;
assign dcArb_hls_user_we        = hls_user_we;
assign dcArb_hls_user_we_mask   = hls_user_we_mask;
assign dcArb_hls_user_adr       = hls_user_adr;
assign dcArb_hls_user_wdat      = hls_user_wdat;
assign dcArb_hls_user_csr_flush = '{default:'0};
assign hls_user_rdat            = dcArb_hls_user_rdat;
assign hls_user_rdat_vld        = dcArb_hls_user_rdat_vld;
`else
assign hls_user_rdy             = '{default:1'b1};
assign hls_user_rdat            = '{default:'0};
assign hls_user_rdat_vld        = '{default:'0};
`endif `endif
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        dc_lock_req <= '{default:0};
        dc_locking  <= '{default:0};
        dc_lock_id  <= '{default:0};
    end
    else begin
`ifdef HLS_RISCV_L1CACHE
        for (int j = 0; j < HLS_NUM; j = j + 1) begin
            //Automatically lock at ap_arb_start
            if (dc_enable[j] & ap_arb_start[j] & ~ap_arb_start_r[j]) begin
                dc_lock_req[j] <= 1;
                //Also, unlock parent
                if (ap_req_ret[j] && ap_parent[j] >= HLS_PARENT_ID && dc_enable[HLS_PARENT_IDX[ap_parent[j]-HLS_PARENT_ID]]) begin
                    dc_lock_req[HLS_PARENT_IDX[ap_parent[j]-HLS_PARENT_ID]] <= 0;
                end
            end
            //Automatically unlock at ap_done
            else if (dc_enable[j] & ap_done[j]) begin
                dc_lock_req[j] <= 0;
                //Also, re-lock parent
                if (ap_req_ret[j] && ap_parent[j] >= HLS_PARENT_ID && dc_enable[HLS_PARENT_IDX[ap_parent[j]-HLS_PARENT_ID]]) begin
                    dc_lock_req[HLS_PARENT_IDX[ap_parent[j]-HLS_PARENT_ID]] <= 1;
                end
            end
            //Manually lock
            else if (dc_lock_set[j]) begin
                dc_lock_req[j] <= 1;
            end
            //Manually unlock
            else if (dc_lock_clr[j]) begin
                dc_lock_req[j] <= 0;
            end
        end
        //Lock and Unlock Arbiter
        for (int j = 0; j < CORE_NUM; j = j + 1) begin
            if (~dc_locking[j]) begin
                for (int i = 0; i < HLS_NUM; i = i + 1) begin
                    if (dc_lock_req[i] && ap_core[i] == j) begin
                        dc_locking[j] <= 1;
                        dc_lock_id[j] <= i;
                    end
                end
            end
            else if (dc_locking[j] & ~dc_lock_req[dc_lock_id[j]]) begin
                dc_locking[j] <= 0;
            end
        end
`else
        dc_lock_req <= '{default:0};
        dc_locking  <= '{default:0};
        dc_lock_id  <= '{default:0};
`endif
    end
end

//---------------------------------------
// DecodeBin Interface
//---------------------------------------
always_ff @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        decBin_ctx <= '{default:'0};
        decBin_get <= '{default:'0};
        decBin_sel <= '{default:'0};
    end
    else begin
        for (int i = 0; i < CORE_NUM; i = i + 1) begin
            //edward 2024-11-22: fixed if decBin_rdy=0 & decBin_get_c=1
            //if (decBin_rdy[i]) begin
            if (decBin_rdy_c[i]) begin
                decBin_get[i] <= decBin_get_c[i];
                decBin_ctx[i] <= decBin_ctx_c[i];
                decBin_sel[i] <= decBin_sel_c[i];
            end
        end
    end
end
always_comb begin
    for (int i = 0; i < CORE_NUM; i = i + 1) begin
        decBin_rdy_c[i] = decBin_rdy[i] | ~decBin_get[i];
    end
end

//---------------------------------------
// XCACHE
//---------------------------------------
xcache #(
    .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH ),
    .AXI_LEN_WIDTH  ( AXI_LEN_WIDTH  ),
    .AXI_ID_WIDTH   ( AXI_ID_WIDTH   )
)
inst_xcache(
    .clk                 ( clk                     ),
    .rstn                ( rstn                    ),
    //risc configure interface   
    .risc_cfg            ( xcache_cfg[0]           ),
    .risc_cfg_adr        ( xcache_cfg_ad           ),
    .risc_cfg_di         ( xcache_cfg_di           ),
    //risc interface   
    .risc_part           ( xcache_part             ),
    .risc_we             ( xcache_we               ),
    .risc_re             ( xcache_re               ),
    .risc_adr            ( xcache_ad               ),
    .risc_di             ( xcache_di               ),
    .risc_do_vld         ( xcache_do_vld           ),
    .risc_do             ( xcache_do               ),
    .risc_rdy            ( xcache_rdy              ),
    //For dualport bank (SCALAR range)
    .scalar_argVld       ( scalar_argVld           ),   //i
    .scalar_argAck       ( scalar_argAck           ),   //o
    .scalar_adr          ( scalar_adr              ),   //i
    .scalar_wdat         ( scalar_wdat             ),   //i
    .scalar_rdat         ( scalar_rdat             ),   //o
    .scalar_rdat_vld     ( scalar_rdat_vld         ),   //o
    //For single port bank (ARRAY range)
    .array_argRdy        ( array_argRdy            ),   //o
    .array_ap_ce         ( array_ap_ce             ),   //i
    .array_argVld        ( array_argVld            ),   //i
    .array_argAck        ( array_argAck            ),   //o
    .array_adr           ( array_adr               ),   //i
    .array_wdat          ( array_wdat              ),   //i
    .array_rdat          ( array_rdat              ),   //o
    .array_rdat_vld      ( array_rdat_vld          ),   //o
    //For cyclic port bank (CYCLIC range)
    .cyclic_argRdy       ( cyclic_argRdy           ),   //o
    .cyclic_ap_ce        ( cyclic_ap_ce            ),   //i
    .cyclic_argVld       ( cyclic_argVld           ),   //i
    .cyclic_argAck       ( cyclic_argAck           ),   //o
    .cyclic_adr          ( cyclic_adr              ),   //i
    .cyclic_wdat         ( cyclic_wdat             ),   //i
    .cyclic_rdat         ( cyclic_rdat             ),   //o
    .cyclic_rdat_vld     ( cyclic_rdat_vld         ),   //o
    //AXI4 for array bank
    .axi_awready         ( xcache_axi_awready  [0] ),
    .axi_awvalid         ( xcache_axi_awvalid  [0] ),
    .axi_awaddr          ( xcache_axi_awaddr   [0] ),
    .axi_awlen           ( xcache_axi_awlen    [0] ),
    .axi_awid            ( xcache_axi_awid     [0] ),
    .axi_awsize          ( xcache_axi_awsize   [0] ),
    .axi_awburst         ( xcache_axi_awburst  [0] ),
    .axi_awlock          ( xcache_axi_awlock   [0] ),
    .axi_awcache         ( xcache_axi_awcache  [0] ),
    .axi_awprot          ( xcache_axi_awprot   [0] ),
    .axi_awqos           ( xcache_axi_awqos    [0] ),
    .axi_awregion        ( xcache_axi_awregion [0] ),
    .axi_awuser          ( xcache_axi_awuser   [0] ),
    .axi_wready          ( xcache_axi_wready   [0] ),
    .axi_wvalid          ( xcache_axi_wvalid   [0] ),
    .axi_wdata           ( xcache_axi_wdata    [0] ),
    .axi_wstrb           ( xcache_axi_wstrb    [0] ),
    .axi_wlast           ( xcache_axi_wlast    [0] ),
    .axi_wid             ( xcache_axi_wid      [0] ),
    .axi_wuser           ( xcache_axi_wuser    [0] ),
    .axi_bready          ( xcache_axi_bready   [0] ),
    .axi_bvalid          ( xcache_axi_bvalid   [0] ),
    .axi_bresp           ( xcache_axi_bresp    [0] ),
    .axi_bid             ( xcache_axi_bid      [0] ),
    .axi_buser           ( xcache_axi_buser    [0] ),
    .axi_arready         ( xcache_axi_arready  [0] ),
    .axi_arvalid         ( xcache_axi_arvalid  [0] ),
    .axi_araddr          ( xcache_axi_araddr   [0] ),
    .axi_arlen           ( xcache_axi_arlen    [0] ),
    .axi_arid            ( xcache_axi_arid     [0] ),
    .axi_arsize          ( xcache_axi_arsize   [0] ),
    .axi_arburst         ( xcache_axi_arburst  [0] ),
    .axi_arlock          ( xcache_axi_arlock   [0] ),
    .axi_arcache         ( xcache_axi_arcache  [0] ),
    .axi_arprot          ( xcache_axi_arprot   [0] ),
    .axi_arqos           ( xcache_axi_arqos    [0] ),
    .axi_arregion        ( xcache_axi_arregion [0] ),
    .axi_aruser          ( xcache_axi_aruser   [0] ),
    .axi_rready          ( xcache_axi_rready   [0] ),
    .axi_rvalid          ( xcache_axi_rvalid   [0] ),
    .axi_rdata           ( xcache_axi_rdata    [0] ),
    .axi_rlast           ( xcache_axi_rlast    [0] ),
    .axi_rresp           ( xcache_axi_rresp    [0] ),
    .axi_rid             ( xcache_axi_rid      [0] ),
    .axi_ruser           ( xcache_axi_ruser    [0] ),
    //AXI4 for cyclic bank
    .axi_awready_1       ( xcache_axi_awready  [1] ),
    .axi_awvalid_1       ( xcache_axi_awvalid  [1] ),
    .axi_awaddr_1        ( xcache_axi_awaddr   [1] ),
    .axi_awlen_1         ( xcache_axi_awlen    [1] ),
    .axi_awid_1          ( xcache_axi_awid     [1] ),
    .axi_awsize_1        ( xcache_axi_awsize   [1] ),
    .axi_awburst_1       ( xcache_axi_awburst  [1] ),
    .axi_awlock_1        ( xcache_axi_awlock   [1] ),
    .axi_awcache_1       ( xcache_axi_awcache  [1] ),
    .axi_awprot_1        ( xcache_axi_awprot   [1] ),
    .axi_awqos_1         ( xcache_axi_awqos    [1] ),
    .axi_awregion_1      ( xcache_axi_awregion [1] ),
    .axi_awuser_1        ( xcache_axi_awuser   [1] ),
    .axi_wready_1        ( xcache_axi_wready   [1] ),
    .axi_wvalid_1        ( xcache_axi_wvalid   [1] ),
    .axi_wdata_1         ( xcache_axi_wdata    [1] ),
    .axi_wstrb_1         ( xcache_axi_wstrb    [1] ),
    .axi_wlast_1         ( xcache_axi_wlast    [1] ),
    .axi_wid_1           ( xcache_axi_wid      [1] ),
    .axi_wuser_1         ( xcache_axi_wuser    [1] ),
    .axi_bready_1        ( xcache_axi_bready   [1] ),
    .axi_bvalid_1        ( xcache_axi_bvalid   [1] ),
    .axi_bresp_1         ( xcache_axi_bresp    [1] ),
    .axi_bid_1           ( xcache_axi_bid      [1] ),
    .axi_buser_1         ( xcache_axi_buser    [1] ),
    .axi_arready_1       ( xcache_axi_arready  [1] ),
    .axi_arvalid_1       ( xcache_axi_arvalid  [1] ),
    .axi_araddr_1        ( xcache_axi_araddr   [1] ),
    .axi_arlen_1         ( xcache_axi_arlen    [1] ),
    .axi_arid_1          ( xcache_axi_arid     [1] ),
    .axi_arsize_1        ( xcache_axi_arsize   [1] ),
    .axi_arburst_1       ( xcache_axi_arburst  [1] ),
    .axi_arlock_1        ( xcache_axi_arlock   [1] ),
    .axi_arcache_1       ( xcache_axi_arcache  [1] ),
    .axi_arprot_1        ( xcache_axi_arprot   [1] ),
    .axi_arqos_1         ( xcache_axi_arqos    [1] ),
    .axi_arregion_1      ( xcache_axi_arregion [1] ),
    .axi_aruser_1        ( xcache_axi_aruser   [1] ),
    .axi_rready_1        ( xcache_axi_rready   [1] ),
    .axi_rvalid_1        ( xcache_axi_rvalid   [1] ),
    .axi_rdata_1         ( xcache_axi_rdata    [1] ),
    .axi_rlast_1         ( xcache_axi_rlast    [1] ),
    .axi_rresp_1         ( xcache_axi_rresp    [1] ),
    .axi_rid_1           ( xcache_axi_rid      [1] ),
    .axi_ruser_1         ( xcache_axi_ruser    [1] )
);

endmodule
