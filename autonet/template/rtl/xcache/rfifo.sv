

module rfifo #(
	parameter FIFO_DWIDTH		= 32, 
	parameter FIFO_DEPTH		= 16
)(
	// common signals:
	input 										rstn,
	input 										clk,
	output logic								full,
	input 					   					we,
	input [FIFO_DWIDTH-1:0]						din,
	input 										re,
	output logic 								empty,
	output logic [FIFO_DWIDTH-1:0]				dout
);

//--------------------------------------------------------------------------------
//internal signals
//--------------------------------------------------------------------------------

//--------------------------------------------------------------------------------
//logic
//--------------------------------------------------------------------------------

//-------------------------------------------------
//FIFO
//-------------------------------------------------
rfifo_fifo_mem # (
	.DWIDTH	( FIFO_DWIDTH	),
	.DEPTH 	( FIFO_DEPTH	)
)
inst_rfifo_fifo_mem(
	.clk	( clk		),
	.rstn	( rstn		),
	.we		( we		),
	.din	( din		),
	.re		( re		),
	.dout	( dout		),
	.full	( full		),
	.empty	( empty		),
	.bCnt	(			)
);



endmodule



module rfifo_fifo_mem # (
	
	parameter DWIDTH = 32,
	parameter DEPTH  = 1024,
	parameter AFULL_THR = 3,	//the threshold of almost full
	parameter AEMPTY_THR = 3,	//the threshold of almost empty
	parameter AWIDTH = $clog2(DEPTH)
)
(
	input 						clk, 
	input 						rstn, 
	input 						we, 
	input [DWIDTH-1:0]			din, 
	input 						re,
	output logic [DWIDTH-1:0]	dout,
	output logic 				full, 
	output logic 				empty,
	output logic [AWIDTH:0]		bCnt	
);

reg [AWIDTH-1:0]	wptr, rptr;

always @ (posedge clk or negedge rstn) begin 
	if (~rstn) begin 
		wptr	<= 0;
		rptr	<= 0;
		bCnt	<= 0;
	end 
	else begin 
		if (we) begin 
			wptr <= wptr + 1;
		end 
		if (re) begin 
			rptr <= rptr + 1;
		end 
		bCnt <= bCnt + we - re;
	end 
end 


rfifo_dpram #( 
    .usr_ram_style  ( "block"       ),
    .aw             ( $clog2(DEPTH) ), 
    .dw             ( DWIDTH        ), 
    .max_size       ( DEPTH         )
)
inst_rfifo_dpram(	
    .rd_clk    ( clk       ),
	.raddr     ( rptr      ),
	.dout      ( dout      ),
	.wr_clk    ( clk       ),
	.we        ( we        ),
	.din       ( din       ),
	.waddr     ( wptr      )	
);


assign full 	= (bCnt == DEPTH);
assign empty	= (bCnt == 0);


endmodule




module rfifo_dpram #( parameter usr_ram_style = "distributed", aw=16, dw=8, max_size=256)
(	
	input rd_clk,
	input [aw-1:0] raddr,
	output reg [dw-1:0] dout,
	input wr_clk,
	input we,
	input [dw-1:0] din,
	input [aw-1:0] waddr	
);

// Infer Dual Port Block RAM with Dual clocks
// ram_style: auto | block | distributed 
//(* ram_style = usr_ram_style *)	reg [dw-1:0] RAM [max_size-1:0];
reg [dw-1:0] RAM [max_size-1:0];
	/*
	always @(posedge rd_clk)
	begin
	   dout <= RAM[raddr];
	end
	*/


    assign dout = RAM[raddr];

	
	always @(posedge wr_clk)
	begin
		if (we) RAM[waddr]<=din;
	end

endmodule	