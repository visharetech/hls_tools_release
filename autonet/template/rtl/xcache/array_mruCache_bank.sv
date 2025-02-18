
module array_mruCache_bank import xcache_param_pkg::*;  #(
	//Cache
	parameter int AXI_LEN_W = 8,
	parameter int DW 				= 32,
	parameter int AW 				= 32,
	parameter int ROLLBACK 			= 1,
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
	input                   			  clk,
	input 								  rstn,
	//--------------------------------------------	
	//connected to array_mux_ready
	output logic 						  array_mux_ready 		[BANK_NUM[MEM_TYPE_ARRAY]],
	input 								  array_mux_re 			[BANK_NUM[MEM_TYPE_ARRAY]],
	input 								  array_mux_we 			[BANK_NUM[MEM_TYPE_ARRAY]],
	input 		 [1:0]					  array_mux_len			[BANK_NUM[MEM_TYPE_ARRAY]],
	input 		 [ARRAY_BANK_BYTE_AW-1:0] array_mux_bankAdr		[BANK_NUM[MEM_TYPE_ARRAY]],		//unit: byte
	input 		 [ARRAY_BANK_DW-1:0]	  array_mux_din			[BANK_NUM[MEM_TYPE_ARRAY]],
	output logic [ARRAY_BANK_DW-1:0]	  array_mux_dout		[BANK_NUM[MEM_TYPE_ARRAY]],
    output logic 						  array_mux_dout_vld	[BANK_NUM[MEM_TYPE_ARRAY]],
    //AXI4
    input                                 axi_awready,
    output logic                          axi_awvalid,
    output logic [AXI_ADDR_WIDTH - 1 : 0] axi_awaddr,
    output logic [AXI_LEN_WIDTH  - 1 : 0] axi_awlen,
    output logic [AXI_ID_WIDTH   - 1 : 0] axi_awid,
    output logic [                 2 : 0] axi_awsize,
    output logic [                 1 : 0] axi_awburst,
    output logic                          axi_awlock,
    output logic [                 3 : 0] axi_awcache,
    output logic [                 2 : 0] axi_awprot,
    output logic [                 3 : 0] axi_awqos,
    output logic [                 3 : 0] axi_awregion,
    output logic                          axi_awuser,
    input                                 axi_wready,
    output logic                          axi_wvalid,
    output logic [AXI_DATA_WIDTH - 1 : 0] axi_wdata,
    output logic [AXI_DATA_WIDTH/8-1 : 0] axi_wstrb,
    output logic                          axi_wlast,
    output logic [AXI_ID_WIDTH   - 1 : 0] axi_wid,
    output logic                          axi_wuser,
    output logic                          axi_bready,
    input                                 axi_bvalid,
    input        [                 1 : 0] axi_bresp,
    input        [AXI_ID_WIDTH   - 1 : 0] axi_bid,
    input                                 axi_buser,
    input                                 axi_arready,
    output logic                          axi_arvalid,
    output logic [AXI_ADDR_WIDTH - 1 : 0] axi_araddr,
    output logic [AXI_LEN_WIDTH  - 1 : 0] axi_arlen,
    output logic [AXI_ID_WIDTH   - 1 : 0] axi_arid,
    output logic [                 2 : 0] axi_arsize,
    output logic [                 1 : 0] axi_arburst,
    output logic                          axi_arlock,
    output logic [                 3 : 0] axi_arcache,
    output logic [                 2 : 0] axi_arprot,
    output logic [                 3 : 0] axi_arqos,
    output logic [                 3 : 0] axi_arregion,
    output logic                          axi_aruser,
    output logic                          axi_rready,
    input                                 axi_rvalid,
    input        [AXI_DATA_WIDTH - 1 : 0] axi_rdata,
    input                                 axi_rlast,
    input        [                 1 : 0] axi_rresp,
    input        [AXI_ID_WIDTH   - 1 : 0] axi_rid,
    input                                 axi_ruser
	
);


//-------------------------------------------------------------
//parameter 
//-------------------------------------------------------------
localparam ARB_AW = AW + $clog2(BANK_NUM[MEM_TYPE_ARRAY]);


//-------------------------------------------------------------
//Signals 
//-------------------------------------------------------------
logic								en; 

logic [CACHE_WORD_BYTE-1:0]   		array_mux_we_mask	[BANK_NUM[MEM_TYPE_ARRAY]];
logic 								array_mux_csr_flush	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [ARRAY_BANK_DW-1:0]	  		array_mux_din_shift	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [ARRAY_BANK_DW-1:0]	  		array_mux_dout_w	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [1:0]                         adr_buf             [BANK_NUM[MEM_TYPE_ARRAY]][4];
logic [1:0]                         buf_head            [BANK_NUM[MEM_TYPE_ARRAY]];
logic [1:0]                         buf_tail            [BANK_NUM[MEM_TYPE_ARRAY]];

//----------------------- mruCache signals -------------------------//
// read address channel
logic								mc_axi4_ar_ready	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [AW-1:0]						mc_axi4_ar_addr		[BANK_NUM[MEM_TYPE_ARRAY]];
logic								mc_axi4_ar_valid	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [AXI_LEN_W-1:0]				mc_axi4_ar_len		[BANK_NUM[MEM_TYPE_ARRAY]];
// read data channel
logic								mc_axi4_r_last		[BANK_NUM[MEM_TYPE_ARRAY]];
logic								mc_axi4_r_valid		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [DW-1:0]						mc_axi4_r_data		[BANK_NUM[MEM_TYPE_ARRAY]];
logic								mc_axi4_r_ready		[BANK_NUM[MEM_TYPE_ARRAY]];
// write address channel
logic								mc_axi4_aw_ready	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [AW-1:0]						mc_axi4_aw_addr		[BANK_NUM[MEM_TYPE_ARRAY]];
logic								mc_axi4_aw_valid	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [AXI_LEN_W-1:0]				mc_axi4_aw_len		[BANK_NUM[MEM_TYPE_ARRAY]];
// write data channel
logic								mc_axi4_w_ready		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [DW-1:0]						mc_axi4_w_data		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [DW/8-1:0]					mc_axi4_w_strb		[BANK_NUM[MEM_TYPE_ARRAY]];
logic								mc_axi4_w_valid		[BANK_NUM[MEM_TYPE_ARRAY]];
logic								mc_axi4_w_last		[BANK_NUM[MEM_TYPE_ARRAY]];
// write response channel
logic								mc_axi4_b_valid		[BANK_NUM[MEM_TYPE_ARRAY]];
logic								mc_axi4_b_resp		[BANK_NUM[MEM_TYPE_ARRAY]];
logic								mc_axi4_b_ready		[BANK_NUM[MEM_TYPE_ARRAY]];

//-----------------------arbiter signals -------------------------//
logic                           	c_axi_awready       [BANK_NUM[MEM_TYPE_ARRAY]];
logic                           	c_axi_awvalid       [BANK_NUM[MEM_TYPE_ARRAY]];
logic [ARB_AW-1:0]          		c_axi_awaddr        [BANK_NUM[MEM_TYPE_ARRAY]];
logic [7:0]                     	c_axi_awlen         [BANK_NUM[MEM_TYPE_ARRAY]];
logic                           	c_axi_wready        [BANK_NUM[MEM_TYPE_ARRAY]];
logic                           	c_axi_wvalid        [BANK_NUM[MEM_TYPE_ARRAY]];
logic [DW-1:0]          			c_axi_wdata         [BANK_NUM[MEM_TYPE_ARRAY]];
logic                           	c_axi_arready       [BANK_NUM[MEM_TYPE_ARRAY]];
logic                           	c_axi_arvalid       [BANK_NUM[MEM_TYPE_ARRAY]];
logic [ARB_AW-1:0]          		c_axi_araddr        [BANK_NUM[MEM_TYPE_ARRAY]];
logic [7:0]                     	c_axi_arlen         [BANK_NUM[MEM_TYPE_ARRAY]];
logic                           	c_axi_rvalid        [BANK_NUM[MEM_TYPE_ARRAY]];
logic                           	c_axi_rready        [BANK_NUM[MEM_TYPE_ARRAY]];
logic [DW-1:0]          			c_axi_rdata         [BANK_NUM[MEM_TYPE_ARRAY]];

//-------------------------------------------------------------
//Logic
//-------------------------------------------------------------

generate 
	for (genvar s=0; s<BANK_NUM[MEM_TYPE_ARRAY]; s++) begin: MRU_CACHE_BANK
	
		always_comb begin 
			array_mux_we_mask	[s] = getWriteMask(array_mux_we[s], array_mux_bankAdr[s], array_mux_len[s]);
			array_mux_csr_flush	[s] = 0;
            
            array_mux_din_shift [s] = shiftData_wr(array_mux_len[s], array_mux_bankAdr[s], array_mux_din[s]);
            array_mux_dout      [s] = shiftData_rd(adr_buf[s][buf_head[s]], array_mux_dout_w[s]);
		end 
        
        always @ (posedge clk or negedge rstn) begin
            if (~rstn) begin
                adr_buf  [s] <= '{default:'0};
                buf_head [s] <= 0;
                buf_tail [s] <= 0;
            end
            else begin
                if (array_mux_re[s] && array_mux_ready[s]) begin
                    adr_buf[s][buf_tail[s]] <= array_mux_bankAdr[s];
                    buf_tail[s] <= buf_tail[s] + 1;
                end
                if (array_mux_dout_vld[s]) begin
                    buf_head[s] <= buf_head[s] + 1;
                end
            end
        end
	
		mruCache #(
			.AXI_LEN_W          ( AXI_LEN_W			),
			.DW                 ( DW				),
			.AW                 ( AW				),
			.CACHE_BYTE         ( CACHE_BYTE		),
			.CACHE_WAY          ( CACHE_WAY			),
			.CACHE_WORD_BYTE    ( CACHE_WORD_BYTE	),
			.CACHE_LINE_LEN     ( CACHE_LINE_LEN	),
			.ROLLBACK           ( ROLLBACK			)
		) 
		inst_mruCache (
			.clk            ( clk								),
			.rstn           ( rstn								),
			//--
			.ready          ( array_mux_ready			[s]		),	//o
			.user_re        ( array_mux_re				[s]		),	//i
			.user_we        ( array_mux_we				[s]		),	//i
			.user_we_mask   ( array_mux_we_mask			[s]		),	//i
			.user_adr       ( array_mux_bankAdr			[s]		),	//i		The unit of user_adr: byte	//testing
			.user_wdat      ( array_mux_din_shift		[s]		),	//i
			.csr_flush      ( array_mux_csr_flush		[s]		),	//i
			.user_rdat      ( array_mux_dout_w			[s]		),	//o
			.user_rdat_vld  ( array_mux_dout_vld		[s]		),	//o
			.rollback       ( 									),	//o
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
	.CACHE_NUM      ( BANK_NUM[MEM_TYPE_ARRAY]	),
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

function [31:0] shiftData_wr;
	input [1:0] len;
	input [1:0] adr;
	input [31:0] word;
    /*case (adr[1:0])
        2'd1: shiftData_wr = {word[23:0],  word[7:0]};
        2'd2: shiftData_wr = {word[15:0], word[31:16]};
        2'd3: shiftData_wr = {word[7:0], word[23:0]};
        default: shiftData_wr = word;
    endcase*/
    case (adr[1:0])
        2'd1: shiftData_wr = {word[23:0],  8'b0};
        2'd2: shiftData_wr = {word[15:0], 16'b0};
        2'd3: shiftData_wr = {word[7:0], 24'b0};
        default: shiftData_wr = word;
    endcase
endfunction

function [31:0] shiftData_rd;
	input [1:0] adr;
	input [31:0] word;
	//shiftData_rd = word >> (adr[1:0]*8);
    case (adr[1:0])
        2'd1: shiftData_rd = {8'b0, word[31:8]};
        2'd2: shiftData_rd = {16'b0, word[31:16]};
        2'd3: shiftData_rd = {24'b0, word[31:24]};
        default: shiftData_rd = word;
    endcase
endfunction


//-------------------------------------------------------------
//so debug 
//-------------------------------------------------------------
logic test1[BANK_NUM[MEM_TYPE_ARRAY]];

always_comb begin 
	test1 = '{default: '0}; 

	for (int s=0; s<BANK_NUM[MEM_TYPE_ARRAY]; s++) begin 
		if (array_mux_din[s] == 32'h0000_6800) begin 
			test1[s] = 1; 
		end 
	end 

end 











endmodule


