/*
xmem change on Aug16:
wait for at least 3 cycle for all read argument from xmem to be ready and the send ap_start
	1. HLS accelerator may incurs xmem read-after-write error for scalar arguments.
	It writes to an address of a scalar argument and read the same address before it is ready.
	A simple workaround for scalar arguments is to instantiated a dedicated write-buffer register in custom connection.
	It can buffer either the xmem read data at the at the first cycle after ap_start and the HLS write data in subsequent cycles.
	Furthermore, the HLS write data is forwarded to both Xmem and the write-buffer register while the HLS always read scalar data from the write buffer.
	2. fix bug in array access due to change above
*/


/*

//-----------------xmem mapping --------------------//


	scalar					array					cyclic
	row-major order 		column-major order		column-major order
	B0	B1	B2	B3			B0	B1	B2	B3		 	B0	 				B1					B2					B3
--------------------------------------------------------------------------------------------------------------------------------
P0	  0   4   8  12			128 136 144 152			160 164 168 172		192 196 200 204		224 228 232 236		256	260 264 270
	 16  20  24  28 		132 140 148 156			176 180 184 188		208 212 216 220 	240 244 248 252		274	278 282 286
P1	 32  36  40	 44
	 48  52  56	 60
P2	 64  68  72	 76
	 80  84  88	 92
P3	 96 100 104	108
	112 116 120	124


P.S:
1. the width of bank in scalar/array range is 4 bytes
2. the width of bank in cyclic range is 16 bytes

<-------- 30 bit ------>

00000000000000000ppsssss	//scalar address
000000000000aaaaaaaaaaaa 	//array	 address
0000cccccccccccccccccccc 	//cyclic address

*/




`include "common.vh"
`define ENABLE_CYCLIC_BANK

module xcache import xcache_param_pkg::*; #(
	//array mruCache
	parameter int AXI_LEN_W 				= 8,
	parameter int DW 						= 32,
	parameter int AW 						= ARRAY_BANK_BYTE_AW,	//previous: 32
	parameter int ROLLBACK 					= 0,
	parameter int CACHE_BYTE 				= 1*1024,
	parameter int CACHE_WAY  				= 2,
	parameter int CACHE_WORD_BYTE			= DW / 8,
	parameter int CACHE_LINE_LEN			= 8,
	//cyclic mruCache
    parameter int CYCLIC_CACHE_AXI_LEN_W 	= 8,
    parameter int CYCLIC_CACHE_DW 			= 32,
    parameter int CYCLIC_CACHE_AW 			= CYCLIC_BANK_BYTE_AW, 				//previous: 32
    parameter int CYCLIC_CACHE_USER_DW 		= 128,
    parameter int CYCLIC_CACHE_USER_MAX_LEN = CYCLIC_CACHE_USER_DW / CYCLIC_CACHE_DW,
    parameter int CYCLIC_CACHE_BYTE 		= 1*1024,
    parameter int CYCLIC_CACHE_WAY 			= 2,
    parameter int CYCLIC_CACHE_WORD_BYTE	= CYCLIC_CACHE_DW / 8,
    parameter int CYCLIC_CACHE_LINE_LEN		= 8,
	//AXI4
    parameter int AXI_ADDR_WIDTH   			= 32,
    parameter int AXI_DATA_WIDTH   			= 256,
    parameter int AXI_LEN_WIDTH    			= 8,
    parameter int AXI_ID_WIDTH     			= 8
)
(
	input 									clk,
	input 									rstn,

    //configure interface
    input 									risc_cfg,
	input  [RISC_AWIDTH-1:0]				risc_cfg_adr,
	input  [RISC_DWIDTH-1:0]				risc_cfg_di,

	//risc interface
    input 	[7:0]							risc_part,
	input 	[3:0]							risc_we,
	input 									risc_re,
	input  [RISC_AWIDTH-1:0]				risc_adr,
	input  [RISC_DWIDTH-1:0]				risc_di,
	output logic							risc_rdy,
	output logic							risc_do_vld,
	output logic [RISC_DWIDTH-1:0] 			risc_do,

	//For dualport bank in scalar range
	input 									scalar_argVld	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	output logic 							scalar_argAck 	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	input [XMEM_AW-1:0]					    scalar_adr		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	input [SCALAR_BANK_DW-1:0]				scalar_wdat		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	output logic [SCALAR_BANK_DW-1:0]		scalar_rdat		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	output logic                    		scalar_rdat_vld	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],

	//For single port bank in array range
	output logic 							array_argRdy	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	input 									array_ap_ce 	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	input 									array_argVld	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	output logic 							array_argAck 	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	input [XMEM_AW-1:0]		        		array_adr		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	input [ARRAY_BANK_DW-1:0]				array_wdat		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	output logic [ARRAY_BANK_DW-1:0]		array_rdat		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	output logic                    		array_rdat_vld	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],

	//For wide port bank in cyclic range
	output logic 							cyclic_argRdy	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	input 									cyclic_ap_ce	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	input 									cyclic_argVld	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	output logic 							cyclic_argAck 	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	input [XMEM_AW-1:0]		        		cyclic_adr		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	input [CYCLIC_BANK_DW-1:0]				cyclic_wdat		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	output logic [CYCLIC_BANK_DW-1:0]		cyclic_rdat		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	output logic                    		cyclic_rdat_vld	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],


    //AXI4 for Array range
    input                                 	axi_awready,
    output logic                          	axi_awvalid,
    output logic [AXI_ADDR_WIDTH - 1 : 0] 	axi_awaddr,
    output logic [AXI_LEN_WIDTH  - 1 : 0] 	axi_awlen,
    output logic [AXI_ID_WIDTH   - 1 : 0] 	axi_awid,
    output logic [                 2 : 0] 	axi_awsize,
    output logic [                 1 : 0] 	axi_awburst,
    output logic                          	axi_awlock,
    output logic [                 3 : 0] 	axi_awcache,
    output logic [                 2 : 0] 	axi_awprot,
    output logic [                 3 : 0] 	axi_awqos,
    output logic [                 3 : 0] 	axi_awregion,
    output logic                          	axi_awuser,
    input                                 	axi_wready,
    output logic                          	axi_wvalid,
    output logic [AXI_DATA_WIDTH - 1 : 0] 	axi_wdata,
    output logic [AXI_DATA_WIDTH/8-1 : 0] 	axi_wstrb,
    output logic                          	axi_wlast,
    output logic [AXI_ID_WIDTH   - 1 : 0] 	axi_wid,
    output logic                          	axi_wuser,
    output logic                          	axi_bready,
    input                                 	axi_bvalid,
    input        [                 1 : 0] 	axi_bresp,
    input        [AXI_ID_WIDTH   - 1 : 0] 	axi_bid,
    input                                 	axi_buser,
    input                                 	axi_arready,
    output logic                          	axi_arvalid,
    output logic [AXI_ADDR_WIDTH - 1 : 0] 	axi_araddr,
    output logic [AXI_LEN_WIDTH  - 1 : 0] 	axi_arlen,
    output logic [AXI_ID_WIDTH   - 1 : 0] 	axi_arid,
    output logic [                 2 : 0] 	axi_arsize,
    output logic [                 1 : 0] 	axi_arburst,
    output logic                          	axi_arlock,
    output logic [                 3 : 0] 	axi_arcache,
    output logic [                 2 : 0] 	axi_arprot,
    output logic [                 3 : 0] 	axi_arqos,
    output logic [                 3 : 0] 	axi_arregion,
    output logic                          	axi_aruser,
    output logic                          	axi_rready,
    input                                 	axi_rvalid,
    input        [AXI_DATA_WIDTH - 1 : 0] 	axi_rdata,
    input                                 	axi_rlast,
    input        [                 1 : 0] 	axi_rresp,
    input        [AXI_ID_WIDTH   - 1 : 0] 	axi_rid,
    input                                 	axi_ruser,
    //AXI4 for Cyclic range
    input                                 	axi_awready_1,
    output logic                          	axi_awvalid_1,
    output logic [AXI_ADDR_WIDTH - 1 : 0] 	axi_awaddr_1,
    output logic [AXI_LEN_WIDTH  - 1 : 0] 	axi_awlen_1,
    output logic [AXI_ID_WIDTH   - 1 : 0] 	axi_awid_1,
    output logic [                 2 : 0] 	axi_awsize_1,
    output logic [                 1 : 0] 	axi_awburst_1,
    output logic                          	axi_awlock_1,
    output logic [                 3 : 0] 	axi_awcache_1,
    output logic [                 2 : 0] 	axi_awprot_1,
    output logic [                 3 : 0] 	axi_awqos_1,
    output logic [                 3 : 0] 	axi_awregion_1,
    output logic                          	axi_awuser_1,
    input                                 	axi_wready_1,
    output logic                          	axi_wvalid_1,
    output logic [AXI_DATA_WIDTH - 1 : 0] 	axi_wdata_1,
    output logic [AXI_DATA_WIDTH/8-1 : 0] 	axi_wstrb_1,
    output logic                          	axi_wlast_1,
    output logic [AXI_ID_WIDTH   - 1 : 0] 	axi_wid_1,
    output logic                          	axi_wuser_1,
    output logic                          	axi_bready_1,
    input                                 	axi_bvalid_1,
    input        [                 1 : 0] 	axi_bresp_1,
    input        [AXI_ID_WIDTH   - 1 : 0] 	axi_bid_1,
    input                                 	axi_buser_1,
    input                                 	axi_arready_1,
    output logic                          	axi_arvalid_1,
    output logic [AXI_ADDR_WIDTH - 1 : 0] 	axi_araddr_1,
    output logic [AXI_LEN_WIDTH  - 1 : 0] 	axi_arlen_1,
    output logic [AXI_ID_WIDTH   - 1 : 0] 	axi_arid_1,
    output logic [                 2 : 0] 	axi_arsize_1,
    output logic [                 1 : 0] 	axi_arburst_1,
    output logic                          	axi_arlock_1,
    output logic [                 3 : 0] 	axi_arcache_1,
    output logic [                 2 : 0] 	axi_arprot_1,
    output logic [                 3 : 0] 	axi_arqos_1,
    output logic [                 3 : 0] 	axi_arregion_1,
    output logic                          	axi_aruser_1,
    output logic                          	axi_rready_1,
    input                                 	axi_rvalid_1,
    input        [AXI_DATA_WIDTH - 1 : 0] 	axi_rdata_1,
    input                                 	axi_rlast_1,
    input        [                 1 : 0] 	axi_rresp_1,
    input        [AXI_ID_WIDTH   - 1 : 0] 	axi_rid_1,
    input                                 	axi_ruser_1
);


//---------------------------------------------------------------
//Parameter
//---------------------------------------------------------------


//---------------------------------------------------------------
//Signals
//---------------------------------------------------------------
logic 								risc_cmd_en, risc_cmd_en_r, risc_cmd_en_r2;

logic 								scalar_mux_ready 	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic 								scalar_mux_re 		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic 								scalar_mux_we 		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [1:0]							scalar_mux_len		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [XMEM_AW-1:0]					scalar_mux_adr		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [LOG2_MAX_PARTITION-1:0]		scalar_mux_part_idx	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [SCALAR_BANK_BYTE_AW-1:0]		scalar_mux_bankAdr	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];		//unit: byte
logic [SCALAR_BANK_DW-1:0]			scalar_mux_din		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_dout		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic 								scalar_mux_dout_vld	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];


logic 								risc_argRdy_scalar 		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic                               risc_argAck_scalar		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [RISC_DWIDTH-1:0]             risc_do_scalar			[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic					            risc_do_vld_scalar		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic 								risc_argRunning_r_scalar[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];

logic 								scalar_mux_re0 		[BANK_NUM[MEM_TYPE_SCALAR]];
logic 								scalar_mux_we0 		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [1:0]							scalar_mux_len0		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [SCALAR_BANK_BYTE_AW-1:0]		scalar_mux_bankAdr0	[BANK_NUM[MEM_TYPE_SCALAR]];		//unit: byte
logic [SCALAR_BANK_DW-1:0]			scalar_mux_din0		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_dout0	[BANK_NUM[MEM_TYPE_SCALAR]];
logic								scalar_mux_dout0_vld[BANK_NUM[MEM_TYPE_SCALAR]];


logic 								scalar_mux_re1 		[BANK_NUM[MEM_TYPE_SCALAR]];
logic 								scalar_mux_we1 		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [1:0]							scalar_mux_len1		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [SCALAR_BANK_BYTE_AW-1:0]		scalar_mux_bankAdr1	[BANK_NUM[MEM_TYPE_SCALAR]];		//unit: byte
logic [SCALAR_BANK_DW-1:0]			scalar_mux_din1		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_dout1	[BANK_NUM[MEM_TYPE_SCALAR]];
logic								scalar_mux_dout1_vld[BANK_NUM[MEM_TYPE_SCALAR]];

logic 								array_mux_ready 	[BANK_NUM[MEM_TYPE_ARRAY]];
logic 								array_mux_re 		[BANK_NUM[MEM_TYPE_ARRAY]];
logic 								array_mux_we 		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [1:0]							array_mux_len		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [XMEM_AW-1:0]					array_mux_adr		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [LOG2_MAX_PARTITION-1:0]		array_mux_part_idx	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [ARRAY_BANK_BYTE_AW-1:0]		array_mux_bankAdr	[BANK_NUM[MEM_TYPE_ARRAY]];				//unit: byte
logic [ARRAY_BANK_DW-1:0]			array_mux_din		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [ARRAY_BANK_DW-1:0]			array_mux_dout		[BANK_NUM[MEM_TYPE_ARRAY]];
logic 								array_mux_dout_vld	[BANK_NUM[MEM_TYPE_ARRAY]];

logic 								risc_argRdy_array 		[BANK_NUM[MEM_TYPE_ARRAY]];
logic                               risc_argAck_array		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [RISC_DWIDTH-1:0]             risc_do_array			[BANK_NUM[MEM_TYPE_ARRAY]];
logic					            risc_do_vld_array		[BANK_NUM[MEM_TYPE_ARRAY]];
logic 								risc_argRunning_r_array [BANK_NUM[MEM_TYPE_ARRAY]];

logic 								cyclic_mux_ready 		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic 								cyclic_mux_re 			[BANK_NUM[MEM_TYPE_CYCLIC]];
logic 								cyclic_mux_we 			[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [1:0]							cyclic_mux_len			[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [XMEM_AW-1:0]					cyclic_mux_adr			[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [LOG2_MAX_PARTITION-1:0]		cyclic_mux_part_idx		[BANK_NUM[MEM_TYPE_CYCLIC]];


logic [CYCLIC_BANK_BYTE_AW-1:0]		cyclic_mux_bankAdr		[BANK_NUM[MEM_TYPE_CYCLIC]];	//unit: byte
logic [CYCLIC_BANK_AW-1:0]			cyclic_mux_wordAdr		[BANK_NUM[MEM_TYPE_CYCLIC]];	//unit: word
logic [3:0][CYCLIC_BANK_DW/4-1:0]	cyclic_mux_din			[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [3:0][CYCLIC_BANK_DW/4-1:0]	cyclic_mux_dout			[BANK_NUM[MEM_TYPE_CYCLIC]];
logic 								cyclic_mux_dout_vld		[BANK_NUM[MEM_TYPE_CYCLIC]];

logic 				  			  	risc_argRdy_cyclic 		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic                               risc_argAck_cyclic		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [CYCLIC_BANK_DW-1:0]          risc_di_cyclic;
logic [CYCLIC_BANK_DW-1:0]          risc_do_cyclic			[BANK_NUM[MEM_TYPE_CYCLIC]];
logic				    			risc_do_vld_cyclic		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic 				    			risc_argRunning_r_cyclic[BANK_NUM[MEM_TYPE_CYCLIC]];



logic [$clog2(SUPERBANK)-1:0]		sBank;	//superbank
logic 								dPort;	//requestPort
//logic [$clog2(MAX_MUX_NUM)-1:0]		aPort; 	//argumentPort
logic [7:0]		                    aPort; 	//argumentPort
logic [LOG2_MAX_PARTITION:0] 	    part;	//partition id

logic [LOG2_MAX_PARTITION:0] 	    partNum;	//part
logic [XMEM_AW-1:0]					rangeStart	[MAX_PARTITION];
logic [LOG2_MAX_PARTITION-1:0] 	    partIdx_w, partIdx_r;
logic                               act_req, act_req_r;

//-------
logic [7:0]						    scalar_mux_num	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
//logic [XMEM_AW-1:0]					scalar_base		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic           					scalar_base_upd	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];

logic [1:0]							scalar_in2Type	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
//logic [7:0]							scalar_in2Width	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
//logic           					scalar_in2Type_upd	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic           					scalar_in2Width_upd	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];

//logic [7:0]							scalar_in2Wport	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
//--
logic [XMEM_AW-1:0]					scalar_subRangeStart	 [MAX_PARTITION];	//set to 0
logic [XMEM_AW-1:0]					scalar_subBankStart   	 [MAX_PARTITION];
logic [XMEM_AW-1:0]					scalar_subBankSize 		 [MAX_PARTITION];
logic 								scalar_matched			 [BANK_NUM[MEM_TYPE_SCALAR]];
logic 								scalar_matched_r		 [BANK_NUM[MEM_TYPE_SCALAR]];

logic [7:0]						    array_mux_num 	[BANK_NUM[MEM_TYPE_ARRAY]];
//logic [XMEM_AW-1:0]					array_base		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic           					array_base_upd	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];

logic [1:0]							array_in2Type	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
//logic [7:0]							array_in2Width	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
//logic [7:0]							array_in2Wport	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
//logic           					array_in2Type_upd	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic           					array_in2Width_upd	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
//--
logic [XMEM_AW-1:0]					array_subRangeStart		 [MAX_PARTITION];
logic [XMEM_AW-1:0]					array_subBankStart  [MAX_PARTITION];
logic [XMEM_AW-1:0]					array_subBankSize  [MAX_PARTITION];
logic 								array_matched			 [BANK_NUM[MEM_TYPE_ARRAY]];
logic 								array_matched_r			 [BANK_NUM[MEM_TYPE_ARRAY]];

logic [7:0]						    cyclic_mux_num	[BANK_NUM[MEM_TYPE_CYCLIC]];
//logic [XMEM_AW-1:0]					cyclic_base		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic           					cyclic_base_upd	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [1:0]							cyclic_in2Type	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
//logic [7:0]							cyclic_in2Width	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
//logic           					cyclic_in2Type_upd	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic           					cyclic_in2Width_upd	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];

//logic [7:0]							cyclic_in2Wport	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
//--
logic [XMEM_AW-1:0]					cyclic_subRangeStart	 [MAX_PARTITION];
logic [XMEM_AW-1:0]					cyclic_max_subRangeStart [MAX_PARTITION];
logic [XMEM_AW-1:0]					cyclic_subBankStart      [MAX_PARTITION];
logic [XMEM_AW-1:0]					cyclic_subBankSize [MAX_PARTITION];
logic 								cyclic_matched			 [BANK_NUM[MEM_TYPE_CYCLIC]];
logic 								cyclic_matched_r		 [BANK_NUM[MEM_TYPE_CYCLIC]];

logic [XMEM_AW-1:0]					subRangeStart[MAX_PARTITION][2];
logic [XMEM_AW-1:0]					subBankSize[MAX_PARTITION][MEM_TYPE_MAX];


logic [RISC_DWIDTH-1:0] 	        risc_do_w;
logic 						        risc_do_vld_w;

logic                               risc_rdy_w;
logic                               found;

logic [3:0]                         risc_we_r;
logic                               risc_re_r, risc_re_r2;
logic [XMEM_AW-1:0]                 risc_adr_r, risc_adr_w;
logic [RISC_DWIDTH-1:0]             risc_di_r;
logic 	        					risc_rdy_r;

logic [AXI_ADDR_WIDTH-1:0]          axi_mem_base;
logic [AXI_ADDR_WIDTH-1:0]          axi_awaddr_t;
logic [AXI_ADDR_WIDTH-1:0]          axi_araddr_t;
logic [AXI_ADDR_WIDTH-1:0]          axi_awaddr_1_t;
logic [AXI_ADDR_WIDTH-1:0]          axi_araddr_1_t;

//=================================================================================
// Riscv cmd
//=================================================================================
assign risc_cmd_en = 0; //risc_adr[XMEM_CONFIG_ABIT];


always @ (posedge clk or negedge rstn) begin
	if (~rstn) begin
		sBank 		 				<= 0;
		dPort  		 				<= 0;
		aPort		 				<= 0;
		part						<= 0;
		partNum 					<= 0;
		rangeStart					<= '{default: '0};
		//For dualport bank 	(SCALAR BANK)
		scalar_mux_num   			<= '{default: '0};
		//scalar_base 	 			<= '{default: '0};

		scalar_in2Type	 			<= '{default: '0};
		//scalar_in2Width  			<= '{default: '0};
		//scalar_in2Wport  			<= '{default: '0};
		//--
		scalar_subRangeStart		<= '{default: '0};
		scalar_subBankStart			<= '{default: '0};
		scalar_subBankSize			<= '{default: '0};

		//For single port bank 	(ARRAY BANK)
		array_mux_num	 			<= '{default: '0};
		//array_base 		 			<= '{default: '0};
		array_in2Type	 			<= '{default: '0};
		//array_in2Width   			<= '{default: '0};
		//array_in2Wport   			<= '{default: '0};
		//--
		array_subRangeStart			<= '{default: '0};
		array_subBankStart			<= '{default: '0};
		array_subBankSize			<= '{default: '0};

		//For wide port bank 	(CYCLIC BANK)
		cyclic_mux_num   			<= '{default: '0};
		//cyclic_base 	 			<= '{default: '0};
		cyclic_in2Type	 			<= '{default: '0};
		//cyclic_in2Width  			<= '{default: '0};
		//cyclic_in2Wport 			<= '{default: '0};
		//--
		cyclic_subRangeStart		<= '{default: '0};
        cyclic_max_subRangeStart    <= '{default: '0};
		cyclic_subBankStart	<= '{default: '0};
		cyclic_subBankSize	<= '{default: '0};
		//--
        axi_mem_base                <= 0;
        //--
        scalar_matched_r            <= '{default: '0};
        array_matched_r             <= '{default: '0};
        cyclic_matched_r            <= '{default: '0};
        risc_do <= 0;
        risc_do_vld <= 0;

		scalar_mux_ready 			<= '{default: '1};


        {risc_cmd_en_r2, risc_cmd_en_r}  <= 0;
        risc_we_r <= 0;
        {risc_re_r2, risc_re_r} <= 0;
        risc_adr_r <= 0;
        risc_di_r <= 0;
        partIdx_r <= 0;
        act_req_r <= 0;
        risc_rdy_r	<= 1;
    end
	else begin

		if (risc_cfg) begin
//			case (risc_adr[7:0])
			case (risc_cfg_adr[9:2])
			CMD_SET_SBANK: 	 	 		sBank 									<= risc_cfg_di;
			CMD_SET_RPORT: 	 	 		dPort 									<= risc_cfg_di;
			CMD_SET_APORT: 	 	 		aPort 									<= risc_cfg_di;
			CMD_SET_PART: 			 	part									<= risc_cfg_di;
			CMD_PART_NUM: 			 	partNum 								<= risc_cfg_di;
			CMD_RANGE_START:		 	rangeStart	[part]						<= risc_cfg_di;
			//For SCALAR range
			CMD_SCALAR_MUX_NUM: 	 	scalar_mux_num	[sBank][dPort] 			<= risc_cfg_di;
			//CMD_SCALAR_BASE:		 	scalar_base 	[sBank][dPort][aPort]	<= risc_cfg_di;
			CMD_SCALAR_TYPE:  		 	scalar_in2Type	[sBank][dPort][aPort] 	<= risc_cfg_di;
			//CMD_SCALAR_WIDTH: 		 	scalar_in2Width	[sBank][dPort][aPort] 	<= risc_cfg_di;
			//CMD_SCALAR_WPORT: 		 	scalar_in2Wport	[sBank][dPort][aPort] 	<= risc_cfg_di;
			//--
			CMD_SCALAR_SUB_PART_START:	scalar_subBankStart[part]			    <= risc_cfg_di;
			CMD_SCALAR_SUB_PART_SIZE:	scalar_subBankSize[part]				<= risc_cfg_di;

			//For ARRAY range
			CMD_ARRAY_MUX_NUM: 		 	array_mux_num	[sBank] 				<= risc_cfg_di;
			//CMD_ARRAY_BASE:			 	array_base 		[sBank][aPort]			<= risc_cfg_di;
			CMD_ARRAY_TYPE:  		 	array_in2Type	[sBank][aPort] 			<= risc_cfg_di;
			//CMD_ARRAY_WIDTH: 		 	array_in2Width	[sBank][aPort] 			<= risc_cfg_di;
			//CMD_ARRAY_WPORT: 		 	array_in2Wport	[sBank][aPort] 			<= risc_cfg_di;
			//--
			CMD_ARRAY_SUB_RNG_START:	array_subRangeStart		[part]			<= risc_cfg_di;
			CMD_ARRAY_SUB_PART_START:	array_subBankStart	[part]			    <= risc_cfg_di;
			CMD_ARRAY_SUB_PART_SIZE:	array_subBankSize	[part]			    <= risc_cfg_di;
			//For CYCLIC range
			CMD_CYCLIC_MUX_NUM: 	 	cyclic_mux_num	[sBank]  				<= risc_cfg_di;
			//CMD_CYCLIC_BASE: 			cyclic_base 	[sBank][aPort]			<= risc_cfg_di;
			CMD_CYCLIC_TYPE: 		 	cyclic_in2Type	[sBank][aPort]			<= risc_cfg_di;
			//CMD_CYCLIC_WIDTH: 		 	cyclic_in2Width	[sBank][aPort]			<= risc_cfg_di;
			//CMD_CYCLIC_WPORT:		 	cyclic_in2Wport	[sBank][aPort]			<= risc_cfg_di;
			//--
			CMD_CYCLIC_SUB_RNG_START:	cyclic_subRangeStart	[part]			<= risc_cfg_di;
			CMD_CYCLIC_MAX_SUB_RNG_START:	cyclic_max_subRangeStart[part]		<= risc_cfg_di;
			CMD_CYCLIC_SUB_PART_START:	cyclic_subBankStart[part]			    <= risc_cfg_di;
			CMD_CYCLIC_SUB_PART_SIZE:	cyclic_subBankSize[part]			<= risc_cfg_di;
            //--
            CMD_AXI_MEM_BASE:           axi_mem_base			                <= risc_cfg_di;
			endcase
		end

        //edward
        {risc_cmd_en_r2, risc_cmd_en_r} <= {risc_cmd_en_r, risc_cmd_en};
        risc_rdy_r	<= risc_rdy;
        if (risc_rdy) begin
            //edward 2025-01-22: match set as one only riscv access
            for (int s=0; s<BANK_NUM[MEM_TYPE_SCALAR]; s++) begin
                scalar_matched_r[s] <= scalar_matched[s] && (risc_we!=0 || risc_re!=0);
            end
            for (int s=0; s<BANK_NUM[MEM_TYPE_ARRAY]; s++) begin
                array_matched_r[s]  <= array_matched[s] && (risc_we!=0 || risc_re!=0);
            end
`ifdef ENABLE_CYCLIC_BANK
            for (int s=0; s<BANK_NUM[MEM_TYPE_CYCLIC]; s++) begin
                cyclic_matched_r[s] <= cyclic_matched[s] && (risc_we!=0 || risc_re!=0);
            end
`endif
            risc_we_r               <= risc_we;
            {risc_re_r2, risc_re_r} <= {risc_re_r, risc_re};
            risc_adr_r              <= risc_adr_w;
            risc_di_r               <= risc_di;
            partIdx_r               <= partIdx_w;
            act_req_r               <= act_req;
        end
        risc_do <= risc_do_w;
        risc_do_vld <= risc_do_vld_w;
	end
end


always_comb begin
    act_req = risc_re_r && ~risc_cmd_en_r && found;

    scalar_base_upd = '{default: '0};
    //scalar_in2Type_upd = '{default: '0};
    scalar_in2Width_upd = '{default: '0};
    array_base_upd = '{default: '0};
    //array_in2Type_upd = '{default: '0};
    array_in2Width_upd = '{default: '0};
    cyclic_base_upd = '{default: '0};
    //cyclic_in2Type_upd = '{default: '0};
    cyclic_in2Width_upd = '{default: '0};
    if (risc_cfg) begin
        case (risc_cfg_adr[9:2])
            CMD_SCALAR_BASE:  scalar_base_upd[sBank][dPort][aPort] = 1;
            //CMD_SCALAR_TYPE:  scalar_in2Type_upd [sBank][dPort][aPort] 	= 1;
            CMD_SCALAR_WIDTH: scalar_in2Width_upd[sBank][dPort][aPort] 	= 1;
            CMD_ARRAY_BASE:   array_base_upd[sBank][aPort] = 1;
            //CMD_ARRAY_TYPE:   array_in2Type_upd [sBank][aPort] 	= 1;
            CMD_ARRAY_WIDTH:  array_in2Width_upd[sBank][aPort] 	= 1;
            CMD_CYCLIC_BASE:  cyclic_base_upd[sBank][aPort] = 1;
            //CMD_CYCLIC_TYPE:  cyclic_in2Type_upd [sBank][aPort] 	= 1;
            CMD_CYCLIC_WIDTH: cyclic_in2Width_upd[sBank][aPort] 	= 1;
        endcase
    end
end

always_comb begin
    //risc_rdy = risc_rdy_r;
    risc_rdy = (~risc_re_r & (risc_we_r == 0)) | risc_cmd_en_r;
    found = 0;
    for (int s=0; s<BANK_NUM[MEM_TYPE_SCALAR]; s++) begin
		if (scalar_matched_r[s] && ~found) begin
			risc_rdy = 1;
            found = 1;
		end
	end
	for (int s=0; s<BANK_NUM[MEM_TYPE_ARRAY]; s++) begin
		if (array_matched_r[s] && ~found) begin
			risc_rdy = risc_argRdy_array[s];
            found = 1;
		end
	end
`ifdef ENABLE_CYCLIC_BANK
	for (int s=0; s<BANK_NUM[MEM_TYPE_CYCLIC]; s++) begin
		if (cyclic_matched_r[s] && ~found) begin
			risc_rdy = risc_argRdy_cyclic[s];
			found = 1;
		end
	end
`endif

    risc_do_w = 0;
	risc_do_vld_w = 0;
    found = 0;
	for (int s=0; s<BANK_NUM[MEM_TYPE_SCALAR]; s++) begin
		if (risc_argRunning_r_scalar[s][0] && ~found) begin
			risc_do_w = risc_do_scalar[s][0];
			risc_do_vld_w	= risc_re_r2;
			found = 1;
		end
	end
	for (int s=0; s<BANK_NUM[MEM_TYPE_ARRAY]; s++) begin
		if (risc_argRunning_r_array[s] && ~found) begin
			risc_do_w 		= risc_do_array		[s];
			risc_do_vld_w	= risc_do_vld_array	[s];
			found = 1;
		end
	end
`ifdef ENABLE_CYCLIC_BANK
	for (int s=0; s<BANK_NUM[MEM_TYPE_CYCLIC]; s++) begin
		if (risc_argRunning_r_cyclic[s] && ~found) begin
			risc_do_w 		= risc_do_cyclic	[s];
			risc_do_vld_w	= risc_do_vld_cyclic[s];
			found = 1;
		end
	end
`endif
end

//=================================================================================
//ReqMux and Xmemory
//=================================================================================

//edward 2025-01-27: partition index either from risc_part or embedded in risc_adr.
assign partIdx_w = (risc_part != 0)? risc_part : risc_adr[XMEM_PART_AW+PART_IDX_W-1 : XMEM_PART_AW];//risc_adr[XMEM_AW+LOG2_MAX_PARTITION-1 : XMEM_AW];

always_comb begin
    for (int pid=0; pid<MAX_PARTITION; pid++) begin
        subRangeStart[pid][MEM_TYPE_ARRAY-1] = array_subRangeStart[pid];
        subBankSize[pid][MEM_TYPE_ARRAY-1] = scalar_subBankSize[pid];
        subRangeStart[pid][MEM_TYPE_ARRAY] = cyclic_subRangeStart[pid];
        subBankSize[pid][MEM_TYPE_ARRAY] = array_subBankSize[pid];
        subBankSize[pid][MEM_TYPE_CYCLIC] = cyclic_subBankSize[pid];
    end
end

bank_filter_v2 inst_bank_filter (
    //edward 2025-01-22: new address mapping that no parition for array & cyclc.
    //.adr				( risc_adr[XMEM_PART_AW-1:0]    ),	//global address from RISCV
    .adr				( risc_adr[XMEM_AW-1:0]         ),
    .adr_o              ( risc_adr_w[XMEM_AW-1:0]       ),
    //.partIdx			( partIdx_w					    ),
    .risc_cmd_en        ( risc_cmd_en                   ),
    //From Risc
    .rangeStart			( rangeStart				    ),
    .subRangeStart		( subRangeStart		            ),
    .subBankSize	    ( subBankSize	                ),
    //--
    .matched_scalar		( scalar_matched                ),
    .matched_array		( array_matched                 ),
    .matched_cyclic		( cyclic_matched                )
);

generate
	//---------------------------------------------------------------
	//	SCALAR RANGE
	//---------------------------------------------------------------
	for (genvar s=0; s<BANK_NUM[MEM_TYPE_SCALAR]; s++) begin: SCALAR

		//------ request mux ------//
		for (genvar d=0; d<DUAL_PORT; d++) begin: DP
            localparam LOG_MUX_NUM   = (SCALAR_BANK_MUX_NUM[s][d] == 1) ? 1 : $clog2(SCALAR_BANK_MUX_NUM[s][d]);
            /*logic [XMEM_AW-1:0]		scalar_base_w		[SCALAR_BANK_MUX_NUM[s][d]];
            logic [XMEM_AW-1:0]		scalar_base_r		[SCALAR_BANK_MUX_NUM[s][d]];*/
            logic [1:0]				scalar_in2Type_w	[SCALAR_BANK_MUX_NUM[s][d]];
            //logic [7:0]				scalar_in2Width_w	[SCALAR_BANK_MUX_NUM[s][d]];
            //logic [7:0]				scalar_in2Wport_w	[SCALAR_BANK_MUX_NUM[s][d]];

            logic [XMEM_AW-1:0]         scalar_base_wdat;
            logic [LOG_MUX_NUM-1:0]     scalar_base_wadr;
            logic                       scalar_base_we;

            /*logic [1:0]                 scalar_in2Type_wdat;
            logic [LOG_MUX_NUM-1:0]     scalar_in2Type_wadr;
            logic                       scalar_in2Type_we;*/

            logic [7:0]                 scalar_in2Width_wdat;
            logic [LOG_MUX_NUM-1:0]     scalar_in2Width_wadr;
            logic                       scalar_in2Width_we;

            logic 						scalar_argVld_w	[SCALAR_BANK_MUX_NUM[s][d]];
            logic  						scalar_argAck_w [SCALAR_BANK_MUX_NUM[s][d]];
            logic [XMEM_AW-1:0]	        scalar_adr_w	[SCALAR_BANK_MUX_NUM[s][d]];
            logic [SCALAR_BANK_DW-1:0]	scalar_wdat_w	[SCALAR_BANK_MUX_NUM[s][d]];
        	logic [SCALAR_BANK_DW-1:0]	scalar_rdat_w   [SCALAR_BANK_MUX_NUM[s][d]];
        	logic                       scalar_rdat_vld_w[SCALAR_BANK_MUX_NUM[s][d]];

            always @(*) begin
                //scalar_base_w = scalar_base_r;
                scalar_base_wadr = 0;
                scalar_base_wdat = risc_cfg_di;
                scalar_base_we = 0;

                /*scalar_in2Type_wadr = 0;
                scalar_in2Type_wdat = risc_cfg_di;
                scalar_in2Type_we = 0;*/

                scalar_in2Width_wadr = 0;
                scalar_in2Width_wdat = risc_cfg_di;
                scalar_in2Width_we = 0;

                for (int m=0; m<SCALAR_BANK_MUX_NUM[s][d]; m++) begin
                    if (scalar_base_upd[s][d][m]) begin
                        //scalar_base_w    [m]   = risc_cfg_di;//scalar_base[s][d][m];
                        scalar_base_wadr = m;
                        scalar_base_we = 1;
                    end

                    /*if (scalar_in2Type_upd[s][d][m]) begin
                        scalar_in2Type_wadr = m;
                        scalar_in2Type_we = 1;
                    end*/

                    if (scalar_in2Width_upd[s][d][m]) begin
                        scalar_in2Width_wadr = m;
                        scalar_in2Width_we = 1;
                    end

                    scalar_in2Type_w [m]   = scalar_in2Type[s][d][m];
                    //scalar_in2Width_w[m]   = scalar_in2Width[s][d][m];
                    //scalar_in2Wport_w[m]   = scalar_in2Wport[s][d][m];

                    scalar_argVld_w [m]    = scalar_argVld [s][d][m];
                    scalar_adr_w    [m]    = scalar_adr    [s][d][m];
                    scalar_wdat_w   [m]    = scalar_wdat   [s][d][m];

                    /*for (int m=0; m<SCALAR_MAX_MUX_NUM; m++) begin
                        if (m<SCALAR_BANK_MUX_NUM[s][d]) begin
                            scalar_rdat_vld[s][d][m] = scalar_rdat_vld_w[m];
                        end
                        else begin
                            scalar_rdat_vld[s][d][m] = 0;
                        end
                    end
                    scalar_rdat[s][d] = scalar_rdat_w;*/
                end
            end

            //edward 2025-02-14: make it as comibination because custom_connection will register read data
            //                   no need to check risc access that is alreay done in reqMux
            always_comb begin
                for (int m=0; m<SCALAR_MAX_MUX_NUM; m++) begin
					if (m<SCALAR_BANK_MUX_NUM[s][d]) begin
						scalar_argAck[s][d][m] = scalar_argAck_w[m];
						scalar_rdat_vld[s][d][m] = scalar_rdat_vld_w[m]; //&& ~(scalar_matched[s]  && ~risc_cmd_en && (risc_we!=0 || risc_re!=0));
        				scalar_rdat[s][d][m] = scalar_rdat_w[m];
					end
					else begin
						scalar_argAck[s][d][m] = 0;
						scalar_rdat_vld[s][d][m] = 0;
        				scalar_rdat[s][d][m] = 0;
					end
                end
            end

			reqMux_v4 #(
				.RANGE_TYPE 	( "SCALAR"					),
				.MUX_NUM	    ( SCALAR_BANK_MUX_NUM[s][d]	),
                .LOG_MUX_NUM    ( LOG_MUX_NUM               ),
				.AW				( XMEM_AW          			),
				.DW				( SCALAR_BANK_DW			),
                .PORT_IDX       ( d                         )
			)
			inst_reqMux_scalar(
				.rstn			( rstn						),
				.clk			( clk						),

                .base_mem_wdat  ( scalar_base_wdat          ),
                .base_mem_wadr  ( scalar_base_wadr          ),
                .base_mem_we    ( scalar_base_we            ),

                /*.in2Type_mem_wdat  ( scalar_in2Type_wdat          ),
                .in2Type_mem_wadr  ( scalar_in2Type_wadr          ),
                .in2Type_mem_we    ( scalar_in2Type_we            ),*/

                .in2Width_mem_wdat  ( scalar_in2Width_wdat          ),
                .in2Width_mem_wadr  ( scalar_in2Width_wadr          ),
                .in2Width_mem_we    ( scalar_in2Width_we            ),

				//the config registers
				.rangeStart			( rangeStart				),
				//.base 				( /*scalar_base_w*/	   	    ),	//byte address
				.in2Type			( scalar_in2Type_w	    	),
				//.in2Width			( scalar_in2Width_w	    	),
				//connnect to functional accelerator
                .f_ap_ce            ( '{default:1'b1}                   ),
				.f_argRdy			(									),
				.f_argVld			( scalar_argVld_w	    			),
				.f_argAck			( scalar_argAck_w	    			),
				.f_adr				( scalar_adr_w		    			),
				.f_wdat				( scalar_wdat_w		    			),
				.f_rdat				( scalar_rdat_w             		),
				.f_rdat_vld			( scalar_rdat_vld_w         		),
                //--
    			.matched			( scalar_matched_r		   [s]		),
				.risc_argRunning_r	( risc_argRunning_r_scalar [s][d]	),
				.risc_argRdy		( risc_argRdy_scalar	   [s][d]	),
                .risc_argWe     	( risc_we_r                 		),
                .risc_argRe     	( risc_re_r                 		),
                .risc_argAck    	( risc_argAck_scalar	   [s][d]   ),
                .risc_argAdr    	( risc_adr_r[XMEM_AW-1:0]   		),
                .risc_argPartIdx	( partIdx_r                 		),
                .risc_argWdat   	( risc_di_r                 	 	),
                .risc_argRdat   	( risc_do_scalar		   [s][d]   ),
                .risc_argRdat_vld   ( risc_do_vld_scalar	   [s][d]   ),
				//--
				.mux_ready			( scalar_mux_ready		[s][d]	),
				.mux_re				( scalar_mux_re 		[s][d]	),
				.mux_we				( scalar_mux_we 		[s][d]	),
				.mux_len			( scalar_mux_len		[s][d]	),
				.mux_adr			( scalar_mux_adr		[s][d]	),
                .mux_part_idx   	( scalar_mux_part_idx	[s][d]	),
				.mux_din			( scalar_mux_din		[s][d]	),
				.mux_dout			( scalar_mux_dout		[s][d]	),
				.mux_dout_vld 		( scalar_mux_dout_vld	[s][d]	)
			);

			//------ cal bankAdr ------//
			cal_bankAdr_v2 #(
				.RANGE_TYPE 		( "SCALAR"					),
				.BANK_ADR_WIDTH 	( SCALAR_BANK_BYTE_AW		)
			)
			inst_cal_bankAdr_scalar  (
				.adr				( scalar_mux_adr	[s][d]	), 				//global address
				.partIdx			( scalar_mux_part_idx [s][d]),
				//From Risc
				.subRangeStart		( scalar_subRangeStart		),		//set to 0
				.subBankStart	    ( scalar_subBankStart	    ),
				.subBankSize	    ( scalar_subBankSize	    ),
				//
				.bankAdr			( scalar_mux_bankAdr[s][d]	)
			);

		end


		assign scalar_mux_re0		[s]		= scalar_mux_re[s][0];
		assign scalar_mux_re1		[s]		= scalar_mux_re[s][1];

		assign scalar_mux_we0		[s]		= scalar_mux_we[s][0];
		assign scalar_mux_we1		[s]		= scalar_mux_we[s][1];

		assign scalar_mux_len0		[s]		= scalar_mux_len[s][0];
		assign scalar_mux_len1		[s]		= scalar_mux_len[s][1];

		assign scalar_mux_bankAdr0	[s]		= scalar_mux_bankAdr[s][0];
		assign scalar_mux_bankAdr1	[s]		= scalar_mux_bankAdr[s][1];

		assign scalar_mux_din0		[s]		= scalar_mux_din[s][0];
		assign scalar_mux_din1		[s]		= scalar_mux_din[s][1];

		assign scalar_mux_dout		[s][0]	= scalar_mux_dout0[s];
		assign scalar_mux_dout		[s][1]	= scalar_mux_dout1[s];

		assign scalar_mux_dout_vld	[s][0]	= scalar_mux_dout0_vld[s];
		assign scalar_mux_dout_vld	[s][1]	= scalar_mux_dout1_vld[s];



		//------ scalar bank ------//
		scalar_bank_v2 #(
			.AW			( SCALAR_BANK_AW 		),
			.BYTE_AW	( SCALAR_BANK_BYTE_AW 	),
			.DW			( SCALAR_BANK_DW 		)
		)
		inst_scalar_bank (
			.clk		( clk 						),
			.re0 		( scalar_mux_re0		[s] ),
			.re1 		( scalar_mux_re1		[s]	),
			.we0		( scalar_mux_we0 		[s]	),
			.we1		( scalar_mux_we1		[s]	),
			.len0		( scalar_mux_len0		[s]	),
			.len1		( scalar_mux_len1		[s]	),
			.adr0		( scalar_mux_bankAdr0	[s] ),
			.adr1		( scalar_mux_bankAdr1	[s]	),
			.din0		( scalar_mux_din0		[s] ),
			.din1		( scalar_mux_din1		[s]	),
			.dout0		( scalar_mux_dout0		[s]	),
			.dout1		( scalar_mux_dout1		[s]	),
			.dout0_vld	( scalar_mux_dout0_vld	[s]	),
			.dout1_vld	( scalar_mux_dout1_vld	[s]	)
		);
	end

	//---------------------------------------------------------------
	//	ARRAY RANGE
	//---------------------------------------------------------------
	for (genvar s=0; s<BANK_NUM[MEM_TYPE_ARRAY]; s++) begin: ARRAY
        localparam LOG_MUX_NUM   = (ARRAY_BANK_MUX_NUM[s] == 1) ? 1 : $clog2(ARRAY_BANK_MUX_NUM[s]);

        //logic [XMEM_AW-1:0]		array_base_w		[ARRAY_BANK_MUX_NUM[s]];
        logic [1:0]				array_in2Type_w	    [ARRAY_BANK_MUX_NUM[s]];
        //logic [7:0]				array_in2Width_w	[ARRAY_BANK_MUX_NUM[s]];
        //logic [7:0]				array_in2Wport_w	[ARRAY_BANK_MUX_NUM[s]];

        logic [XMEM_AW-1:0]         array_base_wdat;
        logic [LOG_MUX_NUM-1:0]     array_base_wadr;
        logic                       array_base_we;

        /*logic [1:0]                 array_in2Type_wdat;
        logic [LOG_MUX_NUM-1:0]     array_in2Type_wadr;
        logic                       array_in2Type_we;*/

        logic [7:0]                 array_in2Width_wdat;
        logic [LOG_MUX_NUM-1:0]     array_in2Width_wadr;
        logic                       array_in2Width_we;

        logic 						array_argRdy_w	[ARRAY_BANK_MUX_NUM[s]];
        logic 						array_ap_ce_w	[ARRAY_BANK_MUX_NUM[s]];
        logic 						array_argVld_w	[ARRAY_BANK_MUX_NUM[s]];
        logic  						array_argAck_w  [ARRAY_BANK_MUX_NUM[s]];
        logic [XMEM_AW-1:0]	        array_adr_w	    [ARRAY_BANK_MUX_NUM[s]];
        logic [ARRAY_BANK_DW-1:0]	array_wdat_w	[ARRAY_BANK_MUX_NUM[s]];
        logic [ARRAY_BANK_DW-1:0]	array_rdat_w    [ARRAY_BANK_MUX_NUM[s]];
        logic                       array_rdat_vld_w[ARRAY_BANK_MUX_NUM[s]];

        always @(*) begin
            array_base_wadr = 0;
            array_base_wdat = risc_cfg_di;
            array_base_we = 0;

            /*array_in2Type_wadr = 0;
            array_in2Type_wdat = risc_cfg_di;
            array_in2Type_we = 0;*/

            array_in2Width_wadr = 0;
            array_in2Width_wdat = risc_cfg_di;
            array_in2Width_we = 0;

            for (int m=0; m<ARRAY_BANK_MUX_NUM[s]; m++) begin
                //array_base_w    [m]   = array_base[s][m];
                if (array_base_upd[s][m]) begin
                    array_base_wadr = m;
                    array_base_we = 1;
                end

                /*if (array_in2Type_upd[s][m]) begin
                    array_in2Type_wadr = m;
                    array_in2Type_we = 1;
                end*/

                if (array_in2Width_upd[s][m]) begin
                    array_in2Width_wadr = m;
                    array_in2Width_we = 1;
                end

                array_in2Type_w [m]   = array_in2Type[s][m];
                //array_in2Width_w[m]   = array_in2Width[s][m];
                //array_in2Wport_w[m]   = array_in2Wport[s][m];

                array_argVld_w [m]    = array_argVld 	[s][m];
				array_ap_ce_w  [m]	  = array_ap_ce  	[s][m];
                array_adr_w    [m]    = array_adr    	[s][m];
                array_wdat_w   [m]    = array_wdat   	[s][m];
            end

            for (int m=0; m<ARRAY_MAX_MUX_NUM; m++) begin
                if (m<ARRAY_BANK_MUX_NUM[s]) begin
					array_argRdy 	[s][m] = array_argRdy_w  	[m];
                    array_rdat_vld	[s][m] = array_rdat_vld_w	[m];
                    array_rdat		[s][m] = array_rdat_w		[m];
                end
                else begin
					array_argRdy 	[s][m] = 0;
                    array_rdat_vld	[s][m] = 0;
                    array_rdat		[s][m] = 0;
                end
            end
            //array_rdat[s] = array_rdat_w;
        end


        //edward 2025-02-14: make it as comibination but array ack is not used by by custom connection        
        //                   no need to check risc access that is alreay done in reqMux
		always_comb begin
			for (int m=0; m<ARRAY_MAX_MUX_NUM; m++) begin
				if (m<ARRAY_BANK_MUX_NUM[s]) begin
					array_argAck[s][m] = array_argAck_w[m] && ~(array_matched[s]  && ~risc_cmd_en && (risc_we!=0 || risc_re!=0));
				end
				else begin
					array_argAck[s][m] = 0;
				end
			end
		end


		//------ request mux ------//
		reqMux_v4 #(
			.RANGE_TYPE 	( "ARRAY"				),
			.MUX_NUM	    ( ARRAY_BANK_MUX_NUM[s]	),
            .LOG_MUX_NUM    ( LOG_MUX_NUM           ),
			.AW				( XMEM_AW   			),
			.DW				( ARRAY_BANK_DW			),
            .PORT_IDX       ( 0                     )
		)
		inst_reqMux_array (
			.rstn				( rstn						),
			.clk				( clk						),

            .base_mem_wdat      ( array_base_wdat           ),
            .base_mem_wadr      ( array_base_wadr           ),
            .base_mem_we        ( array_base_we             ),

            /*.in2Type_mem_wdat  ( array_in2Type_wdat          ),
            .in2Type_mem_wadr  ( array_in2Type_wadr          ),
            .in2Type_mem_we    ( array_in2Type_we            ),*/

            .in2Width_mem_wdat  ( array_in2Width_wdat          ),
            .in2Width_mem_wadr  ( array_in2Width_wadr          ),
            .in2Width_mem_we    ( array_in2Width_we            ),

			//the config registers
			.rangeStart			( rangeStart				),
			//.base 				( /*array_base_w*/			),	//byte address
			.in2Type			( array_in2Type_w			),
			//.in2Width			( array_in2Width_w			),
			//connnect to functional accelerator
			.f_argRdy			( array_argRdy_w			),
			.f_ap_ce 			( array_ap_ce_w				),
			.f_argVld			( array_argVld_w			),
			.f_argAck			( array_argAck_w			),
			.f_adr				( array_adr_w				),
			.f_wdat				( array_wdat_w	        	),
			.f_rdat				( array_rdat_w          	),
			.f_rdat_vld			( array_rdat_vld_w      	),
            //--
			.matched			( array_matched_r		  [s]	),
			.risc_argRunning_r	( risc_argRunning_r_array [s]	),
			.risc_argRdy		( risc_argRdy_array		  [s]	),
            .risc_argWe     	( risc_we_r               		),
            .risc_argRe     	( risc_re_r               		),
            .risc_argAck    	( risc_argAck_array		  [s]  	),
            .risc_argAdr    	( risc_adr_r[XMEM_AW-1:0]   	),
            .risc_argPartIdx	( partIdx_r                		),
            .risc_argWdat   	( risc_di_r               		),
            .risc_argRdat   	( risc_do_array		[s]    		),
            .risc_argRdat_vld   ( risc_do_vld_array	[s]    		),

			//--
			.mux_ready			( array_mux_ready	[s] 		),
			.mux_re				( array_mux_re 		[s]			),
			.mux_we				( array_mux_we 		[s]			),
			.mux_len			( array_mux_len		[s]			),
			.mux_adr			( array_mux_adr		[s] 		),
            .mux_part_idx   	( array_mux_part_idx[s] 		),
			.mux_din			( array_mux_din		[s] 		),
			.mux_dout			( array_mux_dout	[s]			),
			.mux_dout_vld		( array_mux_dout_vld[s]			)
		);

		//------ cal bankAdr ------//
		cal_bankAdr_v2 #(
			.RANGE_TYPE 		( "ARRAY"					),
			.BANK_ADR_WIDTH 	( ARRAY_BANK_BYTE_AW		)
		)
		inst_cal_bankAdr_array  (
			.adr				( array_mux_adr	[s]			), 		//global address
			.partIdx			( array_mux_part_idx[s]		),
			//From Risc
			.subRangeStart		( array_subRangeStart		),
			.subBankStart	    ( array_subBankStart	    ),
			.subBankSize	    ( array_subBankSize	  	 	),
			//
			.bankAdr			( array_mux_bankAdr[s]		)		//byte address
		);

	end

	array_mruCache_bank #(
		//Cache
		.AXI_LEN_W 			( AXI_LEN_W				),
		.DW 				( DW					),
		.AW 				( AW					),
		.ROLLBACK 			( ROLLBACK				),
		.CACHE_BYTE 		( CACHE_BYTE			),
		.CACHE_WAY  		( CACHE_WAY				),
		.CACHE_WORD_BYTE	( CACHE_WORD_BYTE		),
		.CACHE_LINE_LEN		( CACHE_LINE_LEN		),
		//AXI4
		.AXI_ADDR_WIDTH		( AXI_ADDR_WIDTH		),
		.AXI_DATA_WIDTH		( AXI_DATA_WIDTH		),
		.AXI_LEN_WIDTH  	( AXI_LEN_WIDTH			),
		.AXI_ID_WIDTH   	( AXI_ID_WIDTH 			)
	)
	inst_array_mruCache_bank (
		.clk				( clk				),
		.rstn				( rstn				),
		//--------------------------------------------
		//connected to array_mux_ready
		.array_mux_ready 	( array_mux_ready		),
		.array_mux_re 		( array_mux_re			),
		.array_mux_we 		( array_mux_we			),
		.array_mux_len		( array_mux_len			),
		.array_mux_bankAdr	( array_mux_bankAdr		),
		.array_mux_din		( array_mux_din			),
		.array_mux_dout		( array_mux_dout		),
		.array_mux_dout_vld	( array_mux_dout_vld	),
		//AXI4
		.axi_awready		( axi_awready			),
		.axi_awvalid		( axi_awvalid			),
		.axi_awaddr			( axi_awaddr_t			),
		.axi_awlen			( axi_awlen				),
		.axi_awid			( axi_awid				),
		.axi_awsize			( axi_awsize			),
		.axi_awburst		( axi_awburst			),
		.axi_awlock			( axi_awlock			),
		.axi_awcache		( axi_awcache			),
		.axi_awprot			( axi_awprot			),
		.axi_awqos			( axi_awqos				),
		.axi_awregion		( axi_awregion			),
		.axi_awuser			( axi_awuser			),
		.axi_wready			( axi_wready			),
		.axi_wvalid			( axi_wvalid			),
		.axi_wdata			( axi_wdata				),
		.axi_wstrb			( axi_wstrb				),
		.axi_wlast			( axi_wlast				),
		.axi_wid			( axi_wid				),
		.axi_wuser			( axi_wuser				),
		.axi_bready			( axi_bready			),
		.axi_bvalid			( axi_bvalid			),
		.axi_bresp			( axi_bresp				),
		.axi_bid			( axi_bid				),
		.axi_buser			( axi_buser				),
		.axi_arready		( axi_arready			),
		.axi_arvalid		( axi_arvalid			),
		.axi_araddr			( axi_araddr_t			),
		.axi_arlen			( axi_arlen				),
		.axi_arid			( axi_arid				),
		.axi_arsize			( axi_arsize			),
		.axi_arburst		( axi_arburst			),
		.axi_arlock			( axi_arlock			),
		.axi_arcache		( axi_arcache			),
		.axi_arprot			( axi_arprot			),
		.axi_arqos			( axi_arqos				),
		.axi_arregion		( axi_arregion			),
		.axi_aruser			( axi_aruser			),
		.axi_rready			( axi_rready			),
		.axi_rvalid			( axi_rvalid			),
		.axi_rdata			( axi_rdata				),
		.axi_rlast			( axi_rlast				),
		.axi_rresp			( axi_rresp				),
		.axi_rid			( axi_rid				),
		.axi_ruser			( axi_ruser				)
	);
    assign axi_awaddr = axi_awaddr_t + axi_mem_base;
    assign axi_araddr = axi_araddr_t + axi_mem_base;

	//---------------------------------------------------------------
	//	CYCLIC RANGE
	//---------------------------------------------------------------
`ifdef ENABLE_CYCLIC_BANK
    always_comb begin
        risc_di_cyclic = risc_di_r;
    end

	for (genvar s=0; s<BANK_NUM[MEM_TYPE_CYCLIC]; s++) begin: CYCLIC
        localparam LOG_MUX_NUM   = (CYCLIC_BANK_MUX_NUM[s] == 1) ? 1 : $clog2(CYCLIC_BANK_MUX_NUM[s]);

        //logic [XMEM_AW-1:0]		cyclic_base_w		[CYCLIC_BANK_MUX_NUM[s]];
        logic [1:0]				cyclic_in2Type_w    [CYCLIC_BANK_MUX_NUM[s]];
        //logic [7:0]				cyclic_in2Width_w	[CYCLIC_BANK_MUX_NUM[s]];
        //logic [7:0]				cyclic_in2Wport_w	[CYCLIC_BANK_MUX_NUM[s]];

        logic [XMEM_AW-1:0]         cyclic_base_wdat;
        logic [LOG_MUX_NUM-1:0]     cyclic_base_wadr;
        logic                       cyclic_base_we;

        logic [1:0]                 cyclic_in2Type_wdat;
        logic [LOG_MUX_NUM-1:0]     cyclic_in2Type_wadr;
        logic                       cyclic_in2Type_we;

        logic [7:0]                 cyclic_in2Width_wdat;
        logic [LOG_MUX_NUM-1:0]     cyclic_in2Width_wadr;
        logic                       cyclic_in2Width_we;

        logic 						cyclic_argRdy_w [CYCLIC_BANK_MUX_NUM[s]];
		logic 						cyclic_ap_ce_w 	[CYCLIC_BANK_MUX_NUM[s]];
        logic 						cyclic_argVld_w	[CYCLIC_BANK_MUX_NUM[s]];
        logic  						cyclic_argAck_w [CYCLIC_BANK_MUX_NUM[s]];
        logic [XMEM_AW-1:0]	        cyclic_adr_w    [CYCLIC_BANK_MUX_NUM[s]];
        logic [CYCLIC_BANK_DW-1:0]	cyclic_wdat_w	[CYCLIC_BANK_MUX_NUM[s]];
        logic [CYCLIC_BANK_DW-1:0]	cyclic_rdat_w   [CYCLIC_BANK_MUX_NUM[s]];
        logic                       cyclic_rdat_vld_w[CYCLIC_BANK_MUX_NUM[s]];

        always @(*) begin
            cyclic_base_wadr = 0;
            cyclic_base_wdat = risc_cfg_di;
            cyclic_base_we = 0;

            /*cyclic_in2Type_wadr = 0;
            cyclic_in2Type_wdat = risc_cfg_di;
            cyclic_in2Type_we = 0;*/

            cyclic_in2Width_wadr = 0;
            cyclic_in2Width_wdat = risc_cfg_di;
            cyclic_in2Width_we = 0;

            for (int m=0; m<CYCLIC_BANK_MUX_NUM[s]; m++) begin
                if (cyclic_base_upd[s][m]) begin
                    cyclic_base_wadr = m;
                    cyclic_base_we = 1;
                end

                /*if (cyclic_in2Type_upd[s][m]) begin
                    cyclic_in2Type_wadr = m;
                    cyclic_in2Type_we = 1;
                end*/

                if (cyclic_in2Width_upd[s][m]) begin
                    cyclic_in2Width_wadr = m;
                    cyclic_in2Width_we = 1;
                end

                //cyclic_base_w    [m]   = cyclic_base[s][m];
                cyclic_in2Type_w [m]   = cyclic_in2Type[s][m];
                //cyclic_in2Width_w[m]   = cyclic_in2Width[s][m];
                //cyclic_in2Wport_w[m]   = cyclic_in2Wport[s][m];

                cyclic_argVld_w [m]    = cyclic_argVld [s][m];
                cyclic_ap_ce_w  [m]    = cyclic_ap_ce  [s][m];
                cyclic_adr_w    [m]    = cyclic_adr    [s][m];
                cyclic_wdat_w   [m]    = cyclic_wdat   [s][m];
            end


            for (int m=0; m<CYCLIC_MAX_MUX_NUM; m++) begin
                if (m<CYCLIC_BANK_MUX_NUM[s]) begin
					cyclic_argRdy	[s][m] = cyclic_argRdy_w	[m];
                    cyclic_rdat_vld	[s][m] = cyclic_rdat_vld_w	[m];
                    cyclic_rdat		[s][m] = cyclic_rdat_w		[m];
                end
                else begin
                    cyclic_rdat_vld[s][m] = 0;
                    cyclic_rdat[s][m] = 0;
                end
            end
        end

        //edward 2025-02-14: make it as comibination but cyclic ack is not used by by custom connection        
        //                   no need to check risc access that is alreay done in reqMux
		always_comb begin
			for (int m=0; m<CYCLIC_MAX_MUX_NUM; m++) begin
				if (m<CYCLIC_BANK_MUX_NUM[s]) begin
					cyclic_argAck[s][m] = cyclic_argAck_w[m]; // && ~(cyclic_matched[s]  && ~risc_cmd_en && (risc_we!=0 || risc_re!=0));
				end
				else begin
					cyclic_argAck[s][m] = 0;
				end
			end			
		end

		//------ request mux ------//
		reqMux_v4 #(
			.RANGE_TYPE 	( "CYCLIC"					),
			.MUX_NUM    	( CYCLIC_BANK_MUX_NUM[s]	),
            .LOG_MUX_NUM    ( LOG_MUX_NUM               ),
			.AW		        ( XMEM_AW       			),
			.DW		        ( CYCLIC_BANK_DW			),
            .PORT_IDX       ( 0                         )
		)
		inst_reqMux_cyclic (
			.rstn				( rstn					        ),
			.clk				( clk					        ),

            .base_mem_wdat      ( cyclic_base_wdat              ),
            .base_mem_wadr      ( cyclic_base_wadr              ),
            .base_mem_we        ( cyclic_base_we                ),

            /*.in2Type_mem_wdat  ( cyclic_in2Type_wdat          ),
            .in2Type_mem_wadr  ( cyclic_in2Type_wadr          ),
            .in2Type_mem_we    ( cyclic_in2Type_we            ),*/

            .in2Width_mem_wdat  ( cyclic_in2Width_wdat          ),
            .in2Width_mem_wadr  ( cyclic_in2Width_wadr          ),
            .in2Width_mem_we    ( cyclic_in2Width_we            ),

			//the config registers
			.rangeStart			( rangeStart					),
			//.base 				( /*cyclic_base_w*/   	        ),	//byte address
			.in2Type			( cyclic_in2Type_w  	        ),
			//.in2Width			( cyclic_in2Width_w 	        ),
			//connnect to functional accelerator
			.f_argRdy			( cyclic_argRdy_w				),
			.f_ap_ce 			( cyclic_ap_ce_w				),
			.f_argVld			( cyclic_argVld_w		        ),
			.f_argAck			( cyclic_argAck_w		        ),
			.f_adr				( cyclic_adr_w			        ),
			.f_wdat				( cyclic_wdat_w			        ),
			.f_rdat				( cyclic_rdat_w                 ),
			.f_rdat_vld			( cyclic_rdat_vld_w             ),
            //--
			.matched			( cyclic_matched_r [s]          ),
			.risc_argRunning_r	( risc_argRunning_r_cyclic [s]	),
			.risc_argRdy		( risc_argRdy_cyclic	   [s]	),
            .risc_argWe     	( risc_we_r                     ),
            .risc_argRe     	( risc_re_r                     ),
            .risc_argAck    	( risc_argAck_cyclic[s]         ),
            .risc_argAdr    	( risc_adr_r[XMEM_AW-1:0]       ),
            .risc_argPartIdx	( partIdx_r                 	),
            .risc_argWdat   	( risc_di_cyclic                ),
            .risc_argRdat   	( risc_do_cyclic		[s]     ),
			.risc_argRdat_vld 	( risc_do_vld_cyclic	[s]		),

			//--
			.mux_ready 			( cyclic_mux_ready		[s]		),
			.mux_re				( cyclic_mux_re 		[s]	    ),
			.mux_we				( cyclic_mux_we 		[s]	    ),
			.mux_len			( cyclic_mux_len		[s]	    ),
			.mux_adr			( cyclic_mux_adr		[s]     ),
            .mux_part_idx   	( cyclic_mux_part_idx 	[s]     ),
			.mux_din			( cyclic_mux_din		[s]     ),
			.mux_dout			( cyclic_mux_dout		[s]	    ),
			.mux_dout_vld		( cyclic_mux_dout_vld	[s]		)
		);

		//------ cal bankAdr ------//
		cal_bankAdr_v2 #(
			.RANGE_TYPE 	( "CYCLIC"				),
			.BANK_ADR_WIDTH ( CYCLIC_BANK_BYTE_AW	)
		)
		inst_cal_bankAdr_cyclic  (
			.adr				( cyclic_mux_adr	[s]		), 				//global address
			.partIdx			( cyclic_mux_part_idx[s]	),
			//From Risc
			.subRangeStart		( cyclic_subRangeStart		),
			.subBankStart	    ( cyclic_subBankStart	    ),
			.subBankSize	    ( cyclic_subBankSize	    ),
			//
			.bankAdr			( cyclic_mux_bankAdr[s]		)
		);

		//byte address --> word address
		assign cyclic_mux_wordAdr[s] = cyclic_mux_bankAdr[s]>>2;

	end

	cyclic_mruCache_bank #(
		//Cache
		.AXI_LEN_W          ( CYCLIC_CACHE_AXI_LEN_W		),
		.DW                 ( CYCLIC_CACHE_DW				),
		.AW                 ( CYCLIC_CACHE_AW				),
		.USER_DW 			( CYCLIC_CACHE_USER_DW			),
		.USER_MAX_LEN 		( CYCLIC_CACHE_USER_MAX_LEN 	),
		.CACHE_BYTE         ( CYCLIC_CACHE_BYTE				),
		.CACHE_WAY          ( CYCLIC_CACHE_WAY				),
		.CACHE_WORD_BYTE    ( CYCLIC_CACHE_WORD_BYTE		),
		.CACHE_LINE_LEN     ( CYCLIC_CACHE_LINE_LEN			),
		//AXI4
		.AXI_ADDR_WIDTH		( AXI_ADDR_WIDTH				),
		.AXI_DATA_WIDTH		( AXI_DATA_WIDTH				),
		.AXI_LEN_WIDTH  	( AXI_LEN_WIDTH					),
		.AXI_ID_WIDTH   	( AXI_ID_WIDTH 					)
	)
	inst_cyclic_mruCache_bank (
		.clk				( clk					),
		.rstn				( rstn					),
		//--------------------------------------------
		//connected to array_mux_ready
		.cyclic_mux_ready 	( cyclic_mux_ready		),	//o
		.cyclic_mux_re 		( cyclic_mux_re			),  //i
		.cyclic_mux_we 		( cyclic_mux_we			),  //i
		.cyclic_mux_len		( cyclic_mux_len		),  //i
		.cyclic_mux_bankAdr	( cyclic_mux_bankAdr	),  //i
		.cyclic_mux_din		( cyclic_mux_din		),  //i
		.cyclic_mux_dout	( cyclic_mux_dout		),  //o
		.cyclic_mux_dout_vld( cyclic_mux_dout_vld	),  //o
		//AXI4
		.axi_awready		( axi_awready_1			),	//i
		.axi_awvalid		( axi_awvalid_1			),  //o
		.axi_awaddr			( axi_awaddr_1_t		),  //o
		.axi_awlen			( axi_awlen_1			),  //o
		.axi_awid			( axi_awid_1			),  //o
		.axi_awsize			( axi_awsize_1			),  //o
		.axi_awburst		( axi_awburst_1			),  //o
		.axi_awlock			( axi_awlock_1			),  //o
		.axi_awcache		( axi_awcache_1			),  //o
		.axi_awprot			( axi_awprot_1			),  //o
		.axi_awqos			( axi_awqos_1			),  //o
		.axi_awregion		( axi_awregion_1		),  //o
		.axi_awuser			( axi_awuser_1			),  //o
		.axi_wready			( axi_wready_1			),  //i
		.axi_wvalid			( axi_wvalid_1			),  //o
		.axi_wdata			( axi_wdata_1			),  //o
		.axi_wstrb			( axi_wstrb_1			),  //o
		.axi_wlast			( axi_wlast_1			),  //o
		.axi_wid			( axi_wid_1				),  //o
		.axi_wuser			( axi_wuser_1			),  //o
		.axi_bready			( axi_bready_1			),  //o
		.axi_bvalid			( axi_bvalid_1			),  //i
		.axi_bresp			( axi_bresp_1			),  //i
		.axi_bid			( axi_bid_1				),  //i
		.axi_buser			( axi_buser_1			),  //i
		.axi_arready		( axi_arready_1			),  //i
		.axi_arvalid		( axi_arvalid_1			),  //o
		.axi_araddr			( axi_araddr_1_t		),  //o
		.axi_arlen			( axi_arlen_1			),  //o
		.axi_arid			( axi_arid_1			),  //o
		.axi_arsize			( axi_arsize_1			),  //o
		.axi_arburst		( axi_arburst_1			),  //o
		.axi_arlock			( axi_arlock_1			),  //o
		.axi_arcache		( axi_arcache_1			),  //o
		.axi_arprot			( axi_arprot_1			),  //o
		.axi_arqos			( axi_arqos_1			),  //o
		.axi_arregion		( axi_arregion_1		),  //o
		.axi_aruser			( axi_aruser_1			),  //o
		.axi_rready			( axi_rready_1			),  //o
		.axi_rvalid			( axi_rvalid_1			),  //i
		.axi_rdata			( axi_rdata_1			),  //i
		.axi_rlast			( axi_rlast_1			),  //i
		.axi_rresp			( axi_rresp_1			),  //i
		.axi_rid			( axi_rid_1				),  //i
		.axi_ruser			( axi_ruser_1			)	//i
	);
    assign axi_awaddr_1 = axi_awaddr_1_t + axi_mem_base;
    assign axi_araddr_1 = axi_araddr_1_t + axi_mem_base;

`else

    assign risc_argRdy_cyclic 		= '{default:'0};
    assign risc_argAck_cyclic		= '{default:'0};
    assign risc_di_cyclic           = '{default:'0};
    assign risc_do_cyclic			= '{default:'0};
    assign risc_do_vld_cyclic		= '{default:'0};
    assign risc_argRunning_r_cyclic = '{default:'0};
    assign cyclic_argRdy	        = '{default:'0};
	assign cyclic_argAck 	        = '{default:'0};
	assign cyclic_rdat		        = '{default:'0};
	assign cyclic_rdat_vld	        = '{default:'0};
	//connected to array_mux_ready
	assign cyclic_mux_ready		= '{default:'0};
    assign cyclic_mux_re 		= '{default:'0};
    assign cyclic_mux_we 		= '{default:'0};
    assign cyclic_mux_len		= '{default:'0};
    assign cyclic_mux_adr		= '{default:'0};
    assign cyclic_mux_part_idx	= '{default:'0};
    assign cyclic_mux_bankAdr	= '{default:'0};
    assign cyclic_mux_wordAdr	= '{default:'0};
    assign cyclic_mux_din		= '{default:'0};
    assign cyclic_mux_dout		= '{default:'0};
    assign cyclic_mux_dout_vld	= '{default:'0};
	//AXI4
	assign axi_awvalid_1		= 0;
	assign axi_awaddr_1			= 0;
	assign axi_awlen_1			= 0;
	assign axi_awid_1			= 0;
	assign axi_awsize_1			= 0;
	assign axi_awburst_1		= 0;
	assign axi_awlock_1			= 0;
	assign axi_awcache_1		= 0;
	assign axi_awprot_1			= 0;
	assign axi_awqos_1			= 0;
	assign axi_awregion_1		= 0;
	assign axi_awuser_1			= 0;
	assign axi_wvalid_1			= 0;
	assign axi_wdata_1			= 0;
	assign axi_wstrb_1			= 0;
	assign axi_wlast_1			= 0;
	assign axi_wid_1			= 0;
	assign axi_wuser_1			= 0;
	assign axi_bready_1			= 0;
	assign axi_arvalid_1		= 0;
	assign axi_araddr_1			= 0;
	assign axi_arlen_1			= 0;
	assign axi_arid_1			= 0;
	assign axi_arsize_1			= 0;
	assign axi_arburst_1		= 0;
	assign axi_arlock_1			= 0;
	assign axi_arcache_1		= 0;
	assign axi_arprot_1			= 0;
	assign axi_arqos_1			= 0;
	assign axi_arregion_1		= 0;
	assign axi_aruser_1			= 0;
	assign axi_rready_1			= 0;

`endif















endgenerate



//========================================================
//so debug
//========================================================
logic [31:0] p0;
logic [31:0] p1;
logic [31:0] p2;
logic [31:0] p3;

assign p0 = ARRAY_BANK_DEPTH;
assign p1 = ARRAY_BANK_NUM;
assign p2 = ARRAY_BANK_AW;
assign p3 = ARRAY_BANK_BYTE_AW;

endmodule






