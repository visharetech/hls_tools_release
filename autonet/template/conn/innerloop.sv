//Last updated from So: 20231025
// innerloop
module innerloop # (
	parameter LEN_DWIDTH = 32,
	parameter INC_DWIDTH = 16, 	//INC_DWIDTH can be increased.
    parameter ENABLE_PIPELINE = 1,
	//constant paramters
	localparam CMD_LOOP_INIT_BITS  = LEN_DWIDTH, 
	localparam CMD_LOOP_LEN_BITS   = LEN_DWIDTH,
	localparam CMD_LOOP_INC_BITS   = INC_DWIDTH + 3
)
(
	//common interface
	input 							clk,
	input 							rstn,
	//cmd interface from the external wrapper ports
	input 							cmd_start,
	input [CMD_LOOP_INIT_BITS-1:0]	cmd_loop_init_i,
	input [CMD_LOOP_LEN_BITS-1:0]	cmd_loop_len_i,
	input [CMD_LOOP_INC_BITS-1:0]	cmd_loop_inc_i,
	output logic 					cmd_loop_idle_o,
	output logic 					cmd_loop_done_o,
	//ap interface connected to the external hls function
	output logic					ap_start,
	input   						ap_done,
	input  	 						ap_idle,
	input   						ap_ready,
	input 							ap_return,
	output logic [LEN_DWIDTH-1:0]	ap_idx
);

//-------------------------------------------
//parameters
//-------------------------------------------

//------------------------------------------- 
//signals
//------------------------------------------- 
logic 					cmd_start_r;  
logic [LEN_DWIDTH-1:0]	cmd_loopInit, cmd_loopInit_r;
logic [LEN_DWIDTH-1:0]	cmd_loopLen, cmd_loopLen_r;
logic [INC_DWIDTH-1:0]	cmd_loopInc, cmd_loopInc_r;
logic 					cmd_loopBreak_en, cmd_loopBreak_en_r;
logic 					cmd_loopIdx_ascend, cmd_loopIdx_ascend_r;
logic 					cmd_loopStart, cmd_loopStart_r;
logic 					cmd_loop_done;

logic 					running, running_r;
logic [LEN_DWIDTH-1:0]	loopCnt;
logic [LEN_DWIDTH-1:0]	loopCnt_r;
logic 					break0;
logic 					break1;

//-------------------------------------------------------------------
//The logic for capturing the cmd register from the external ports
//-------------------------------------------------------------------

always @ (posedge clk or negedge rstn) begin
	if (~rstn) begin
		cmd_loopInit_r <= 0;
		cmd_loopLen_r <= 0;
		{cmd_loopInc_r, cmd_loopIdx_ascend_r, cmd_loopBreak_en_r, cmd_loopStart_r} <= 0; 
	end
	else begin
		cmd_loopInit_r <= cmd_loopInit;
		cmd_loopLen_r <= cmd_loopLen;
		{cmd_loopInc_r, cmd_loopIdx_ascend_r, cmd_loopBreak_en_r, cmd_loopStart_r} <= {cmd_loopInc, cmd_loopIdx_ascend, cmd_loopBreak_en, cmd_loopStart}; 
	end
end

always_comb begin 
	cmd_loopInit = cmd_loopInit_r;
	cmd_loopLen  = cmd_loopLen_r;
	{cmd_loopInc, cmd_loopIdx_ascend, cmd_loopBreak_en, cmd_loopStart} = {cmd_loopInc_r, cmd_loopIdx_ascend_r, cmd_loopBreak_en_r, cmd_loopStart_r};

	if (cmd_start) begin 
		//cmd registers from the the external wrapper ports.
		cmd_loopInit = cmd_loop_init_i;
		cmd_loopLen  = cmd_loop_len_i -1;
		{cmd_loopInc, cmd_loopIdx_ascend, cmd_loopBreak_en, cmd_loopStart} = cmd_loop_inc_i;
	end 

	//When the looping is completed, deassert the signal of cmd_loopStart for informing the user the looper (innerloop) is idle. 	
	if (cmd_loop_done) begin
		cmd_loopStart = 0;
   		cmd_loopLen	  = -1;
	end
    cmd_loop_idle_o	= ~cmd_loopStart_r;
end 









//--------------------------------------------------------------------------------------
//The logic for generating ap interface signals to control the external hls function
//--------------------------------------------------------------------------------------
always @ (posedge clk or negedge rstn) begin
	if (~rstn) begin
		running_r		<= 0;
		loopCnt_r		<= 0;
	end
	else begin
		running_r		<= running;
		loopCnt_r		<= (cmd_start) ? cmd_loopInit : loopCnt;
	end
end

always_comb begin
	running = running_r;
	loopCnt = loopCnt_r;


	if (ENABLE_PIPELINE) begin  
		ap_start = ~running_r & cmd_loopStart_r;
	
		if (ap_start & ap_ready) begin
			running = 1;
			loopCnt = loopCnt_r + cmd_loopInc_r;
			if (cmd_loop_done) begin
				loopCnt = 0;
			end
		end

		if (running & ap_ready) begin
			running = 0;
		end
	end 
	else begin //disable pipeline

		ap_start = ~running_r & cmd_loopStart_r;
	
		running = 1 & cmd_loopStart_r;
		if (ap_done) begin
			running = 0;
			loopCnt = loopCnt_r + cmd_loopInc_r;
			if (cmd_loop_done) begin
				loopCnt = 0;
			end
		end

	end 
	
	//output the index for the external hls function
	ap_idx = (cmd_loopIdx_ascend) ? loopCnt_r : (cmd_loopLen_r - loopCnt_r);
end

//case 0: stop the looper (innerloop) when the looping is completed  
assign break0 = (loopCnt_r == cmd_loopLen_r);
//case 1: stop the looper (innerloop) when getting the return value (break) from the external hls funtion
assign break1 = (cmd_loopBreak_en & ap_done & ap_return);

assign cmd_loop_done =  break0 | break1;
assign cmd_loop_done_o = cmd_loop_done & ~cmd_loop_idle_o;

//----------------------------------------------------
//unused signals
//----------------------------------------------------
//(* DONT_TOUCH  = "true" *)


endmodule
