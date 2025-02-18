// innerloop wrapper
// submodule = ${submodule}
// pipeline = ${pipeline}
module innerloop_${submodule} #(
    parameter LEN_DWIDTH = 32,
    parameter INC_DWIDTH = 32-3/*16*/,     //INC_DWIDTH can be increased.
    //constant parameters
    localparam CMD_LOOP_INIT_BITS  = LEN_DWIDTH,
    localparam CMD_LOOP_LEN_BITS   = LEN_DWIDTH,
    localparam CMD_LOOP_INC_BITS   = INC_DWIDTH + 3,
    localparam CMD_LOOP_CNT_BITS   = 32
)
(
    input                                   ap_clk,
    input                                   ap_rstn,
    input                                   ap_start,
    output logic                            ap_done,
    output logic                            ap_idle,
    output logic                            ap_ready,
    output logic [31:0]                     ap_return,           
    
	input [CMD_LOOP_INIT_BITS-1:0]          loop_init,
	input [CMD_LOOP_LEN_BITS-1:0]           loop_len,
	input [CMD_LOOP_INC_BITS-1:0]           loop_inc,
    output logic [CMD_LOOP_CNT_BITS-1:0]    loop_cnt,
    output logic                            loop_cnt_ap_vld,

    //--
${declare_ioport}
    //--
);

//----------------------------------------------------------------------
//signals 
//----------------------------------------------------------------------
logic             cmd_start;
logic             loop_idle;
logic             loop_done;
logic             loop_done_r;

//ap interface
${declare_ap_ctrl}
logic [31:0]    ${submodule}_ap_return_r;

logic [31:0]    ${submodule}_ap_idx;
logic           ${submodule}_ap_ret;
logic [31:0]    ${submodule}_doneCnt;


//----------------------------------------------------------------------
//ctrl 
//----------------------------------------------------------------------

//----------------------------------------------------------------------
//module: innerloop
//----------------------------------------------------------------------
innerloop # (
    .LEN_DWIDTH         ( LEN_DWIDTH    ),
    .INC_DWIDTH         ( INC_DWIDTH    ),
    .ENABLE_PIPELINE    ( ${pipeline}   )
)
inst_innerloop(
    //common interface
    .clk                ( ap_clk                    ),
    .rstn               ( ap_rstn                   ),
    //cmd interface
    .cmd_start          ( cmd_start                 ),
    
    .cmd_loop_init_i    ( loop_init                 ),
    .cmd_loop_len_i     ( loop_len                  ),
    .cmd_loop_inc_i     ( loop_inc                  ),
    .cmd_loop_idle_o    ( loop_idle                 ),
    .cmd_loop_done_o    ( loop_done                 ),
    
    //ap interface
    .ap_start           ( ${submodule}_ap_start     ),
    .ap_done            ( ${submodule}_ap_done      ),
    .ap_idle            ( ${submodule}_ap_idle      ),
    .ap_ready           ( ${submodule}_ap_ready     ),
    .ap_return          ( ${submodule}_ap_ret       ),
    .ap_idx             ( ${submodule}_ap_idx       )
);




${inst}

//----------------------------------------------------------------------


always @ (posedge ap_clk or negedge ap_rstn) begin 
    if (~ap_rstn) begin 
        ${submodule}_doneCnt    <= 0;
        loop_done_r     <= 0;
        ${submodule}_ap_return_r <= 0;
    end 
    else begin
        if (ap_start) begin 
            ${submodule}_doneCnt <= 0;
        end 
        else if (${submodule}_ap_done) begin 
            ${submodule}_doneCnt <= ${submodule}_doneCnt + 1; 
        end
        
        loop_done_r <= loop_done;
        ${submodule}_ap_return_r <= ${submodule}_ap_return;
    end 
end 

assign ap_idle              = loop_idle;
assign ap_return            = ${submodule}_ap_return_r;
assign ap_done              = loop_done_r; 
assign ap_ready             = cmd_start;
assign ${submodule}_ap_ret  = (${submodule}_ap_return !=0);

assign cmd_start            = ap_start;
assign loop_cnt             = ${submodule}_doneCnt;
assign loop_cnt_ap_vld      = loop_done_r;

endmodule 