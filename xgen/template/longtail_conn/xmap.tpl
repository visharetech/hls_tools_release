
${desc}

${macro}

module custom_connection import hls_long_tail_pkg::*, xcache_param_pkg::*;
(
    input                               clk,
    input                               rstn,
    //ap interface
    input                               ap_arb_start        [HLS_NUM],
    input                               ap_arb_ret          [HLS_NUM],
    output logic                        ap_start            [HLS_NUM],
    input                               ap_ready            [HLS_NUM],
    input                               ap_idle             [HLS_NUM],
    input                               ap_done             [HLS_NUM],
    input [7:0]                         ap_part             [HLS_NUM],

    //dual port bank in scalar range
    output logic                        scalar_argVld       [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
    input                               scalar_argAck       [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
    output logic [XMEM_AW-1:0]          scalar_adr          [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
    output logic [SCALAR_BANK_DW-1:0]   scalar_wdat         [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
    input [SCALAR_BANK_DW-1:0]          scalar_rdat         [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
    input                               scalar_rdat_vld     [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],

    //single port bank in array range
    input                               array_argRdy        [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
    output logic                        array_ap_ce         [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
    output logic                        array_argVld        [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
    input                               array_argAck        [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
    output logic [XMEM_AW-1:0]          array_adr           [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
    output logic [ARRAY_BANK_DW-1:0]    array_wdat          [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
    input [ARRAY_BANK_DW-1:0]           array_rdat          [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
    input                               array_rdat_vld      [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
    //wide port bank in cyclic range
    input                               cyclic_argRdy       [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
    output logic                        cyclic_ap_ce        [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
    output logic                        cyclic_argVld       [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
    input                               cyclic_argAck       [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
    output logic [XMEM_AW-1:0]          cyclic_adr          [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
    output logic [CYCLIC_BANK_DW-1:0]   cyclic_wdat         [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
    input [CYCLIC_BANK_DW-1:0]          cyclic_rdat         [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
    input                               cyclic_rdat_vld     [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],


    //hls function connection 
${module_argv}
);

//---------------------------------------------------------------------------
//signals 
//---------------------------------------------------------------------------
localparam BANK_NUM_ALL = BANK_NUM[MEM_TYPE_SCALAR] + BANK_NUM[MEM_TYPE_ARRAY] + BANK_NUM[MEM_TYPE_CYCLIC];


//---------------------------------------------------------------------------
//signals 
//---------------------------------------------------------------------------
logic [7:0]                 ap_part_w           [HLS_NUM];
logic [7:0]                 ap_part_r           [HLS_NUM];

logic                       ap_arb_start_r      [HLS_NUM];
logic                       ap_arb_start_2r     [HLS_NUM];

logic                       ap_arb_start_running   [HLS_NUM];
logic                       ap_arb_start_running_r [HLS_NUM];

logic                       ap_arb_ret_r        [HLS_NUM];
logic                       ap_arb_ret_2r       [HLS_NUM];

logic                       ap_start_r          [HLS_NUM];
logic                       ap_ready_r          [HLS_NUM];
logic                       ap_done_r           [HLS_NUM];

logic                       ap_running          [HLS_NUM];
logic                       ap_running_r        [HLS_NUM];

logic                       ap_arb_ret_running   [HLS_NUM];
logic                       ap_arb_ret_running_r [HLS_NUM];

logic                       ap_arb_reload        [HLS_NUM];
logic                       ap_arb_reload_r      [HLS_NUM];

logic                       ap_arb_reload_running   [HLS_NUM];
logic                       ap_arb_reload_running_r [HLS_NUM];


//dual port bank in scalar range
logic                       scalar_argdone          [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic                       scalar_argdone_r        [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];

logic         				scalar_argAckdone   	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic         				scalar_argAckdone_r 	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic                       scalar_argAckdone_all	[HLS_NUM];
logic                       scalar_argAckdone_all_r	[HLS_NUM];

logic                       scalar_argdone_all      [HLS_NUM];
logic                       scalar_argdone_all_r    [HLS_NUM];
logic                       scalar_argVld_r         [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic                       scalar_argAck_r         [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic                       scalar_argVld_all       [HLS_NUM];
logic                       scalar_argVld_all_r     [HLS_NUM];
logic                       scalar_rdat_vld_r       [BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];

//single port bank in array range
logic                       array_argdone           [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic                       array_argdone_r         [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic                       array_argVld_r          [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [XMEM_AW-1:0]         array_adr_r             [BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];

//wide port bank in cyclic range
logic                       cyclic_argdone          [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic                       cyclic_argdone_r        [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic                       cyclic_argVld_r         [BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];

${decl_block}

always @ (posedge clk or negedge rstn) begin 
    if (~rstn) begin
        ap_part_r               <= '{default: '0};
        ap_arb_start_r          <= '{default: '0};
        ap_arb_start_2r         <= '{default: '0};
        ap_arb_start_running_r	<= '{default: '0};
        ap_arb_ret_r            <= '{default: '0};
        ap_arb_ret_2r           <= '{default: '0};
        ap_arb_ret_running_r    <= '{default: '0};
        ap_arb_reload_r         <= '{default: '0};
        ap_arb_reload_running_r <= '{default: '0};
        ap_running_r            <= '{default: '0};
        ap_start_r              <= '{default: '0};
        ap_ready_r              <= '{default: '0};
        ap_done_r               <= '{default: '0};
        scalar_argdone_r        <= '{default: '0};
        scalar_argdone_all_r    <= '{default: '0};
        scalar_argVld_r         <= '{default: '0};
        scalar_argVld_all_r     <= '{default: '0};
        scalar_argAck_r			<= '{default: '0};
		scalar_argAckdone_r		<= '{default: 1'b1};
		scalar_argAckdone_all_r	<= '{default: '0};
		scalar_rdat_vld_r		<= '{default: '0};
        array_argdone_r         <= '{default: '0};
        array_argVld_r          <= '{default: '0};
        array_adr_r             <= '{default: '0};
        cyclic_argdone_r        <= '{default: '0};
        cyclic_argVld_r         <= '{default: '0};
        
${reset_block}
    end 
    else begin
        ap_part_r               <= ap_part_w;
        ap_arb_start_r          <= ap_arb_start;
        ap_arb_start_2r         <= ap_arb_start_r;
        ap_arb_start_running_r	<= ap_arb_start_running;
        ap_arb_ret_r            <= ap_arb_ret;
        ap_arb_ret_2r           <= ap_arb_ret_r;
        ap_arb_ret_running_r    <= ap_arb_ret_running;
        ap_arb_reload_r         <= ap_arb_reload;
        ap_arb_reload_running_r <= ap_arb_reload_running;
        ap_running_r            <= ap_running;
        ap_start_r              <= ap_start;
        ap_ready_r              <= ap_ready;
        ap_done_r               <= ap_done;
        array_adr_r             <= array_adr;
        scalar_argdone_r        <= scalar_argdone;
        scalar_argdone_all_r    <= scalar_argdone_all;
        scalar_argVld_r         <= scalar_argVld;
        scalar_argVld_all_r     <= scalar_argVld_all;
		scalar_argAck_r			<= scalar_argAck;
		scalar_argAckdone_r		<= scalar_argAckdone;
		scalar_argAckdone_all_r <= scalar_argAckdone_all;
		scalar_rdat_vld_r		<= scalar_rdat_vld;
        array_argdone_r         <= array_argdone;
        array_argVld_r          <= array_argVld;
        cyclic_argdone_r        <= cyclic_argdone;
        cyclic_argVld_r         <= cyclic_argVld;
        
${always_block}
    end
end


always_comb begin
    ap_part_w               = ap_part_r;
    ap_arb_start_running    = ap_arb_start_running_r;
    ap_arb_ret_running      = ap_arb_ret_running_r;
    ap_running              = ap_running_r;
    ap_start                = ap_start_r;
    ap_arb_reload_running   = ap_arb_reload_running_r;
    ap_arb_reload           = '{default: '0};
    scalar_argdone          = scalar_argdone_r;
    scalar_argAckdone		= scalar_argAckdone_r;
    array_argdone           = array_argdone_r;
    cyclic_argdone          = cyclic_argdone_r;

    scalar_argVld           = scalar_argVld_r;
    array_argVld            = array_argVld_r;
    cyclic_argVld           = cyclic_argVld_r;

    scalar_adr              = '{default: '0};
    scalar_wdat             = '{default: '0};
    scalar_argdone_all      = '{default: '0};
    scalar_argVld_all       = '{default: '0};
    scalar_argAckdone_all   = scalar_argAckdone_all_r;
    //array_adr             = '{default: '0};
    array_adr               = array_adr_r;
    array_wdat              = '{default: '0};
    cyclic_adr              = '{default: '0};
    cyclic_wdat             = '{default: '0};

    array_ap_ce             = '{default: '0};
    cyclic_ap_ce            = '{default: '0};
${comb_block}
end

endmodule