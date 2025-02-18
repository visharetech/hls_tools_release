
module cyclic_mruCache_bank import xcache_param_pkg::*;  #(
	//Cache
	parameter int AXI_LEN_W = 8,
	parameter int DW 				= 32,
	parameter int AW 				= 32,
    parameter int USER_DW 			= 128,
    parameter int USER_MAX_LEN 		= USER_DW / DW,
	parameter int CACHE_BYTE 		= 1*1024,
	parameter int CACHE_WAY  		= 2,
	parameter int CACHE_WORD_BYTE	= DW / 8,
	parameter int CACHE_LINE_LEN	= 8,
	parameter int MEM_BYTE 			= (1 << AW),
	//AXI4 
    parameter int AXI_ADDR_WIDTH   = 32,
    parameter int AXI_DATA_WIDTH   = 256,
    parameter int AXI_LEN_WIDTH    = 8,
    parameter int AXI_ID_WIDTH     = 8
)
(
	input                   			 	clk,
	input 								  	rstn,
	//--------------------------------------------	
	//connected to cyclic reqMux
	output logic 						  	cyclic_mux_ready 		[BANK_NUM[MEM_TYPE_CYCLIC]],
	input 								  	cyclic_mux_re 			[BANK_NUM[MEM_TYPE_CYCLIC]],
	input 								  	cyclic_mux_we 			[BANK_NUM[MEM_TYPE_CYCLIC]],
	input 		 [1:0]					  	cyclic_mux_len			[BANK_NUM[MEM_TYPE_CYCLIC]],
	input 		 [CYCLIC_BANK_BYTE_AW-1:0]	cyclic_mux_bankAdr		[BANK_NUM[MEM_TYPE_CYCLIC]],		//unit: byte
	input 		 [CYCLIC_BANK_DW-1:0]	  	cyclic_mux_din			[BANK_NUM[MEM_TYPE_CYCLIC]],
	output logic [CYCLIC_BANK_DW-1:0]	  	cyclic_mux_dout			[BANK_NUM[MEM_TYPE_CYCLIC]],
    output logic 						  	cyclic_mux_dout_vld		[BANK_NUM[MEM_TYPE_CYCLIC]],
    //AXI4
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
    input                                 	axi_ruser
	
);


//-------------------------------------------------------------
//parameter 
//-------------------------------------------------------------
localparam ARB_AW = AW + $clog2(BANK_NUM[MEM_TYPE_CYCLIC]);


//-------------------------------------------------------------
//Signals 
//-------------------------------------------------------------
logic								en; 

logic 								cyclic_mux_csr_flush[BANK_NUM[MEM_TYPE_CYCLIC]];

//----------------------- mruCache signals -------------------------//
// read address channel
logic								mc_axi4_ar_ready	[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [AW-1:0]						mc_axi4_ar_addr		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic								mc_axi4_ar_valid	[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [AXI_LEN_W-1:0]				mc_axi4_ar_len		[BANK_NUM[MEM_TYPE_CYCLIC]];
// read data channel
logic								mc_axi4_r_last		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic								mc_axi4_r_valid		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [DW-1:0]						mc_axi4_r_data		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic								mc_axi4_r_ready		[BANK_NUM[MEM_TYPE_CYCLIC]];
// write address channel
logic								mc_axi4_aw_ready	[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [AW-1:0]						mc_axi4_aw_addr		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic								mc_axi4_aw_valid	[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [AXI_LEN_W-1:0]				mc_axi4_aw_len		[BANK_NUM[MEM_TYPE_CYCLIC]];
// write data channel
logic								mc_axi4_w_ready		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [DW-1:0]						mc_axi4_w_data		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [DW/8-1:0]					mc_axi4_w_strb		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic								mc_axi4_w_valid		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic								mc_axi4_w_last		[BANK_NUM[MEM_TYPE_CYCLIC]];
// write response channel
logic								mc_axi4_b_valid		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic								mc_axi4_b_resp		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic								mc_axi4_b_ready		[BANK_NUM[MEM_TYPE_CYCLIC]];

//-----------------------arbiter signals -------------------------//
logic                           	c_axi_awready       [BANK_NUM[MEM_TYPE_CYCLIC]];
logic                           	c_axi_awvalid       [BANK_NUM[MEM_TYPE_CYCLIC]];
logic [ARB_AW-1:0]          		c_axi_awaddr        [BANK_NUM[MEM_TYPE_CYCLIC]];
logic [7:0]                     	c_axi_awlen         [BANK_NUM[MEM_TYPE_CYCLIC]];
logic                           	c_axi_wready        [BANK_NUM[MEM_TYPE_CYCLIC]];
logic                           	c_axi_wvalid        [BANK_NUM[MEM_TYPE_CYCLIC]];
logic [DW-1:0]          			c_axi_wdata         [BANK_NUM[MEM_TYPE_CYCLIC]];
logic                           	c_axi_arready       [BANK_NUM[MEM_TYPE_CYCLIC]];
logic                           	c_axi_arvalid       [BANK_NUM[MEM_TYPE_CYCLIC]];
logic [ARB_AW-1:0]          		c_axi_araddr        [BANK_NUM[MEM_TYPE_CYCLIC]];
logic [7:0]                     	c_axi_arlen         [BANK_NUM[MEM_TYPE_CYCLIC]];
logic                           	c_axi_rvalid        [BANK_NUM[MEM_TYPE_CYCLIC]];
logic                           	c_axi_rready        [BANK_NUM[MEM_TYPE_CYCLIC]];
logic [DW-1:0]          			c_axi_rdata         [BANK_NUM[MEM_TYPE_CYCLIC]];

//-------------------------------------------------------------
//Logic
//-------------------------------------------------------------

generate 
	for (genvar s=0; s<BANK_NUM[MEM_TYPE_CYCLIC]; s++) begin: CYCLIC_CACHE_BANK
	
		always_comb begin 
			cyclic_mux_csr_flush	[s] = 0;
		end 
	
		cyclicCache #(
			.AXI_LEN_W          ( AXI_LEN_W			),
			.DW                 ( DW				),
			.AW                 ( AW				),
			.USER_DW 			( USER_DW			),
			.USER_MAX_LEN 		( USER_MAX_LEN 		),
			.CACHE_BYTE         ( CACHE_BYTE		),
			.CACHE_WAY          ( CACHE_WAY			),
			.CACHE_WORD_BYTE    ( CACHE_WORD_BYTE	),
			.CACHE_LINE_LEN     ( CACHE_LINE_LEN	)
		) 
		inst_cyclic_cache (
			.clk            ( clk						),
			.rstn           ( rstn						),
			//--
			.ready          ( cyclic_mux_ready		[s]	),	//o
			.user_re        ( cyclic_mux_re			[s]	),	//i
			.user_we        ( cyclic_mux_we			[s]	),	//i
			.user_len 		( cyclic_mux_len		[s]	),	//i
			.user_adr       ( cyclic_mux_bankAdr	[s]	),	//i		The unit of user_adr: byte	//testing
			.user_wdat      ( cyclic_mux_din		[s]	),	//i
			.csr_flush      ( cyclic_mux_csr_flush	[s]	),	//i
			.user_rdat      ( cyclic_mux_dout		[s]	),	//o
			.user_rdat_vld  ( cyclic_mux_dout_vld	[s]	),	//o
			// read address channel
			.axi4_ar_ready  ( mc_axi4_ar_ready		[s]	),	//i
			.axi4_ar_addr   ( mc_axi4_ar_addr		[s]	),	//o
			.axi4_ar_valid  ( mc_axi4_ar_valid		[s]	),	//o
			.axi4_ar_len    ( mc_axi4_ar_len		[s]	),	//o
			// read data channel	
			.axi4_r_last    ( mc_axi4_r_last		[s]	),	//i
			.axi4_r_valid   ( mc_axi4_r_valid		[s]	),	//i
			.axi4_r_data    ( mc_axi4_r_data		[s]	),	//i
			.axi4_r_ready   ( mc_axi4_r_ready		[s]	),	//o
			// write address channel	
			.axi4_aw_ready  ( mc_axi4_aw_ready		[s]	),	//i
			.axi4_aw_addr   ( mc_axi4_aw_addr		[s]	),	//o
			.axi4_aw_valid  ( mc_axi4_aw_valid		[s]	),	//o
			.axi4_aw_len    ( mc_axi4_aw_len		[s]	),	//o
			// write data channel	
			.axi4_w_ready   ( mc_axi4_w_ready		[s]	),	//i
			.axi4_w_data    ( mc_axi4_w_data		[s]	),	//o
			.axi4_w_strb    ( mc_axi4_w_strb		[s]	),	//o
			.axi4_w_valid   ( mc_axi4_w_valid		[s]	),	//o
			.axi4_w_last    ( mc_axi4_w_last		[s]	),	//o
			// write response channel	
			.axi4_b_valid   ( mc_axi4_b_valid		[s]	),	//i
			.axi4_b_resp    ( mc_axi4_b_resp		[s]	),	//i
			.axi4_b_ready   ( mc_axi4_b_ready		[s]	)	//o
		);
		
		assign mc_axi4_ar_ready [s] = c_axi_arready     [s];
		assign c_axi_araddr     [s] = mc_axi4_ar_addr   [s] + MEM_BYTE*s;
		assign c_axi_arvalid    [s] = mc_axi4_ar_valid	[s];
		assign c_axi_arlen      [s] = mc_axi4_ar_len	[s];
		assign mc_axi4_r_last	[s] = 0;
		assign mc_axi4_r_valid	[s] = c_axi_rvalid      [s];
		assign mc_axi4_r_data	[s] = c_axi_rdata       [s];
		assign c_axi_rready     [s] = mc_axi4_r_ready   [s];
		assign mc_axi4_aw_ready [s] = c_axi_awready     [s];
		assign c_axi_awaddr     [s] = mc_axi4_aw_addr	[s] + MEM_BYTE*s;
		assign c_axi_awvalid    [s] = mc_axi4_aw_valid  [s];
		assign c_axi_awlen      [s] = mc_axi4_aw_len	[s];
		assign mc_axi4_w_ready	[s] = c_axi_wready      [s];
		assign c_axi_wdata      [s] = mc_axi4_w_data	[s];
		assign c_axi_wvalid     [s] = mc_axi4_w_valid	[s];
		assign mc_axi4_b_valid  [s] = 1;
		assign mc_axi4_b_resp   [s] = 0;
		
	end 
endgenerate 	

	
cache_axi4_arbiter_v1 #(
	.CACHE_NUM      ( BANK_NUM[MEM_TYPE_CYCLIC]	),
	.ADDR_BITS      ( ARB_AW 					),
	.WORD_PER_LINE  ( CACHE_LINE_LEN   			),
	.BYTE_PER_WORD  ( CACHE_WORD_BYTE   		),
	.AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH  			),
	.AXI_DATA_WIDTH ( AXI_DATA_WIDTH  			),
	.AXI_LEN_WIDTH  ( AXI_LEN_WIDTH   			),
	.AXI_ID_WIDTH   ( AXI_ID_WIDTH    			)
)
inst_axi4_arbiter(
	.clk        ( clk           ),
	.rstn       ( rstn          ),
	.en         ( en            ),
	//AXI4 from cache
	.c_awready  ( c_axi_awready ),
	.c_awvalid  ( c_axi_awvalid ),
	.c_awaddr   ( c_axi_awaddr  ),
	.c_wready   ( c_axi_wready  ),
	.c_wvalid   ( c_axi_wvalid  ),
	.c_wdata    ( c_axi_wdata   ),
	.c_arready  ( c_axi_arready ),
	.c_arvalid  ( c_axi_arvalid ),
	.c_arlen    ( c_axi_arlen   ),
	.c_araddr   ( c_axi_araddr  ),
	.c_rvalid   ( c_axi_rvalid  ),
	.c_rready   ( c_axi_rready  ),
	.c_rdata    ( c_axi_rdata   ),
	//AXI4 to main memory
	.m_awready  ( axi_awready 	),
	.m_awvalid  ( axi_awvalid 	),
	.m_awaddr   ( axi_awaddr  	),
	.m_awlen    ( axi_awlen   	),
	.m_awid     ( axi_awid    	),
	.m_wready   ( axi_wready  	),
	.m_wvalid   ( axi_wvalid  	),
	.m_wlast    ( axi_wlast   	),
	.m_wdata    ( axi_wdata   	),
	.m_arready  ( axi_arready   ),
	.m_arvalid  ( axi_arvalid   ),
	.m_araddr   ( axi_araddr    ),
	.m_arlen    ( axi_arlen     ),
	.m_arid     ( axi_arid      ),
	.m_rvalid   ( axi_rvalid    ),
	.m_rready   ( axi_rready    ),
	.m_rdata    ( axi_rdata     )
);


//Constant output
assign axi_awsize    = 5;
assign axi_awburst   = 1;
assign axi_awlock    = 0;
assign axi_awcache   = 0;
assign axi_awprot    = 0;
assign axi_awqos     = 0;
assign axi_awregion  = 0;
assign axi_awuser    = 0;
assign axi_wstrb     = 32'hffffffff;
assign axi_wid       = 0;
assign axi_wuser     = 0;
assign axi_bready    = 1;
assign axi_arsize    = 5;
assign axi_arburst   = 1;
assign axi_arlock    = 0;
assign axi_arcache   = 0;
assign axi_arprot    = 0;
assign axi_arqos     = 0;
assign axi_arregion  = 0;
assign axi_aruser    = 0;


assign en 			 = 1'b1;	//ask Edward 






//-------------------------------------------------------------
//Function: 
//-------------------------------------------------------------

function [3:0] getWriteMask;
	input we;
	input [1:0] byteAdr;
	input [1:0] len;
	if(we==0) 			getWriteMask=0;
	else begin
		if(len==3) 		getWriteMask= 4'b1111;
		else if(len==1) getWriteMask= byteAdr[1] ? 4'b1100 : 4'b0011;
		else 			getWriteMask= 1<<byteAdr[1:0];
	end
endfunction



//-------------------------------------------------------------
//so debug 
//-------------------------------------------------------------
logic [31:0] debug_grp1_0;
logic [31:0] debug_grp1_1;
logic [31:0] debug_grp1_2;
logic [31:0] debug_grp1_3;
logic [31:0] debug_grp1_4;
logic [31:0] debug_grp1_5;
logic [31:0] debug_grp1_6;
logic [31:0] debug_grp1_7;


assign debug_grp1_0 = CYCLIC_BANK_BYTE_AW;
assign debug_grp1_1 = AW;


endmodule


