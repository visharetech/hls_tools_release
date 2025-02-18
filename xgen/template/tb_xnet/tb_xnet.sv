`timescale 1ns/1ps


//-----------------------------------------------------------------------------------
/*

*** Because openhevc dosen't have cyclic memory. So we will test cyclic bank with xnet testbench later

*/
//-----------------------------------------------------------------------------------

module tb_xnet;


//-----------------------------------------------------------------------
//enum declaration
//-----------------------------------------------------------------------
enum {SCALAR, ARRAY, CYCLIC, RANGE_ALL} range_t;


//-----------------------------------------------------------------------
//import pkg file
//-----------------------------------------------------------------------
import xcache_param_pkg::*;
//import fill_ref_sample_pkg::*;
import hls_long_tail_pkg::*;

//-----------------------------------------------------------------------
//include parameter files
//-----------------------------------------------------------------------


`include "xmem_param.vh"



//-----------------------------------------------------------------------
//parameters:
//-----------------------------------------------------------------------
localparam HLS_ARG_WIDTH    = 32;
localparam HLS_ARG_VECTOR   = 8;
localparam HLS_RET_WIDTH    = 32;
localparam HLS_RET_VECTOR   = 1;
localparam XMEM_ADDR_WIDTH  = 20;
localparam XMEM_DATA_WIDTH  = 32;
localparam DMA_ADDR_WIDTH  = 20;
localparam DMA_DATA_WIDTH  = 32;




//AXI4
localparam int AXI_ADDR_WIDTH   = 32;
localparam int AXI_DATA_WIDTH   = 256;
localparam int AXI_LEN_WIDTH    = 8;
localparam int AXI_ID_WIDTH     = 8;
localparam int AXI_PORT_NUM     = 2;


//-----------------------------------------------------------------------
//signals
//-----------------------------------------------------------------------
logic 								clk;
logic 								rstn;

//HLS ap_ctrl
logic                               ap_ce       [HLS_NUM] = '{default: '0};
logic                               ap_arb_start[HLS_NUM] = '{default: '0};
logic                               ap_arb_ret	[HLS_NUM] = '{default: '0};

logic                               ap_start    [HLS_NUM];
logic [HLS_ARG_WIDTH - 1 : 0]       ap_arg      [HLS_NUM][HLS_ARG_VECTOR];
logic                               ap_ready    [HLS_NUM] = '{default: '0};
logic                               ap_idle     [HLS_NUM] = '{default: '0};
logic                               ap_done     [HLS_NUM] = '{default: '0};
logic [HLS_RET_WIDTH - 1 : 0]       ap_return   [HLS_NUM][HLS_RET_VECTOR] = '{default: '0};
logic [7 : 0]    					ap_part     [HLS_NUM] = '{default: '0};

//Configure
logic                               cfg_we = 0;
logic [31 : 0]     					cfg_ad = 0;
logic [31 : 0]     					cfg_di = 0;

//XMEM (v2) bus
logic                               risc_rdy;
logic                               risc_re = 0;
logic [3  : 0]                      risc_we = 0;
logic [31 : 0]     					risc_ad = 0;
logic [31 : 0]     					risc_di = 0;
logic [31 : 0]     					risc_do;
logic 								risc_do_vld;

logic 								all_argRdy = 0;

//For dualport bank in scalar range
logic								scalar_argVld	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic								scalar_argAck 	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [XMEM_AW-1:0]	        		scalar_adr		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [SCALAR_BANK_DW-1:0]			scalar_wdat		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [SCALAR_BANK_DW-1:0]			scalar_rdat		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic                       		scalar_rdat_vld	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic                       		scalar_rdat_vld_r[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];

//For single port bank in array range
logic 								array_argRdy	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic 								array_ap_ce		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic 								array_argVld	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic 								array_argAck 	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [XMEM_AW-1:0]	        		array_adr		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [ARRAY_BANK_DW-1:0]			array_wdat		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [ARRAY_BANK_DW-1:0]			array_rdat		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic                       		array_rdat_vld	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];


//For wide port bank in cyclic range
logic 								cyclic_argRdy	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic 								cyclic_ap_ce	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic					    		cyclic_argVld	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic								cyclic_argAck 	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [XMEM_AW-1:0]	        		cyclic_adr		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [CYCLIC_BANK_DW-1:0]			cyclic_wdat		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [CYCLIC_BANK_DW-1:0]			cyclic_rdat		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic                   			cyclic_rdat_vld	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];


logic [31:0] 						debug[16] = '{default: '0};

logic 								dram_init_done	[AXI_PORT_NUM];

//AXI4 for cyclic bank
logic                               axi_awready		[AXI_PORT_NUM];
logic                          		axi_awvalid		[AXI_PORT_NUM];
logic [AXI_ADDR_WIDTH - 1 : 0] 		axi_awaddr		[AXI_PORT_NUM];
logic [AXI_LEN_WIDTH  - 1 : 0] 		axi_awlen		[AXI_PORT_NUM];
logic [AXI_ID_WIDTH   - 1 : 0] 		axi_awid		[AXI_PORT_NUM];
logic [                 2 : 0] 		axi_awsize		[AXI_PORT_NUM];
logic [                 1 : 0] 		axi_awburst		[AXI_PORT_NUM];
logic                          		axi_awlock		[AXI_PORT_NUM];
logic [                 3 : 0] 		axi_awcache		[AXI_PORT_NUM];
logic [                 2 : 0] 		axi_awprot		[AXI_PORT_NUM];
logic [                 3 : 0] 		axi_awqos		[AXI_PORT_NUM];
logic [                 3 : 0] 		axi_awregion	[AXI_PORT_NUM];
logic                          		axi_awuser		[AXI_PORT_NUM];
logic                               axi_wready		[AXI_PORT_NUM];
logic                          		axi_wvalid		[AXI_PORT_NUM];
logic [AXI_DATA_WIDTH - 1 : 0] 		axi_wdata		[AXI_PORT_NUM];
logic [AXI_DATA_WIDTH/8-1 : 0] 		axi_wstrb		[AXI_PORT_NUM];
logic                          		axi_wlast		[AXI_PORT_NUM];
logic [AXI_ID_WIDTH   - 1 : 0] 		axi_wid			[AXI_PORT_NUM];
logic                          		axi_wuser		[AXI_PORT_NUM];
logic                          		axi_bready		[AXI_PORT_NUM];
logic                               axi_bvalid		[AXI_PORT_NUM];
logic [                 1 : 0] 		axi_bresp		[AXI_PORT_NUM];
logic [AXI_ID_WIDTH   - 1 : 0] 		axi_bid			[AXI_PORT_NUM];
logic                               axi_buser		[AXI_PORT_NUM];
logic                               axi_arready		[AXI_PORT_NUM];
logic                          		axi_arvalid		[AXI_PORT_NUM];
logic [AXI_ADDR_WIDTH - 1 : 0] 		axi_araddr		[AXI_PORT_NUM];
logic [AXI_LEN_WIDTH  - 1 : 0] 		axi_arlen		[AXI_PORT_NUM];
logic [AXI_ID_WIDTH   - 1 : 0] 		axi_arid		[AXI_PORT_NUM];
logic [                 2 : 0] 		axi_arsize		[AXI_PORT_NUM];
logic [                 1 : 0] 		axi_arburst		[AXI_PORT_NUM];
logic                          		axi_arlock		[AXI_PORT_NUM];
logic [                 3 : 0] 		axi_arcache		[AXI_PORT_NUM];
logic [                 2 : 0] 		axi_arprot		[AXI_PORT_NUM];
logic [                 3 : 0] 		axi_arqos		[AXI_PORT_NUM];
logic [                 3 : 0] 		axi_arregion	[AXI_PORT_NUM];
logic                          		axi_aruser		[AXI_PORT_NUM];
logic                          		axi_rready		[AXI_PORT_NUM];
logic                          		axi_rvalid		[AXI_PORT_NUM];
logic [AXI_DATA_WIDTH - 1 : 0] 		axi_rdata		[AXI_PORT_NUM];
logic                          		axi_rlast		[AXI_PORT_NUM];
logic [                 1 : 0] 		axi_rresp		[AXI_PORT_NUM];
logic [AXI_ID_WIDTH   - 1 : 0] 		axi_rid			[AXI_PORT_NUM];
logic                          		axi_ruser		[AXI_PORT_NUM] = '{default: '0};

always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        scalar_rdat_vld_r <= '{default:'0};
    end
    else begin
        scalar_rdat_vld_r <= scalar_rdat_vld;
    end
end

//-----------------------------------------------------------------------
//the decalaration of hls function signals
//-----------------------------------------------------------------------
`include "xmem_sig_declare.vh"


//-----------------------------------------------------------------------
//xmem
//-----------------------------------------------------------------------
xcache inst_xmem(
    .clk              	( clk				),
    .rstn             	( rstn				),
    //Configure interface
    .risc_cfg         	( cfg_we			),
    .risc_cfg_adr      	( cfg_ad			),
    .risc_cfg_di       	( cfg_di			),    
    //risc interface
    .risc_we          	( risc_we			),
    .risc_re          	( risc_re			),
    .risc_adr         	( risc_ad			),
    .risc_di          	( risc_di			),
    .risc_do_vld      	( risc_do_vld		),
    .risc_do          	( risc_do			),
    .risc_rdy         	( risc_rdy			),
	//--------------------------

    .scalar_argVld	  	( scalar_argVld		),	//i
    .scalar_argAck 	  	( scalar_argAck		),	//o
    .scalar_adr		  	( scalar_adr		),	//i
    .scalar_wdat	  	( scalar_wdat		),	//i
    .scalar_rdat	  	( scalar_rdat		),	//o
    .scalar_rdat_vld  	( scalar_rdat_vld	),	//o
	//--
	.array_argRdy		( array_argRdy		),	//o
	.array_ap_ce		( array_ap_ce 		),	//i
    .array_argVld	  	( array_argVld		),	//i
    .array_argAck 	  	( array_argAck		),	//o
    .array_adr		  	( array_adr			),	//i
    .array_wdat		  	( array_wdat		),	//i
    .array_rdat		  	( array_rdat		),	//o
    .array_rdat_vld	  	( array_rdat_vld	),	//o
	//--
	.cyclic_argRdy		( cyclic_argRdy		),	//o
	.cyclic_ap_ce		( cyclic_ap_ce 		),	//i
    .cyclic_argVld	  	( cyclic_argVld		),	//i
    .cyclic_argAck 	  	( cyclic_argAck		),	//o
    .cyclic_adr		  	( cyclic_adr		),	//i
    .cyclic_wdat	  	( cyclic_wdat		),	//i
    .cyclic_rdat	  	( cyclic_rdat		),	//o
    .cyclic_rdat_vld  	( cyclic_rdat_vld	), 	//o

	//AXI4 for array bank
	.axi_awready		( axi_awready	[0]	),
	.axi_awvalid		( axi_awvalid	[0]	),
	.axi_awaddr			( axi_awaddr	[0]	),
	.axi_awlen			( axi_awlen		[0]	),
	.axi_awid			( axi_awid		[0]	),
	.axi_awsize			( axi_awsize	[0]	),
	.axi_awburst		( axi_awburst	[0]	),
	.axi_awlock			( axi_awlock	[0]	),
	.axi_awcache		( axi_awcache	[0]	),
	.axi_awprot			( axi_awprot	[0]	),
	.axi_awqos			( axi_awqos		[0]	),
	.axi_awregion		( axi_awregion	[0]	),
	.axi_awuser			( axi_awuser	[0]	),
	.axi_wready			( axi_wready	[0]	),
	.axi_wvalid			( axi_wvalid	[0]	),
	.axi_wdata			( axi_wdata		[0]	),
	.axi_wstrb			( axi_wstrb		[0]	),
	.axi_wlast			( axi_wlast		[0]	),
	.axi_wid			( axi_wid		[0]	),
	.axi_wuser			( axi_wuser		[0]	),
	.axi_bready			( axi_bready	[0]	),
	.axi_bvalid			( axi_bvalid	[0]	),
	.axi_bresp			( axi_bresp		[0]	),
	.axi_bid			( axi_bid		[0]	),
	.axi_buser			( axi_buser		[0]	),
	.axi_arready		( axi_arready	[0]	),
	.axi_arvalid		( axi_arvalid	[0]	),
	.axi_araddr			( axi_araddr	[0]	),
	.axi_arlen			( axi_arlen		[0]	),
	.axi_arid			( axi_arid		[0]	),
	.axi_arsize			( axi_arsize	[0]	),
	.axi_arburst		( axi_arburst	[0]	),
	.axi_arlock			( axi_arlock	[0]	),
	.axi_arcache		( axi_arcache	[0]	),
	.axi_arprot			( axi_arprot	[0]	),
	.axi_arqos			( axi_arqos		[0]	),
	.axi_arregion		( axi_arregion	[0]	),
	.axi_aruser			( axi_aruser	[0]	),
	.axi_rready			( axi_rready	[0]	),
	.axi_rvalid			( axi_rvalid	[0]	),
	.axi_rdata			( axi_rdata		[0]	),
	.axi_rlast			( axi_rlast		[0]	),
	.axi_rresp			( axi_rresp		[0]	),
	.axi_rid			( axi_rid		[0]	),
	.axi_ruser			( axi_ruser		[0]	),
	//AXI4 for cyclic bank
	.axi_awready_1		( axi_awready	[1]	),
	.axi_awvalid_1		( axi_awvalid	[1]	),
	.axi_awaddr_1		( axi_awaddr	[1]	),
	.axi_awlen_1		( axi_awlen		[1]	),
	.axi_awid_1			( axi_awid		[1]	),
	.axi_awsize_1		( axi_awsize	[1]	),
	.axi_awburst_1		( axi_awburst	[1]	),
	.axi_awlock_1		( axi_awlock	[1]	),
	.axi_awcache_1		( axi_awcache	[1]	),
	.axi_awprot_1		( axi_awprot	[1]	),
	.axi_awqos_1		( axi_awqos		[1]	),
	.axi_awregion_1		( axi_awregion	[1]	),
	.axi_awuser_1		( axi_awuser	[1]	),
	.axi_wready_1		( axi_wready	[1]	),
	.axi_wvalid_1		( axi_wvalid	[1]	),
	.axi_wdata_1		( axi_wdata		[1]	),
	.axi_wstrb_1		( axi_wstrb		[1]	),
	.axi_wlast_1		( axi_wlast		[1]	),
	.axi_wid_1			( axi_wid		[1]	),
	.axi_wuser_1		( axi_wuser		[1]	),
	.axi_bready_1		( axi_bready	[1]	),
	.axi_bvalid_1		( axi_bvalid	[1]	),
	.axi_bresp_1		( axi_bresp		[1]	),
	.axi_bid_1			( axi_bid		[1]	),
	.axi_buser_1		( axi_buser		[1]	),
	.axi_arready_1		( axi_arready	[1]	),
	.axi_arvalid_1		( axi_arvalid	[1]	),
	.axi_araddr_1		( axi_araddr	[1]	),
	.axi_arlen_1		( axi_arlen		[1]	),
	.axi_arid_1			( axi_arid		[1]	),
	.axi_arsize_1		( axi_arsize	[1]	),
	.axi_arburst_1		( axi_arburst	[1]	),
	.axi_arlock_1		( axi_arlock	[1]	),
	.axi_arcache_1		( axi_arcache	[1]	),
	.axi_arprot_1		( axi_arprot	[1]	),
	.axi_arqos_1		( axi_arqos		[1]	),
	.axi_arregion_1		( axi_arregion	[1]	),
	.axi_aruser_1		( axi_aruser	[1]	),
	.axi_rready_1		( axi_rready	[1]	),
	.axi_rvalid_1		( axi_rvalid	[1]	),
	.axi_rdata_1		( axi_rdata		[1]	),
	.axi_rlast_1		( axi_rlast		[1]	),
	.axi_rresp_1		( axi_rresp		[1]	),
	.axi_rid_1			( axi_rid		[1]	),
	.axi_ruser_1		( axi_ruser		[1]	)
);



//----------------------------------------------------------------------------------
// AXI4 Memory model
//----------------------------------------------------------------------------------
dram_axi_sim_model_v2 #(
    .ID_WIDTH         ( AXI_ID_WIDTH      	),
    .DRAM_DATA_WIDTH  ( AXI_DATA_WIDTH    	)
)
inst_array_dram_model (
    .clk              ( clk              	),
    .rstn             ( rstn             	),
    .dram_init_done   ( dram_init_done	[0] ),
    .ddr_awvalid      ( axi_awvalid   	[0] ),
    .ddr_awaddr       ( axi_awaddr      [0] ),
    .ddr_awlen        ( axi_awlen       [0] ),
    .ddr_awsize       ( axi_awsize      [0] ),
    .ddr_awid         ( axi_awid        [0] ),
    .ddr_awready      ( axi_awready     [0] ),
    .ddr_wdata        ( axi_wdata       [0] ),
    .ddr_wstrb        ( axi_wstrb       [0] ),
    .ddr_wvalid       ( axi_wvalid      [0] ),
    .ddr_wready       ( axi_wready      [0] ),
    .ddr_bready       ( axi_bready      [0] ),
    .ddr_bid          ( axi_bid         [0] ),
    .ddr_bresp        ( axi_bresp       [0] ),
    .ddr_bvalid       ( axi_bvalid      [0] ),
    .ddr_arvalid      ( axi_arvalid     [0] ),
    .ddr_araddr       ( axi_araddr      [0] ),
    .ddr_arlen        ( axi_arlen       [0] ),
    .ddr_arsize       ( axi_arsize      [0] ),
    .ddr_arid         ( axi_arid        [0] ),
    .ddr_arready      ( axi_arready     [0] ),
    .ddr_rready       ( axi_rready      [0] ),
    .ddr_rdata        ( axi_rdata       [0] ),
    .ddr_rvalid       ( axi_rvalid      [0] ),
    .ddr_rlast        ( axi_rlast       [0] ),
    .ddr_rid          ( axi_rid         [0] ),
    .ddr_resp         ( axi_rresp       [0] )
);

//----------------------------------------------------------------------------------
// AXI4 Memory model
//----------------------------------------------------------------------------------
dram_axi_sim_model_v2 #(
    .ID_WIDTH         ( AXI_ID_WIDTH      ),
    .DRAM_DATA_WIDTH  ( AXI_DATA_WIDTH    )
)
inst_cyclic_dram_model (
    .clk              ( clk                	),
    .rstn             ( rstn               	),
    .dram_init_done   ( dram_init_done  [1]	),
    .ddr_awvalid      ( axi_awvalid     [1]	),
    .ddr_awaddr       ( axi_awaddr      [1]	),
    .ddr_awlen        ( axi_awlen       [1]	),
    .ddr_awsize       ( axi_awsize      [1]	),
    .ddr_awid         ( axi_awid        [1]	),
    .ddr_awready      ( axi_awready     [1]	),
    .ddr_wdata        ( axi_wdata       [1]	),
    .ddr_wstrb        ( axi_wstrb       [1]	),
    .ddr_wvalid       ( axi_wvalid      [1]	),
    .ddr_wready       ( axi_wready      [1]	),
    .ddr_bready       ( axi_bready      [1]	),
    .ddr_bid          ( axi_bid         [1]	),
    .ddr_bresp        ( axi_bresp       [1]	),
    .ddr_bvalid       ( axi_bvalid      [1]	),
    .ddr_arvalid      ( axi_arvalid     [1]	),
    .ddr_araddr       ( axi_araddr      [1]	),
    .ddr_arlen        ( axi_arlen       [1]	),
    .ddr_arsize       ( axi_arsize      [1]	),
    .ddr_arid         ( axi_arid        [1]	),
    .ddr_arready      ( axi_arready     [1]	),
    .ddr_rready       ( axi_rready      [1]	),
    .ddr_rdata        ( axi_rdata       [1]	),
    .ddr_rvalid       ( axi_rvalid      [1]	),
    .ddr_rlast        ( axi_rlast       [1]	),
    .ddr_rid          ( axi_rid         [1]	),
    .ddr_resp         ( axi_rresp       [1]	)
);

//-----------------------------------------------------------------------
//custom_connection
//-----------------------------------------------------------------------
`include "custom_connection_instantiate.vh"


//-----------------------------------------------------------------------
//xmem_init_task used for configurating xmem module
//-----------------------------------------------------------------------
`include "xmem_param_init_task.vh"

//-----------------------------------------------------------------------
//xnet driver to drive custom_connection
//-----------------------------------------------------------------------
`include "xnet_drv.vh"


//-----------------------------------------------------------------------
//main
//-----------------------------------------------------------------------
always #5 clk =~ clk;


initial begin
	clk = 5;
	rstn = 0;
#100;
	rstn = 1;
#100;
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);
    @ (posedge clk);

	xmem_param_init();

	xmem_init_param_done = 1;

end


endmodule