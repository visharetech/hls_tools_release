`timescale 1ns/100ps

`include "csv_parser.vh"

//param_list = ${param_list}

module tb_top ${param_list} ();

localparam offset_ret      = -1;
localparam width_ret       = 32;
localparam START_CORE      = 0;
localparam CORE_NUM        = 1;
localparam ENABLE_DMA      = 1;
localparam ENABLE_PROFILE  = 0;
localparam EN_RISCV_XMEM1  = 0;
localparam AXI_ADDR_WIDTH  = 32;
localparam AXI_DATA_WIDTH  = 256;
localparam AXI_LEN_WIDTH   = 8;
localparam AXI_ID_WIDTH    = 8;
localparam AXI_STRB_WIDTH  = AXI_DATA_WIDTH / 8;
localparam AXI2_ADDR_WIDTH = 32;
localparam AXI2_DATA_WIDTH = 256;
localparam AXI2_LEN_WIDTH  = 8;
localparam AXI2_ID_WIDTH   = 8;
localparam AXI2_STRB_WIDTH = AXI2_DATA_WIDTH / 8;
`ifndef HLS_LOCAL_DCACHE
localparam DC_PORTS        = CORE_NUM * 3;
`else
localparam DC_PORTS        = HLS_CACHE + 2;
`endif
localparam DC_SIZE         = 32 * 1024 * 1024;   //Cache byte size per core

//Module IO Ports
logic                           clk;
logic                           rstn;
//Riscv core
logic                           rv_re                   [CORE_NUM];
logic [3:0]                     rv_we                   [CORE_NUM];
logic [31 : 0]                  rv_addr                 [CORE_NUM];
logic [31 : 0]                  rv_wdata                [CORE_NUM];
logic                           rv_ready                [CORE_NUM];
logic                           rv_valid                [CORE_NUM];
logic [31 : 0]                  rv_rdata                [CORE_NUM];
//Riscv core (xcache content access)
logic [7:0]                     rv_xcache_part          [CORE_NUM];
logic                           rv_xcache_re            [CORE_NUM];
logic [3:0]                     rv_xcache_we            [CORE_NUM];
logic [31 : 0]                  rv_xcache_addr          [CORE_NUM];
logic [31 : 0]                  rv_xcache_wdata         [CORE_NUM];
logic                           rv_xcache_ready         [CORE_NUM];
logic                           rv_xcache_valid         [CORE_NUM];
logic [31 : 0]                  rv_xcache_rdata         [CORE_NUM];
//Riscv -> HLS function arbiter (RISCV is Parent)
logic                           rv_prnt_reqRdy_o        [CORE_NUM];
logic                           rv_prnt_reqVld_i        [CORE_NUM];
logic [31 : 0]                  rv_prnt_reqChild_i      [CORE_NUM];
logic [31 : 0]                  rv_prnt_reqPc_i         [CORE_NUM];
logic [255 : 0]                 rv_prnt_reqArgs_i       [CORE_NUM];
logic                           rv_prnt_reqReturn_i     [CORE_NUM];
logic                           rv_prnt_retRdy_i        [CORE_NUM];
logic                           rv_prnt_retVld_o        [CORE_NUM];
logic [31 : 0]                  rv_prnt_retChild_o      [CORE_NUM];
logic [31 : 0]                  rv_prnt_retDat_o        [CORE_NUM];
//Riscv -> HLS function arbiter (RISCV is Child)
logic                           rv_chld_reqRdy_i        [CORE_NUM];
logic                           rv_chld_reqVld_o        [CORE_NUM];
logic [31 : 0]                  rv_chld_reqParent_o     [CORE_NUM];
logic [255 : 0]                 rv_chld_reqArgs_o       [CORE_NUM];
logic [31 : 0]                  rv_chld_reqPc_o         [CORE_NUM];
logic                           rv_chld_reqReturn_o     [CORE_NUM];
logic                           rv_chld_retRdy_o        [CORE_NUM];
logic                           rv_chld_retVld_i        [CORE_NUM];
logic [31 : 0]                  rv_chld_retParent_i     [CORE_NUM];
logic [31 : 0]                  rv_chld_retDat_i        [CORE_NUM];
//Function arbiter (Longtail HLS is parent)
logic                           df_chld_reqRdy_i;
logic                           df_chld_reqVld_o;
logic [31 : 0]                  df_chld_reqParent_o;
logic [255 : 0]                 df_chld_reqArgs_o;
logic [31 : 0]                  df_chld_reqPc_o;
logic                           df_chld_reqReturn_o;
logic                           df_chld_retRdy_o;
logic                           df_chld_retVld_i;
logic [31 : 0]                  df_chld_retParent_i;
logic [31 : 0]                  df_chld_retDat_i;
`ifndef HLS_LOCAL_DCACHE
//connecting to dcache use interface arbiter
logic                           dcArb_hls_user_rdy      [CORE_NUM];
logic                           dcArb_hls_user_re       [CORE_NUM];
logic                           dcArb_hls_user_we       [CORE_NUM];
logic [3  : 0]                  dcArb_hls_user_we_mask  [CORE_NUM];
logic [31 : 0]                  dcArb_hls_user_adr      [CORE_NUM];
logic [31 : 0]                  dcArb_hls_user_wdat     [CORE_NUM];
logic                           dcArb_hls_user_csr_flush[CORE_NUM];
logic [31 : 0]                  dcArb_hls_user_rdat     [CORE_NUM];
logic                           dcArb_hls_user_rdat_vld [CORE_NUM];
//Copy Engine to dacache
logic                           cpEng_dc_re             [CORE_NUM];
logic [31 : 0]                  cpEng_dc_rad            [CORE_NUM];
logic                           cpEng_dc_rrdy           [CORE_NUM];
logic [31 : 0]                  cpEng_dc_rdat           [CORE_NUM];
logic                           cpEng_dc_rdat_vld       [CORE_NUM];
logic [3 : 0]                   cpEng_dc_bwe            [CORE_NUM];
logic [31 : 0]                  cpEng_dc_wad            [CORE_NUM];
logic [31 : 0]                  cpEng_dc_wdat           [CORE_NUM];
logic                           cpEng_dc_wrdy           [CORE_NUM];
`else
//connecting to dcache use interface arbiter
logic                           dcArb_hls_user_rdy      [HLS_CACHE];
logic                           dcArb_hls_user_ap_ce    [HLS_CACHE];
logic                           dcArb_hls_user_re       [HLS_CACHE];
logic                           dcArb_hls_user_we       [HLS_CACHE];
logic [3  : 0]                  dcArb_hls_user_we_mask  [HLS_CACHE];
logic [31 : 0]                  dcArb_hls_user_adr      [HLS_CACHE];
logic [31 : 0]                  dcArb_hls_user_wdat     [HLS_CACHE];
logic                           dcArb_hls_user_csr_flush[HLS_CACHE];
logic [31 : 0]                  dcArb_hls_user_rdat     [HLS_CACHE];
logic                           dcArb_hls_user_rdat_vld [HLS_CACHE];
//Copy Engine to dacache
logic                           cpEng_dc_re;
logic [31 : 0]                  cpEng_dc_rad;
logic                           cpEng_dc_rrdy;
logic [31 : 0]                  cpEng_dc_rdat;
logic                           cpEng_dc_rdat_vld;
logic [3 : 0]                   cpEng_dc_bwe;
logic [31 : 0]                  cpEng_dc_wad;
logic [31 : 0]                  cpEng_dc_wdat;
logic                           cpEng_dc_wrdy;
`endif
//DecodeBin
logic [CABAC_NUM_BITS - 1 : 0]  decBin_sel              [CORE_NUM];
logic [ 8 : 0]                  decBin_ctx              [CORE_NUM];
logic                           decBin_get              [CORE_NUM];
logic                           decBin_rdy              [CORE_NUM];
logic                           decBin_bin              [CORE_NUM];
logic                           decBin_vld              [CORE_NUM];
//Xmem access from dataflow HLS
logic                           hls_xmem1_rdy0          [CORE_NUM];
logic                           hls_xmem1_ce0           [CORE_NUM];
logic [ 7 : 0]                  hls_xmem1_we0           [CORE_NUM];
logic [31 : 0]                  hls_xmem1_address0      [CORE_NUM];
logic [63 : 0]                  hls_xmem1_d0            [CORE_NUM];
//Dataflow interface
logic                           dataflow_rdy;
logic                           dataflow_re;
logic                           dataflow_we;
logic [MPORT_ADDR_WIDTH-1:0]    dataflow_addr;
logic [MPORT_STRB_WIDTH-1:0]    dataflow_strb;
logic [MPORT_DATA_WIDTH-1:0]    dataflow_din;
logic                           dataflow_dout_vld;
logic [MPORT_DATA_WIDTH-1:0]    dataflow_dout;
logic                           dataflow_flush;
logic [MPORT_ADDR_WIDTH-1:0]    dataflow_flush_cnt;
//AXI4 interface (write channel) for DMA
logic                           dma_axi_awready;
logic                           dma_axi_awvalid;
logic [AXI_ADDR_WIDTH-1 : 0]    dma_axi_awaddr;
logic [AXI_LEN_WIDTH-1 : 0]     dma_axi_awlen;
logic [AXI_ID_WIDTH-1 : 0]      dma_axi_awid;
logic [2 : 0]                   dma_axi_awsize;
logic [1 : 0]                   dma_axi_awburst;
logic                           dma_axi_awlock;
logic [3 : 0]                   dma_axi_awcache;
logic [2 : 0]                   dma_axi_awprot;
logic [3 : 0]                   dma_axi_awqos;
logic [3 : 0]                   dma_axi_awregion;
logic                           dma_axi_awuser;
logic                           dma_axi_wready;
logic                           dma_axi_wvalid;
logic [AXI_DATA_WIDTH - 1 : 0]  dma_axi_wdata;
logic [AXI_STRB_WIDTH - 1 : 0]  dma_axi_wstrb;
logic                           dma_axi_wlast;
logic [AXI_ID_WIDTH-1 : 0]      dma_axi_wid;
logic                           dma_axi_wuser;
logic                           dma_axi_bready;
logic                           dma_axi_bvalid;
logic [1 : 0]                   dma_axi_bresp;
logic [AXI_ID_WIDTH-1 : 0]      dma_axi_bid;
logic                           dma_axi_buser;
//AXI4 interface (read channel) for DMA
logic                           dma_axi_arready;
logic                           dma_axi_arvalid;
logic [AXI_ADDR_WIDTH-1 : 0]    dma_axi_araddr;
logic [AXI_LEN_WIDTH-1 : 0]     dma_axi_arlen;
logic [AXI_ID_WIDTH-1 : 0]      dma_axi_arid;
logic [2 : 0]                   dma_axi_arsize;
logic [1 : 0]                   dma_axi_arburst;
logic                           dma_axi_arlock;
logic [3 : 0]                   dma_axi_arcache;
logic [2 : 0]                   dma_axi_arprot;
logic [3 : 0]                   dma_axi_arqos;
logic [3 : 0]                   dma_axi_arregion;
logic                           dma_axi_aruser;
logic                           dma_axi_rvalid;
logic                           dma_axi_rready;
logic [AXI_DATA_WIDTH-1 : 0]    dma_axi_rdata;
logic                           dma_axi_rlast;
logic [1 : 0]                   dma_axi_rresp;
logic [AXI_ID_WIDTH-1 : 0]      dma_axi_rid;
logic                           dma_axi_ruser;
//AXI4 interface (write channel) for xcache
logic                           xcache_axi_awready [2];
logic                           xcache_axi_awvalid [2];
logic [AXI2_ADDR_WIDTH-1 : 0]   xcache_axi_awaddr  [2];
logic [AXI2_LEN_WIDTH-1 : 0]    xcache_axi_awlen   [2];
logic [AXI2_ID_WIDTH-1 : 0]     xcache_axi_awid    [2];
logic [2 : 0]                   xcache_axi_awsize  [2];
logic [1 : 0]                   xcache_axi_awburst [2];
logic                           xcache_axi_awlock  [2];
logic [3 : 0]                   xcache_axi_awcache [2];
logic [2 : 0]                   xcache_axi_awprot  [2];
logic [3 : 0]                   xcache_axi_awqos   [2];
logic [3 : 0]                   xcache_axi_awregion[2];
logic                           xcache_axi_awuser  [2];
logic                           xcache_axi_wready  [2];
logic                           xcache_axi_wvalid  [2];
logic [AXI2_DATA_WIDTH - 1 : 0] xcache_axi_wdata   [2];
logic [AXI2_STRB_WIDTH - 1 : 0] xcache_axi_wstrb   [2];
logic                           xcache_axi_wlast   [2];
logic [AXI2_ID_WIDTH-1 : 0]     xcache_axi_wid     [2];
logic                           xcache_axi_wuser   [2];
logic                           xcache_axi_bready  [2];
logic                           xcache_axi_bvalid  [2];
logic [1 : 0]                   xcache_axi_bresp   [2];
logic [AXI2_ID_WIDTH-1 : 0]     xcache_axi_bid     [2];
logic                           xcache_axi_buser   [2];
//AXI4 interface (read channel) for xcache
logic                           xcache_axi_arready [2];
logic                           xcache_axi_arvalid [2];
logic [AXI2_ADDR_WIDTH-1 : 0]   xcache_axi_araddr  [2];
logic [AXI2_LEN_WIDTH-1 : 0]    xcache_axi_arlen   [2];
logic [AXI2_ID_WIDTH-1 : 0]     xcache_axi_arid    [2];
logic [2 : 0]                   xcache_axi_arsize  [2];
logic [1 : 0]                   xcache_axi_arburst [2];
logic                           xcache_axi_arlock  [2];
logic [3 : 0]                   xcache_axi_arcache [2];
logic [2 : 0]                   xcache_axi_arprot  [2];
logic [3 : 0]                   xcache_axi_arqos   [2];
logic [3 : 0]                   xcache_axi_arregion[2];
logic                           xcache_axi_aruser  [2];
logic                           xcache_axi_rvalid  [2];
logic                           xcache_axi_rready  [2];
logic [AXI2_DATA_WIDTH-1 : 0]   xcache_axi_rdata   [2];
logic                           xcache_axi_rlast   [2];
logic [1 : 0]                   xcache_axi_rresp   [2];
logic [AXI2_ID_WIDTH-1 : 0]     xcache_axi_rid     [2];
logic                           xcache_axi_ruser   [2];
//Testbench
logic                           dc_ap_ce   [DC_PORTS];
logic                           dc_ready   [DC_PORTS];
logic [31 : 0]                  dc_address0[DC_PORTS];
logic                           dc_ce0     [DC_PORTS];
logic                           dc_we0     [DC_PORTS];
logic [3 : 0]                   dc_we_mask [DC_PORTS];
logic [31 : 0]                  dc_d0      [DC_PORTS];
logic [31 : 0]                  dc_q0      [DC_PORTS];
logic                           dc_q0_vld  [DC_PORTS];


//Macro to read argument/return from tgcapture
`define GET_VALUE(name, tgIdx, width) \
    tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
    name = dat64;

//Macro to read argument/return from tgcapture
`define GET_AP_ARG(name, tgIdx, width) \
    tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
    name = dat64;

//Macro to read xmem register from tgcapture
`define GET_XM_IN_REG(name, tgIdx, width) \
    tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
    name = dat64; \
    if (width == 64) \
        xmem_write64(offset_``name , name); \
    else \
        xmem_write(offset_``name , name, width); \


//Macro to read xmem register from tgcapture
`define GET_XM_DCACHE_REG(name, tgIdx, offset) \
    tgEmpty |= tg_queue(tgF, 64, tgIdx, dat64); \
    name = dat64; \
    name = dcache_offset;  \
    xmem_write(offset_``name , name, 32); \
    dcache_offset += offset * 4;

//Macro to read xmem register from tgcapture
`define GET_XM_IN_TO_ARR_INDEX_REG(name, tgIdx, arrIndex, width) \
    tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
    name = dat64; \
    if (width == 64) \
        xmem_write64(offset_``name + (arrIndex * width), name); \
    else \
        xmem_write(offset_``name  + (arrIndex * width), name, width); \

//test data consist both input and output data
`define GET_XM_OUT_REG(name, tgIdx, width) \
    `GET_XM_PTR(name, tgIdx, width)
    //tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
    //tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
    //name = dat64;

//Macro to read xmem register from tgcapture
`define GET_XM_STRUCT(name, tgIdx, width) \
    `GET_XM_PTR(name, tgIdx, width)

`define GET_XM_MEM(name, tgIdx, width, depth) \
    for (int i = 0; i < depth; i++) begin \
        tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
        name[i] = dat64; \
        if (width == 64) \
            xmem_write64(offset_``name + (i * (width / 8)), name[i]); \
        else \
            xmem_write(offset_``name + (i * (width / 8)), name[i], width); \
    end \
	for (int i=0; i<depth; i++) begin \
		tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
		name[i] = dat64; \
	end

//Macro to read xmem pointer (both input and output) from tgcapture
`define GET_XM_PTR(name, tgIdx, width) \
    tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
    name = dat64; \
    if (width == 64) \
        xmem_write64(offset_``name , name); \
    else \
        xmem_write(offset_``name , name, width); \
    tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
    name = dat64;

//Macro to read axi stream (input) from tgcapture
`define WRITE_AXIS_DATA(name, data) \
    tb_top.DMA_TVALID = 0;                 \
    while (!name``_TREADY) begin    \
        @ (posedge clk);         \
    end                         \
    if (name``_TREADY) begin  \
        tb_top.DMA_TDATA = data;   \
        tb_top.DMA_TVALID = 1;      \
    end                     \
    @ (posedge clk);

//Macro to verify axi stream (output) from tgcapture
`define VERIFY_AXIS_OUT(name, tgIdx, width)                 \
    $$display("VERIFY_AXIS_OUT - draft only(not check)");   \
    if (name``_TREADY && name``_TVALID) begin               \
        tgEmpty |= tg_queue(tgF, width, tgIdx, dat64);      \
        if (name``_TDATA != dat64) begin                    \
            $$display("ERROR: %m failed: test_cnt=%0d %s=%0d expected=%0d", test_cnt, name``_TDATA, name``_TDATA, dat64); \
            $$fclose(tgF);              \
            #10 $$stop;                 \
        end                             \
    end

`define GET_DCACHE_MEM(name, tgIdx, offset, width, depth) \
    for (int i = 0; i < depth; i++) begin \
        tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
        name[i] = dat64; \
        dcache_write(offset + (i * (width / 8)), name[i], width); \
    end \
	for (int i=0; i<depth; i++) begin \
		tgEmpty |= tg_queue(tgF, width, tgIdx, dat64); \
		name[i] = dat64; \
	end

//Macro to verify HLS results
`define VERIFY(var_name, var_val, var_exp) \
    if (var_val !== var_exp) begin \
        $$display("ERROR: %m failed: test_cnt=%0d %s=%0d expected=%0d", test_cnt, var_name, var_val, var_exp); \
        $$fclose(tgF); \
        #10 $$stop; \
    end

//Macro to verify HLS results
`define VERIFY_XMEM(var_name, var_val, var_exp) \
    if (width_``var_exp == 64) \
        xmem_read64(offset_``var_exp, var_val); \
    else \
        xmem_read(offset_``var_exp, var_val, width_``var_exp); \
    if (var_val !== var_exp) begin \
        $$display("ERROR: %m failed: test_cnt=%0d %s=%0d expected=%0d", test_cnt, var_name, var_val, var_exp); \
        $$fclose(tgF); \
        #10 $$stop; \
    end

//Macro to verify HLS results
`define VERIFY_XMEM_ARRAY(var_name, var_val, var_exp) \
    foreach(var_val[i]) begin \
        int width = $$size(var_val[0]);       \
        logic [63:0] mask = (i == 2 && (var_name == "bNeighborFlags" || var_name == "bNeighborFlags_c"))? 63'h1 : 63'hffffffffffffffff;\
        if (width == 64) \
            xmem_read64(offset_``var_exp + (i * width/8), var_val[i]); \
        else \
            xmem_read(offset_``var_exp + (i * width/8), var_val[i], width); \
        if ((var_val[i] & mask) !== (var_exp[i] & mask)) begin \
            $$display("ERROR: %m failed: test_cnt=%0d %s[%0d]=%0d expected=%0d", test_cnt, var_name, i, var_val[i], var_exp[i]); \
            $$fclose(tgF); \
            #10 $$stop; \
        end \
    end

//Macro to verify HLS results
`define VERIFY_XMEM_STRUCT(var_name, var_val, var_exp) \
    `VERIFY_XMEM(var_name, var_val, var_exp)

//Macro to verify HLS results
`define VERIFY_DCACHE_MEM(var_name, var_val, var_exp, offset) \
    foreach(var_val[i]) begin \
        int width = $$size(var_val[0]);       \
        dcache_read(offset + (i * width/8), var_val[i], width); \
        if (var_val[i] !== var_exp[i]) begin \
            $$display("ERROR: %m failed: test_cnt=%0d %s[%0d]=%0d expected=%0d", test_cnt, var_name, i, var_val[i], var_exp[i]); \
            $$fclose(tgF); \
            #10 $$stop; \
        end \
    end


//Riscv task
`include "riscv_task.vh"

//DecodeBin task
//`include "decodeBin_task.vh"
`include "simple_decodeBin_task.vh"

//tgcapture task
`include "tgcapture_task.vh"

//HLS test task
`include "hls_test_task.vh"

//xmem init task
`include "xmem_init_task.vh"

//Cache model
always_comb begin
`ifndef HLS_LOCAL_DCACHE    
    dc_ap_ce = '{default:1'b1};
    for (int i = 0; i < CORE_NUM; i++) begin
        dc_ce0     [i] = dcArb_hls_user_re[i] | dcArb_hls_user_we[i];
        dc_we0     [i] = dcArb_hls_user_we[i];
        dc_we_mask [i] = dcArb_hls_user_we_mask[i];
        dc_address0[i] = dcArb_hls_user_adr[i];
        dc_d0      [i] = dcArb_hls_user_wdat[i];
        dcArb_hls_user_rdy     [i] = dc_ready[i];
        dcArb_hls_user_rdat    [i] = dc_q0[i]
        dcArb_hls_user_rdat_vld[i] = dc_q0_vld[i];
    end
    for (int i = 0; i < CORE_NUM; i++) begin
        dc_ce0     [CORE_NUM+i] = cpEng_dc_re[i];
        dc_we0     [CORE_NUM+i] = 0;
        dc_we_mask [CORE_NUM+i] = 0;
        dc_address0[CORE_NUM+i] = cpEng_dc_rad[i];
        dc_d0      [CORE_NUM+i] = 0;
        cpEng_dc_rrdy    [i] = dc_ready[CORE_NUM+i];
        cpEng_dc_rdat    [i] = dc_q0[CORE_NUM+i]
        cpEng_dc_rdat_vld[i] = dc_q0_vld[CORE_NUM+i];   
    end
    for (int i = 0; i < CORE_NUM; i++) begin
        dc_ce0     [2*CORE_NUM+i] = 0;
        dc_we0     [2*CORE_NUM+i] = cpEng_dc_bwe[i] != 0;
        dc_we_mask [2*CORE_NUM+i] = cpEng_dc_bwe[i];
        dc_address0[2*CORE_NUM+i] = cpEng_dc_wad[i];
        dc_d0      [2*CORE_NUM+i] = cpEng_dc_wdat[i];
        cpEng_dc_wrdy[i] = dc_ready[2*CORE_NUM+i];
    end
`else
    for (int i = 0; i < HLS_CACHE; i++) begin
        dc_ap_ce   [i] = dcArb_hls_user_ap_ce[i];
        dc_ce0     [i] = dcArb_hls_user_re[i] | dcArb_hls_user_we[i];
        dc_we0     [i] = dcArb_hls_user_we[i];
        dc_we_mask [i] = dcArb_hls_user_we_mask[i];
        dc_address0[i] = dcArb_hls_user_adr[i];
        dc_d0      [i] = dcArb_hls_user_wdat[i];
        dcArb_hls_user_rdy     [i] = dc_ready[i];
        dcArb_hls_user_rdat    [i] = dc_q0[i];
        dcArb_hls_user_rdat_vld[i] = dc_q0_vld[i];
    end
    dc_ap_ce   [HLS_CACHE+0] = 1;
    dc_ce0     [HLS_CACHE+0] = cpEng_dc_re;
    dc_we0     [HLS_CACHE+0] = 0;
    dc_we_mask [HLS_CACHE+0] = 0;
    dc_address0[HLS_CACHE+0] = cpEng_dc_rad;
    dc_d0      [HLS_CACHE+0] = 0;
    cpEng_dc_rrdy      = dc_ready[HLS_CACHE+0];
    cpEng_dc_rdat      = dc_q0[HLS_CACHE+0];
    cpEng_dc_rdat_vld  = dc_q0_vld[HLS_CACHE+0];    
    dc_ap_ce   [HLS_CACHE+1] = 1;
    dc_ce0     [HLS_CACHE+1] = cpEng_dc_bwe != 0;
    dc_we0     [HLS_CACHE+1] = cpEng_dc_bwe != 0;
    dc_we_mask [HLS_CACHE+1] = cpEng_dc_bwe;
    dc_address0[HLS_CACHE+1] = cpEng_dc_wad;
    dc_d0      [HLS_CACHE+1] = cpEng_dc_wdat;
    cpEng_dc_wrdy = dc_ready[HLS_CACHE+1];
`endif    
end
cache_model #(
    .CORES          ( DC_PORTS         ),
    .MISS_RATE      ( 0.25             ),
    .MAX_MISS_CYCLE ( 8                ),
    .DEPTH          ( DC_SIZE*CORE_NUM ),
    .DBITS          ( 32               ),
    .ABITS          ( 32               )
)
cache (
    .clk      ( clk         ),
    .rstn     ( rstn        ),
    .hls_ap_ce( dc_ap_ce    ),
    .ready    ( dc_ready    ),
    .address0 ( dc_address0 ),
    .ce0      ( dc_ce0      ),
    .we0      ( dc_we0      ),
    .we_mask  ( dc_we_mask  ),
    .d0       ( dc_d0       ),
    .q0       ( dc_q0       ),
    .q0_vld   ( dc_q0_vld   )
);

// AXI4 Memory model (DMA)
dram_axi_sim_model_v2 #(
    .ID_WIDTH         ( AXI_ID_WIDTH   ),
    .DRAM_DATA_WIDTH  ( AXI_DATA_WIDTH )
)
inst_dma_dram_model (
    .clk              ( clk             ),
    .rstn             ( rstn            ),
    .dram_init_done   (                 ),
    .ddr_awvalid      ( dma_axi_awvalid ),
    .ddr_awaddr       ( dma_axi_awaddr  ),
    .ddr_awlen        ( dma_axi_awlen   ),
    .ddr_awsize       ( dma_axi_awsize  ),
    .ddr_awid         ( dma_axi_awid    ),
    .ddr_awready      ( dma_axi_awready ),
    .ddr_wdata        ( dma_axi_wdata   ),
    .ddr_wstrb        ( dma_axi_wstrb   ),
    .ddr_wvalid       ( dma_axi_wvalid  ),
    .ddr_wready       ( dma_axi_wready  ),
    .ddr_bready       ( dma_axi_bready  ),
    .ddr_bid          ( dma_axi_bid     ),
    .ddr_bresp        ( dma_axi_bresp   ),
    .ddr_bvalid       ( dma_axi_bvalid  ),
    .ddr_arvalid      ( dma_axi_arvalid ),
    .ddr_araddr       ( dma_axi_araddr  ),
    .ddr_arlen        ( dma_axi_arlen   ),
    .ddr_arsize       ( dma_axi_arsize  ),
    .ddr_arid         ( dma_axi_arid    ),
    .ddr_arready      ( dma_axi_arready ),
    .ddr_rready       ( dma_axi_rready  ),
    .ddr_rdata        ( dma_axi_rdata   ),
    .ddr_rvalid       ( dma_axi_rvalid  ),
    .ddr_rlast        ( dma_axi_rlast   ),
    .ddr_rid          ( dma_axi_rid     ),
    .ddr_resp         ( dma_axi_rresp   )
);

// AXI4 Memory model (array cache)
dram_axi_sim_model_v2 #(
    .ID_WIDTH         ( AXI2_ID_WIDTH   ),
    .DRAM_DATA_WIDTH  ( AXI2_DATA_WIDTH )
)
inst_array_dram_model (
    .clk              ( clk                     ),
    .rstn             ( rstn                    ),
    .dram_init_done   (                         ),
    .ddr_awvalid      ( xcache_axi_awvalid  [0] ),
    .ddr_awaddr       ( xcache_axi_awaddr   [0] ),
    .ddr_awlen        ( xcache_axi_awlen    [0] ),
    .ddr_awsize       ( xcache_axi_awsize   [0] ),
    .ddr_awid         ( xcache_axi_awid     [0] ),
    .ddr_awready      ( xcache_axi_awready  [0] ),
    .ddr_wdata        ( xcache_axi_wdata    [0] ),
    .ddr_wstrb        ( xcache_axi_wstrb    [0] ),
    .ddr_wvalid       ( xcache_axi_wvalid   [0] ),
    .ddr_wready       ( xcache_axi_wready   [0] ),
    .ddr_bready       ( xcache_axi_bready   [0] ),
    .ddr_bid          ( xcache_axi_bid      [0] ),
    .ddr_bresp        ( xcache_axi_bresp    [0] ),
    .ddr_bvalid       ( xcache_axi_bvalid   [0] ),
    .ddr_arvalid      ( xcache_axi_arvalid  [0] ),
    .ddr_araddr       ( xcache_axi_araddr   [0] ),
    .ddr_arlen        ( xcache_axi_arlen    [0] ),
    .ddr_arsize       ( xcache_axi_arsize   [0] ),
    .ddr_arid         ( xcache_axi_arid     [0] ),
    .ddr_arready      ( xcache_axi_arready  [0] ),
    .ddr_rready       ( xcache_axi_rready   [0] ),
    .ddr_rdata        ( xcache_axi_rdata    [0] ),
    .ddr_rvalid       ( xcache_axi_rvalid   [0] ),
    .ddr_rlast        ( xcache_axi_rlast    [0] ),
    .ddr_rid          ( xcache_axi_rid      [0] ),
    .ddr_resp         ( xcache_axi_rresp    [0] )
);

// AXI4 Memory model (cyclic cache)
dram_axi_sim_model_v2 #(
    .ID_WIDTH         ( AXI2_ID_WIDTH   ),
    .DRAM_DATA_WIDTH  ( AXI2_DATA_WIDTH )
)
inst_cyclic_dram_model (
    .clk              ( clk                     ),
    .rstn             ( rstn                    ),
    .dram_init_done   (                         ),
    .ddr_awvalid      ( xcache_axi_awvalid  [1] ),
    .ddr_awaddr       ( xcache_axi_awaddr   [1] ),
    .ddr_awlen        ( xcache_axi_awlen    [1] ),
    .ddr_awsize       ( xcache_axi_awsize   [1] ),
    .ddr_awid         ( xcache_axi_awid     [1] ),
    .ddr_awready      ( xcache_axi_awready  [1] ),
    .ddr_wdata        ( xcache_axi_wdata    [1] ),
    .ddr_wstrb        ( xcache_axi_wstrb    [1] ),
    .ddr_wvalid       ( xcache_axi_wvalid   [1] ),
    .ddr_wready       ( xcache_axi_wready   [1] ),
    .ddr_bready       ( xcache_axi_bready   [1] ),
    .ddr_bid          ( xcache_axi_bid      [1] ),
    .ddr_bresp        ( xcache_axi_bresp    [1] ),
    .ddr_bvalid       ( xcache_axi_bvalid   [1] ),
    .ddr_arvalid      ( xcache_axi_arvalid  [1] ),
    .ddr_araddr       ( xcache_axi_araddr   [1] ),
    .ddr_arlen        ( xcache_axi_arlen    [1] ),
    .ddr_arsize       ( xcache_axi_arsize   [1] ),
    .ddr_arid         ( xcache_axi_arid     [1] ),
    .ddr_arready      ( xcache_axi_arready  [1] ),
    .ddr_rready       ( xcache_axi_rready   [1] ),
    .ddr_rdata        ( xcache_axi_rdata    [1] ),
    .ddr_rvalid       ( xcache_axi_rvalid   [1] ),
    .ddr_rlast        ( xcache_axi_rlast    [1] ),
    .ddr_rid          ( xcache_axi_rid      [1] ),
    .ddr_resp         ( xcache_axi_rresp    [1] )
);

//Top module
hls_long_tail_top_v1 #(
    .START_CORE      ( START_CORE     ),
    .CORE_NUM        ( CORE_NUM       ),
    .ENABLE_DMA      ( ENABLE_DMA     ),
    .ENABLE_PROFILE  ( ENABLE_PROFILE ),
    .EN_RISCV_XMEM1  ( EN_RISCV_XMEM1 ),
    //AXIS DMA
    .AXI_ADDR_WIDTH  ( AXI_ADDR_WIDTH ),
    .AXI_DATA_WIDTH  ( AXI_DATA_WIDTH ),
    .AXI_LEN_WIDTH   ( AXI_LEN_WIDTH  ),
    .AXI_ID_WIDTH    ( AXI_ID_WIDTH   ),
    .AXI_STRB_WIDTH  ( AXI_STRB_WIDTH ),
    //XCACHE
    .AXI2_ADDR_WIDTH ( AXI2_ADDR_WIDTH ),
    .AXI2_DATA_WIDTH ( AXI2_DATA_WIDTH ),
    .AXI2_LEN_WIDTH  ( AXI2_LEN_WIDTH  ),
    .AXI2_ID_WIDTH   ( AXI2_ID_WIDTH   ),
    .AXI2_STRB_WIDTH ( AXI2_STRB_WIDTH )
)
inst_top (.*);

//Clock
always #5 clk = ~clk;

logic [7:0] DMA_TDATA;
logic DMA_TVALID;

//Run hls
task automatic run_hls(int c, int hls);
    case(hls)
        ${running_task}
    endcase
endtask

//Run core
task automatic run_core(int c);
    if (c < CORE_NUM) begin
        //for (int i = 0; i < HLS_NUM; i++) begin
        //    run_hls(c, i);
        //end
        run_hls(c, innerloop_ff_hevc_extract_rbsp_1_hls);
    end
endtask

//Main
initial begin

    force inst_top.axis_src_TDATA = tb_top.DMA_TDATA;
    force inst_top.axis_src_TVALID= tb_top.DMA_TVALID;

    //Default values
    clk                 = 0;
    rstn                = 0;
    rv_re               = '{default:'0};
    rv_we               = '{default:'0};
    rv_addr             = '{default:'0};
    rv_wdata            = '{default:'0};        
    rv_xcache_part      = '{default:'0};
    rv_xcache_re        = '{default:'0};
    rv_xcache_we        = '{default:'0};
    rv_xcache_addr      = '{default:'0};
    rv_xcache_wdata     = '{default:'0};
    rv_prnt_reqVld_i    = '{default:'0};
    rv_prnt_reqChild_i  = '{default:'0};
    rv_prnt_reqPc_i     = '{default:'0};
    rv_prnt_reqArgs_i   = '{default:'0};
    rv_prnt_reqReturn_i = '{default:'0};
    rv_prnt_retRdy_i    = '{default:'0};
    rv_chld_reqRdy_i    = '{default:'0};
    rv_chld_retVld_i    = '{default:'0};
    rv_chld_retParent_i = '{default:'0};
    rv_chld_retDat_i    = '{default:'0};
    decBin_rdy          = '{default:'0};
    decBin_bin          = '{default:'0};
    decBin_vld          = '{default:'0};
    df_chld_reqRdy_i    = 1;
    df_chld_retVld_i    = 0;
    df_chld_retParent_i = 0;
    df_chld_retDat_i    = 0;
    dataflow_rdy        = 1;
    dataflow_dout_vld   = 0;
    dataflow_dout       = 0;

    //Reset
    #100;
    rstn      = 1;
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);

    xmem_param_init();

    @ (posedge clk);
    @ (posedge clk);

    parse_csv_file(${csv_filepath});

    //Running task
    fork
        run_core(0);
        run_core(1);
        run_core(2);
        run_core(3);
    join

    $$display("Finish!");
    #10 $$stop;
end

always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        df_chld_retVld_i    <= 0;
        df_chld_retParent_i <= 0;
    end
    else begin
        df_chld_retVld_i    <= df_chld_reqVld_o & df_chld_reqReturn_o;
        df_chld_retParent_i <= df_chld_reqParent_o;
    end
end


endmodule
