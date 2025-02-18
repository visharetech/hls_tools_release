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

`include "common.vh"

module xmem import xmem_param_pkg::*;
(
	input 							clk,
	input 							rstn,


	//risc interface
	input 	[3:0]					risc_we,
	input 							risc_re,
	input  [RISC_AWIDTH-1:0]		risc_adr,
	input  [RISC_DWIDTH-1:0]		risc_di,
	output logic					risc_rdy,
	output logic					risc_do_vld,
	output logic [RISC_DWIDTH-1:0] 	risc_do,

	//For dualport bank in scalar range
	input 										scalar_argVld	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	output logic 								scalar_argAck 	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	input [XMEM_AW-1:0]					        scalar_adr		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	input [SCALAR_BANK_DW-1:0]					scalar_wdat		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],
	output logic [SCALAR_BANK_DW-1:0]			scalar_rdat		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT],
	output logic                    			scalar_rdat_vld	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM],

	//For single port bank in array range
	input 										array_argVld	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	output logic 								array_argAck 	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	input [XMEM_AW-1:0]		        			array_adr		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	input [ARRAY_BANK_DW-1:0]					array_wdat		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],
	output logic [ARRAY_BANK_DW-1:0]			array_rdat		[BANK_NUM[MEM_TYPE_ARRAY]],
	output logic                    			array_rdat_vld	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM],

	//For wide port bank in cyclic range
	input 										cyclic_argVld	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	output logic 								cyclic_argAck 	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	input [XMEM_AW-1:0]		        			cyclic_adr		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	input [CYCLIC_BANK_DW-1:0]					cyclic_wdat		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM],
	output logic [CYCLIC_BANK_DW-1:0]			cyclic_rdat		[BANK_NUM[MEM_TYPE_CYCLIC]],
	output logic                    			cyclic_rdat_vld	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM]

);


//---------------------------------------------------------------
//Parameter
//---------------------------------------------------------------
localparam BANK_NUM_SCALAR = BANK_NUM[MEM_TYPE_SCALAR];


//---------------------------------------------------------------
//Signals
//---------------------------------------------------------------
logic 								risc_cmd_en, risc_cmd_en_r, risc_cmd_en_r2;

logic 								scalar_mux_re 		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic 								scalar_mux_we 		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [1:0]							scalar_mux_len		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [XMEM_AW-1:0]					scalar_mux_adr		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [LOG2_MAX_PARTITION-1:0]		scalar_mux_part_idx	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [XMEM_AW-1:0]			        scalar_mux_bankAdr	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_din		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_dout		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];

logic                               risc_argAck_scalar	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];
logic [RISC_DWIDTH-1:0]             risc_do_scalar		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT];


logic 								scalar_mux_re0 		[BANK_NUM[MEM_TYPE_SCALAR]];
logic 								scalar_mux_we0 		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [1:0]							scalar_mux_len0		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [XMEM_AW-1:0]			        scalar_mux_bankAdr0	[BANK_NUM[MEM_TYPE_SCALAR]];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_din0		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_dout0	[BANK_NUM[MEM_TYPE_SCALAR]];

logic 								scalar_mux_re1 		[BANK_NUM[MEM_TYPE_SCALAR]];
logic 								scalar_mux_we1 		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [1:0]							scalar_mux_len1		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [XMEM_AW-1:0]			        scalar_mux_bankAdr1	[BANK_NUM[MEM_TYPE_SCALAR]];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_din1		[BANK_NUM[MEM_TYPE_SCALAR]];
logic [SCALAR_BANK_DW-1:0]			scalar_mux_dout1	[BANK_NUM[MEM_TYPE_SCALAR]];

logic 								array_mux_re 		[BANK_NUM[MEM_TYPE_ARRAY]];
logic 								array_mux_we 		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [1:0]							array_mux_len		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [XMEM_AW-1:0]					array_mux_adr		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [LOG2_MAX_PARTITION-1:0]		array_mux_part_idx	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [XMEM_AW-1:0]			        array_mux_bankAdr	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [ARRAY_BANK_DW-1:0]			array_mux_din		[BANK_NUM[MEM_TYPE_ARRAY]];
logic [ARRAY_BANK_DW-1:0]			array_mux_dout		[BANK_NUM[MEM_TYPE_ARRAY]];

logic                               risc_argAck_array	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [RISC_DWIDTH-1:0]             risc_do_array		[BANK_NUM[MEM_TYPE_ARRAY]];

logic 								cyclic_mux_re 		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic 								cyclic_mux_we 		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [1:0]							cyclic_mux_len		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [XMEM_AW-1:0]					cyclic_mux_adr		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [LOG2_MAX_PARTITION-1:0]		cyclic_mux_part_idx	[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [XMEM_AW-1:0]			        cyclic_mux_bankAdr	[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [CYCLIC_BANK_AW-1:0]			cyclic_mux_wordAdr	[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [3:0][CYCLIC_BANK_DW/4-1:0]	cyclic_mux_din		[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [3:0][CYCLIC_BANK_DW/4-1:0]	cyclic_mux_dout		[BANK_NUM[MEM_TYPE_CYCLIC]];

logic                               risc_argAck_cyclic	[BANK_NUM[MEM_TYPE_SCALAR]];
logic [CYCLIC_BANK_DW-1:0]          risc_di_cyclic;
logic [CYCLIC_BANK_DW-1:0]          risc_do_cyclic		[BANK_NUM[MEM_TYPE_CYCLIC]];


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
logic [XMEM_AW-1:0]					scalar_base		[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [1:0]							scalar_in2Type	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [7:0]							scalar_in2Width	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
logic [7:0]							scalar_in2Wport	[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT][SCALAR_MAX_MUX_NUM];
//--
logic [XMEM_AW-1:0]					scalar_subBankStart   	 [MAX_PARTITION];
logic [XMEM_AW-1:0]					scalar_subBankSize [MAX_PARTITION];
logic 								scalar_matched			 [BANK_NUM[MEM_TYPE_SCALAR]];
logic 								scalar_matched_r		 [BANK_NUM[MEM_TYPE_SCALAR]];

logic [7:0]						    array_mux_num 	[BANK_NUM[MEM_TYPE_ARRAY]];
logic [XMEM_AW-1:0]					array_base		[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [1:0]							array_in2Type	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [7:0]							array_in2Width	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
logic [7:0]							array_in2Wport	[BANK_NUM[MEM_TYPE_ARRAY]][ARRAY_MAX_MUX_NUM];
//--
logic [XMEM_AW-1:0]					array_subRangeStart		 [MAX_PARTITION];
logic [XMEM_AW-1:0]					array_subBankStart  [MAX_PARTITION];
logic [XMEM_AW-1:0]					array_subBankSize  [MAX_PARTITION];
logic 								array_matched			 [BANK_NUM[MEM_TYPE_ARRAY]];
logic 								array_matched_r			 [BANK_NUM[MEM_TYPE_ARRAY]];

logic [7:0]						    cyclic_mux_num	[BANK_NUM[MEM_TYPE_CYCLIC]];
logic [XMEM_AW-1:0]					cyclic_base		[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [1:0]							cyclic_in2Type	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [7:0]							cyclic_in2Width	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
logic [7:0]							cyclic_in2Wport	[BANK_NUM[MEM_TYPE_CYCLIC]][CYCLIC_MAX_MUX_NUM];
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
logic                               risc_rdy_w;
logic                               found;
logic [1:0]                         word_idx;

logic [3:0]                         risc_we_r;
logic                               risc_re_r, risc_re_r2;
logic [XMEM_AW-1:0]                 risc_adr_r, risc_adr_w;
logic [RISC_DWIDTH-1:0]             risc_di_r;


//=================================================================================
// Riscv cmd
//=================================================================================
assign risc_cmd_en = risc_adr[XMEM_CONFIG_ABIT];


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
		scalar_base 	 			<= '{default: '0};
		scalar_in2Type	 			<= '{default: '0};
		scalar_in2Width  			<= '{default: '0};
		scalar_in2Wport  			<= '{default: '0};
		//--
		scalar_subBankStart	<= '{default: '0};
		scalar_subBankSize	<= '{default: '0};

		//For single port bank 	(ARRAY BANK)
		array_mux_num	 			<= '{default: '0};
		array_base 		 			<= '{default: '0};
		array_in2Type	 			<= '{default: '0};
		array_in2Width   			<= '{default: '0};
		array_in2Wport   			<= '{default: '0};
		//--
		array_subRangeStart			<= '{default: '0};
		array_subBankStart		<= '{default: '0};
		array_subBankSize		<= '{default: '0};

		//For wide port bank 	(CYCLIC BANK)
		cyclic_mux_num   			<= '{default: '0};
		cyclic_base 	 			<= '{default: '0};
		cyclic_in2Type	 			<= '{default: '0};
		cyclic_in2Width  			<= '{default: '0};
		cyclic_in2Wport 			<= '{default: '0};
		//--
		cyclic_subRangeStart		<= '{default: '0};
        cyclic_max_subRangeStart    <= '{default: '0};
		cyclic_subBankStart	<= '{default: '0};
		cyclic_subBankSize	<= '{default: '0};
		//--
        scalar_matched_r            <= '{default: '0};
        array_matched_r             <= '{default: '0};
        cyclic_matched_r            <= '{default: '0};
        risc_do <= 0;
        risc_do_vld <= 0;


        risc_rdy <= 1;
        //risc_rdy_r <= 1;
        {risc_cmd_en_r2, risc_cmd_en_r}  <= 0;
        risc_we_r <= 0;
        {risc_re_r2, risc_re_r} <= 0;
        risc_adr_r <= 0;
        risc_di_r <= 0;
        partIdx_r <= 0;
        act_req_r <= 0;
    end
	else begin

		if (risc_we[0] & risc_cmd_en) begin
//			case (risc_adr[7:0])
			case (risc_adr[9:2])
			CMD_SET_SBANK: 	 	 		sBank 									<= risc_di;
			CMD_SET_RPORT: 	 	 		dPort 									<= risc_di;
			CMD_SET_APORT: 	 	 		aPort 									<= risc_di;
			CMD_SET_PART: 			 	part									<= risc_di;
			CMD_PART_NUM: 			 	partNum 								<= risc_di;
			CMD_RANGE_START:		 	rangeStart	[part]						<= risc_di;
			//For SCALAR range
			CMD_SCALAR_MUX_NUM: 	 	scalar_mux_num	[sBank][dPort] 			<= risc_di;
			CMD_SCALAR_BASE:		 	scalar_base 	[sBank][dPort][aPort]	<= risc_di;
			CMD_SCALAR_TYPE:  		 	scalar_in2Type	[sBank][dPort][aPort] 	<= risc_di;
			CMD_SCALAR_WIDTH: 		 	scalar_in2Width	[sBank][dPort][aPort] 	<= risc_di;
			CMD_SCALAR_WPORT: 		 	scalar_in2Wport	[sBank][dPort][aPort] 	<= risc_di;
			//--
			CMD_SCALAR_SUB_PART_START:	scalar_subBankStart[part]			    <= risc_di;
			CMD_SCALAR_SUB_PART_DEPTH:	scalar_subBankSize[part]			<= risc_di;

			//For ARRAY range
			CMD_ARRAY_MUX_NUM: 		 	array_mux_num	[sBank] 				<= risc_di;
			CMD_ARRAY_BASE:			 	array_base 		[sBank][aPort]			<= risc_di;
			CMD_ARRAY_TYPE:  		 	array_in2Type	[sBank][aPort] 			<= risc_di;
			CMD_ARRAY_WIDTH: 		 	array_in2Width	[sBank][aPort] 			<= risc_di;
			CMD_ARRAY_WPORT: 		 	array_in2Wport	[sBank][aPort] 			<= risc_di;
			//--
			CMD_ARRAY_SUB_RNG_START:	array_subRangeStart		[part]			<= risc_di;
			CMD_ARRAY_SUB_PART_START:	array_subBankStart	[part]			    <= risc_di;
			CMD_ARRAY_SUB_PART_DEPTH:	array_subBankSize	[part]			    <= risc_di;

			//For CYCLIC range
			CMD_CYCLIC_MUX_NUM: 	 	cyclic_mux_num	[sBank]  				<= risc_di;
			CMD_CYCLIC_BASE: 			cyclic_base 	[sBank][aPort]			<= risc_di;
			CMD_CYCLIC_TYPE: 		 	cyclic_in2Type	[sBank][aPort]			<= risc_di;
			CMD_CYCLIC_WIDTH: 		 	cyclic_in2Width	[sBank][aPort]			<= risc_di;
			CMD_CYCLIC_WPORT:		 	cyclic_in2Wport	[sBank][aPort]			<= risc_di;
			//--
			CMD_CYCLIC_SUB_RNG_START:	cyclic_subRangeStart	[part]			<= risc_di;
			CMD_CYCLIC_MAX_SUB_RNG_START:	cyclic_max_subRangeStart[part]		<= risc_di;
			CMD_CYCLIC_SUB_PART_START:	cyclic_subBankStart[part]			    <= risc_di;
			CMD_CYCLIC_SUB_PART_DEPTH:	cyclic_subBankSize[part]			<= risc_di;
			endcase
		end

        scalar_matched_r <= scalar_matched;
        array_matched_r  <= array_matched ;
        cyclic_matched_r <= cyclic_matched;
        risc_do <= risc_do_w;
        risc_do_vld <= risc_re_r2 && ~risc_cmd_en_r2 && found;
        //risc_rdy_r <= risc_rdy;
        {risc_cmd_en_r2, risc_cmd_en_r} <= {risc_cmd_en_r, risc_cmd_en};
        risc_we_r <= risc_we;
        {risc_re_r2, risc_re_r} <= {risc_re_r, risc_re};
        risc_adr_r <= risc_adr_w;
        risc_di_r <= risc_di;
        partIdx_r <= partIdx_w;
        act_req_r <= act_req;
        risc_rdy <= risc_rdy_w;

	end
end


always_comb begin
    act_req = risc_re_r && ~risc_cmd_en_r && found;
end

always_comb begin
    risc_do_w = 0;
    risc_rdy_w = 1;//risc_rdy;
    found = 0;
    //if ((risc_re || risc_we) && ~risc_cmd_en && risc_rdy) begin
        //risc_rdy_w = 1;//0;
    //end
    //else begin
        for (int s=0; s<BANK_NUM[MEM_TYPE_SCALAR]; s++) begin
            for (int d=0; d<DUAL_PORT; d++) begin
                if (risc_argAck_scalar[s][d] && ~found) begin
                    risc_do_w = risc_do_scalar[s][d];
                    //risc_rdy_w = 1;
                    found = 1;
                end
            end
        end

        for (int s=0; s<BANK_NUM[MEM_TYPE_ARRAY]; s++) begin
            if (risc_argAck_array[s] && ~found) begin
                risc_do_w = risc_do_array[s];
                //risc_rdy_w = 1;
                found = 1;
            end
        end

        for (int s=0; s<BANK_NUM[MEM_TYPE_CYCLIC]; s++) begin
            if (risc_argAck_cyclic[s] && ~found) begin
                //risc_do_w = risc_do_cyclic[s][word_idx*RISC_DWIDTH +: RISC_DWIDTH];
                risc_do_w = risc_do_cyclic[s][RISC_DWIDTH-1 : 0];
                found = 1;
                //risc_rdy_w = 1;
            end
        end
    //end

end

//=================================================================================
//ReqMux and Xmemory
//=================================================================================

assign partIdx_w = risc_adr[XMEM_PART_AW+PART_IDX_W-1 : XMEM_PART_AW];//risc_adr[XMEM_AW+LOG2_MAX_PARTITION-1 : XMEM_AW];

always_comb begin
    for (int pid=0; pid<MAX_PARTITION; pid++) begin
        subRangeStart[pid][MEM_TYPE_ARRAY-1] = array_subRangeStart[pid];
        subBankSize[pid][MEM_TYPE_ARRAY-1] = scalar_subBankSize[pid];
        subRangeStart[pid][MEM_TYPE_ARRAY] = cyclic_subRangeStart[pid];
        subBankSize[pid][MEM_TYPE_ARRAY] = array_subBankSize[pid];
        subBankSize[pid][MEM_TYPE_CYCLIC] = cyclic_subBankSize[pid];
    end
end

bank_filter inst_bank_filter (
    .adr				( risc_adr[XMEM_PART_AW-1:0]    ),	//global address from RISCV
    .adr_o              ( risc_adr_w[XMEM_AW-1:0]       ),
    .partIdx			( partIdx_w					    ),
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
            logic [XMEM_AW-1:0]		scalar_base_w		[SCALAR_BANK_MUX_NUM[s][d]];
            logic [1:0]				scalar_in2Type_w	[SCALAR_BANK_MUX_NUM[s][d]];
            logic [7:0]				scalar_in2Width_w	[SCALAR_BANK_MUX_NUM[s][d]];
            logic [7:0]				scalar_in2Wport_w	[SCALAR_BANK_MUX_NUM[s][d]];

            logic 						scalar_argVld_w	[SCALAR_BANK_MUX_NUM[s][d]];
            logic  						scalar_argAck_w [SCALAR_BANK_MUX_NUM[s][d]];
            logic [XMEM_AW-1:0]	        scalar_adr_w	[SCALAR_BANK_MUX_NUM[s][d]];
            logic [SCALAR_BANK_DW-1:0]	scalar_wdat_w	[SCALAR_BANK_MUX_NUM[s][d]];
        	logic [SCALAR_BANK_DW-1:0]	scalar_rdat_w;
        	logic                       scalar_rdat_vld_w[SCALAR_BANK_MUX_NUM[s][d]];

            always @(*) begin
                for (int m=0; m<SCALAR_BANK_MUX_NUM[s][d]; m++) begin
                    scalar_base_w    [m]   = scalar_base[s][d][m];
                    scalar_in2Type_w [m]   = scalar_in2Type[s][d][m];
                    scalar_in2Width_w[m]   = scalar_in2Width[s][d][m];
                    scalar_in2Wport_w[m]   = scalar_in2Wport[s][d][m];

                    scalar_argVld_w [m]    = scalar_argVld [s][d][m];
                    scalar_adr_w    [m]    = scalar_adr    [s][d][m];
                    scalar_wdat_w   [m]    = scalar_wdat   [s][d][m];

                    //scalar_argAck[s][d][m] = scalar_argAck_w[m];
                end
                /*for (int m=SCALAR_BANK_MUX_NUM[s][d]; m<SCALAR_MAX_MUX_NUM; m++) begin
                    scalar_argAck[s][d][m] = 0;
                end*/
            end
            `ifndef XMEM_LATENCY_1
                always @(posedge clk or negedge rstn) begin
                    if (~rstn) begin
                        scalar_argAck[s][d] <= '{default: '0};
                        scalar_rdat[s][d] <= 0;
                        scalar_rdat_vld[s][d] <= '{default: '0};
                    end
                    else begin
                        for (int m=0; m<SCALAR_MAX_MUX_NUM; m++) begin
                            if (m<SCALAR_BANK_MUX_NUM[s][d]) begin
                                scalar_argAck[s][d][m] <= scalar_argAck_w[m] && ~(scalar_matched[s]  && ~risc_cmd_en && (risc_we!=0 || risc_re!=0));
                                scalar_rdat_vld[s][d][m] <= scalar_rdat_vld_w[m];
                            end
                            else begin
                                scalar_argAck[s][d][m] <= 0;
                                scalar_rdat_vld[s][d][m] <= 0;
                            end
                        end
                        scalar_rdat[s][d] <= scalar_rdat_w;
                    end
                end
            `else
                always @(*) begin
                    for (int m=0; m<SCALAR_MAX_MUX_NUM; m++) begin
                        if (m<SCALAR_BANK_MUX_NUM[s][d]) begin
                            //scalar_argAck[s][d][m] = scalar_argAck_w[m];
                            scalar_rdat_vld[s][d][m] = scalar_rdat_vld_w[m];
                        end
                        else begin
                            //scalar_argAck[s][d][m] = 0;
                            scalar_rdat_vld[s][d][m] = 0;
                        end
                    end
                    scalar_rdat[s][d] = scalar_rdat_w;
                end
                always @(posedge clk or negedge rstn) begin
                    if (~rstn) begin
                        scalar_argAck[s][d] <= '{default: '0};
                    end
                    else begin
                        for (int m=0; m<SCALAR_MAX_MUX_NUM; m++) begin
                            if (m<SCALAR_BANK_MUX_NUM[s][d]) begin
                                scalar_argAck[s][d][m] <= scalar_argAck_w[m];
                            end
                            else begin
                                scalar_argAck[s][d][m] <= 0;
                            end
                        end
                    end
                end
            `endif
			reqMux #(
				.RANGE_TYPE 	( "SCALAR"					),
				.MUX_NUM	    ( SCALAR_BANK_MUX_NUM[s][d]	),
				.AW				( XMEM_AW          			),
				.DW				( SCALAR_BANK_DW			),
                .PORT_IDX       ( d                         )
			)
			inst_reqMux_scalar(
				.rstn			( rstn						),
				.clk			( clk						),
				//the config registers
				.rangeStart		( rangeStart				),
				.mux_num 		( scalar_mux_num	[s][d]	),
				.base 			( scalar_base_w		    	),	//byte address
				.in2Type		( scalar_in2Type_w	    	),
				.in2Width		( scalar_in2Width_w	    	),
				.in2Wport		( scalar_in2Wport_w	    	),
				//connnect to functional accelerator
				.f_argVld		( scalar_argVld_w	    	),
				.f_argAck		( scalar_argAck_w	    	),
				.f_adr			( scalar_adr_w		    	),
				.f_wdat			( scalar_wdat_w		    	),
				.f_rdat			( scalar_rdat_w             ),
				.f_rdat_vld		( scalar_rdat_vld_w         ),
                //--
    			.matched		( scalar_matched_r	[s]		),
                .risc_argWe     ( risc_we_r                   ),
                .risc_argRe     ( risc_re_r                   ),
                .risc_argAck    ( risc_argAck_scalar[s][d]  ),
                .risc_argAdr    ( risc_adr_r[XMEM_AW-1:0]       ),
                .risc_argPartIdx( partIdx_r                 ),
                .risc_argWdat   ( risc_di_r                   ),
                .risc_argRdat   ( risc_do_scalar[s][d]      ),

				//--
				.mux_re			( scalar_mux_re 	[s][d]	 ),
				.mux_we			( scalar_mux_we 	[s][d]	 ),
				.mux_len		( scalar_mux_len	[s][d]	 ),
				.mux_adr		( scalar_mux_adr	[s][d]	 ),
                .mux_part_idx   ( scalar_mux_part_idx [s][d] ),
				.mux_din		( scalar_mux_din	[s][d]	 ),
				.mux_dout		( scalar_mux_dout	[s][d]	 )
			);

			//------ cal bankAdr ------//
			cal_bankAdr #(
				.RANGE_TYPE 		( "SCALAR"					),
				.BANK_ADR_WIDTH 	( SCALAR_BANK_AW			)
			)
			inst_cal_bankAdr_scalar  (
				.adr				( scalar_mux_adr	[s][d]	), 				//global address
				.partIdx			( scalar_mux_part_idx [s][d]),
				//From Risc
				//.rangeStart			( rangeStart				),
				.subRangeStart		( 		),
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

		//------ scalar bank ------//
		scalar_bank #(
			.AW	( SCALAR_BANK_AW ),
			.DW	( SCALAR_BANK_DW )
		)
		inst_scalar_bank (
			.clk	( clk 						),
			.we0	( scalar_mux_we0 		[s]	),
			.we1	( scalar_mux_we1		[s]	),
			.len0	( scalar_mux_len0		[s]	),
			.len1	( scalar_mux_len1		[s]	),
			.adr0	( scalar_mux_bankAdr0	[s] ),
			.adr1	( scalar_mux_bankAdr1	[s]	),
			.din0	( scalar_mux_din0		[s] ),
			.din1	( scalar_mux_din1		[s]	),
			.dout0	( scalar_mux_dout0		[s]	),
			.dout1	( scalar_mux_dout1		[s]	)
		);
	end

	//---------------------------------------------------------------
	//	ARRAY RANGE
	//---------------------------------------------------------------
	for (genvar s=0; s<BANK_NUM[MEM_TYPE_ARRAY]; s++) begin: ARRAY

        logic [XMEM_AW-1:0]		array_base_w		[ARRAY_BANK_MUX_NUM[s]];
        logic [1:0]				array_in2Type_w	    [ARRAY_BANK_MUX_NUM[s]];
        logic [7:0]				array_in2Width_w	[ARRAY_BANK_MUX_NUM[s]];
        logic [7:0]				array_in2Wport_w	[ARRAY_BANK_MUX_NUM[s]];

        logic 						array_argVld_w	[ARRAY_BANK_MUX_NUM[s]];
        logic  						array_argAck_w  [ARRAY_BANK_MUX_NUM[s]];
        logic [XMEM_AW-1:0]	        array_adr_w	    [ARRAY_BANK_MUX_NUM[s]];
        logic [ARRAY_BANK_DW-1:0]	array_wdat_w	[ARRAY_BANK_MUX_NUM[s]];
        logic [ARRAY_BANK_DW-1:0]	array_rdat_w;
        logic                       array_rdat_vld_w[ARRAY_BANK_MUX_NUM[s]];

        always @(*) begin
            for (int m=0; m<ARRAY_BANK_MUX_NUM[s]; m++) begin
                array_base_w    [m]   = array_base[s][m];
                array_in2Type_w [m]   = array_in2Type[s][m];
                array_in2Width_w[m]   = array_in2Width[s][m];
                array_in2Wport_w[m]   = array_in2Wport[s][m];

                array_argVld_w [m]    = array_argVld [s][m];
                array_adr_w    [m]    = array_adr    [s][m];
                array_wdat_w   [m]    = array_wdat   [s][m];

                //array_argAck[s][m]    = array_argAck_w[m];
            end
            /*for (int m=ARRAY_BANK_MUX_NUM[s]; m<ARRAY_MAX_MUX_NUM; m++) begin
                array_argAck[s][m] = 0;
            end*/
        end
        `ifndef XMEM_LATENCY_1
            always @(posedge clk or negedge rstn) begin
                if (~rstn) begin
                    array_argAck[s] <= '{default: '0};
                    array_rdat[s] <= 0;
                    array_rdat_vld[s] <= '{default: '0};
                end
                else begin
                    for (int m=0; m<ARRAY_MAX_MUX_NUM; m++) begin
                        if (m<ARRAY_BANK_MUX_NUM[s]) begin
                            array_argAck[s][m] <= array_argAck_w[m] && ~(array_matched[s]  && ~risc_cmd_en && (risc_we!=0 || risc_re!=0));
                            array_rdat_vld[s][m] <= array_rdat_vld_w[m];
                        end
                        else begin
                            array_argAck[s][m] <= 0;
                            array_rdat_vld[s][m] <= 0;
                        end
                    end
                    array_rdat[s] <= array_rdat_w;
                end
            end
        `else
            always @(*) begin
                for (int m=0; m<ARRAY_MAX_MUX_NUM; m++) begin
                    if (m<ARRAY_BANK_MUX_NUM[s]) begin
                        //array_argAck[s][m] = array_argAck_w[m];
                        array_rdat_vld[s][m] = array_rdat_vld_w[m];
                    end
                    else begin
                        //array_argAck[s][m] = 0;
                        array_rdat_vld[s][m] = 0;
                    end
                end
                array_rdat[s] = array_rdat_w;
            end
            always @(posedge clk or negedge rstn) begin
                if (~rstn) begin
                    array_argAck[s] <= '{default: '0};
                end
                else begin
                    for (int m=0; m<ARRAY_MAX_MUX_NUM; m++) begin
                        if (m<ARRAY_BANK_MUX_NUM[s]) begin
                            array_argAck[s][m] <= array_argAck_w[m];
                        end
                        else begin
                            array_argAck[s][m] <= 0;
                        end
                    end
                end
            end

        `endif

		//------ request mux ------//
		reqMux #(
			.RANGE_TYPE 	( "ARRAY"				),
			.MUX_NUM	    ( ARRAY_BANK_MUX_NUM[s]	),
			.AW				( XMEM_AW   			),
			.DW				( ARRAY_BANK_DW			),
            .PORT_IDX       ( 0                     )
		)
		inst_reqMux_array (
			.rstn			( rstn					),
			.clk			( clk					),
			//the config registers
			.rangeStart		( rangeStart				),
			.mux_num 		( array_mux_num		[s]	),
			.base 			( array_base_w			),	//byte address
			.in2Type		( array_in2Type_w		),
			.in2Width		( array_in2Width_w		),
			.in2Wport		( array_in2Wport_w		),
			//connnect to functional accelerator
			.f_argVld		( array_argVld_w		),
			.f_argAck		( array_argAck_w		),
			.f_adr			( array_adr_w			),
			.f_wdat			( array_wdat_w	        ),
			.f_rdat			( array_rdat_w          ),
			.f_rdat_vld		( array_rdat_vld_w      ),
            //--
			.matched		( array_matched_r	[s]		),
            .risc_argWe     ( risc_we_r               ),
            .risc_argRe     ( risc_re_r               ),
            .risc_argAck    ( risc_argAck_array[s]  ),
            .risc_argAdr    ( risc_adr_r[XMEM_AW-1:0]              ),
            .risc_argPartIdx( partIdx_r                 ),
            .risc_argWdat   ( risc_di_r               ),
            .risc_argRdat   ( risc_do_array[s]      ),

			//--
			.mux_re			( array_mux_re 		[s]	),
			.mux_we			( array_mux_we 		[s]	),
			.mux_len		( array_mux_len		[s]	),
			.mux_adr		( array_mux_adr		[s] ),
            .mux_part_idx   ( array_mux_part_idx [s]),
			.mux_din		( array_mux_din		[s] ),
			.mux_dout		( array_mux_dout	[s]	)
		);

		//------ cal bankAdr ------//
		cal_bankAdr #(
			.RANGE_TYPE 	( "ARRAY"				),
			.BANK_ADR_WIDTH ( ARRAY_BANK_AW			)
		)
		inst_cal_bankAdr_array  (
			.adr				( array_mux_adr	[s]			), 				//global address
			.partIdx			( array_mux_part_idx[s]		),
			//From Risc
			//.rangeStart			( rangeStart				),
			.subRangeStart		( array_subRangeStart		),
			.subBankStart	    ( array_subBankStart	    ),
			.subBankSize	    ( array_subBankSize	    ),
			//
			.bankAdr			( array_mux_bankAdr[s]		)
		);

		//------ array bank ------//
		array_bank #(
			.AW	( ARRAY_BANK_AW ),
			.DW	( ARRAY_BANK_DW )
		)
		inst_array_bank (
			.clk	( clk 					),
			.we0	( array_mux_we 		[s]	),
			.len0	( array_mux_len		[s]	),
			.adr0	( array_mux_bankAdr	[s] ),
			.din0	( array_mux_din		[s] ),
			.dout0	( array_mux_dout	[s]	)
		);
	end

	//---------------------------------------------------------------
	//	CYCLIC RANGE
	//---------------------------------------------------------------
    always_comb begin
        risc_di_cyclic = risc_di_r;
    end

	for (genvar s=0; s<BANK_NUM[MEM_TYPE_CYCLIC]; s++) begin: CYCLIC
        logic [XMEM_AW-1:0]		cyclic_base_w		[CYCLIC_BANK_MUX_NUM[s]];
        logic [1:0]				cyclic_in2Type_w    [CYCLIC_BANK_MUX_NUM[s]];
        logic [7:0]				cyclic_in2Width_w	[CYCLIC_BANK_MUX_NUM[s]];
        logic [7:0]				cyclic_in2Wport_w	[CYCLIC_BANK_MUX_NUM[s]];

        logic 						cyclic_argVld_w	[CYCLIC_BANK_MUX_NUM[s]];
        logic  						cyclic_argAck_w [CYCLIC_BANK_MUX_NUM[s]];
        logic [XMEM_AW-1:0]	        cyclic_adr_w    [CYCLIC_BANK_MUX_NUM[s]];
        logic [CYCLIC_BANK_DW-1:0]	cyclic_wdat_w	[CYCLIC_BANK_MUX_NUM[s]];
        logic [CYCLIC_BANK_DW-1:0]	cyclic_rdat_w;
        logic                       cyclic_rdat_vld_w[CYCLIC_BANK_MUX_NUM[s]];

        always @(*) begin
            for (int m=0; m<CYCLIC_BANK_MUX_NUM[s]; m++) begin
                cyclic_base_w    [m]   = cyclic_base[s][m];
                cyclic_in2Type_w [m]   = cyclic_in2Type[s][m];
                cyclic_in2Width_w[m]   = cyclic_in2Width[s][m];
                cyclic_in2Wport_w[m]   = cyclic_in2Wport[s][m];

                cyclic_argVld_w [m]    = cyclic_argVld [s][m];
                cyclic_adr_w    [m]    = cyclic_adr    [s][m];
                cyclic_wdat_w   [m]    = cyclic_wdat   [s][m];

                //cyclic_argAck[s][m]    = cyclic_argAck_w[m];
            end
            /*for (int m=CYCLIC_BANK_MUX_NUM[s]; m<CYCLIC_MAX_MUX_NUM; m++) begin
                cyclic_argAck[s][m] = 0;
            end*/
        end
        `ifndef XMEM_LATENCY_1
            always @(posedge clk or negedge rstn) begin
                if (~rstn) begin
                    cyclic_argAck[s] <= '{default: '0};
                    cyclic_rdat[s] <= 0;
                    cyclic_rdat_vld[s] <= '{default: '0};
                end
                else begin
                    for (int m=0; m<CYCLIC_MAX_MUX_NUM; m++) begin
                        if (m<CYCLIC_BANK_MUX_NUM[s]) begin
                            cyclic_argAck[s][m] <= cyclic_argAck_w[m] && ~(cyclic_matched[s]  && ~risc_cmd_en && (risc_we!=0 || risc_re!=0));
                            cyclic_rdat_vld[s][m] <= cyclic_rdat_vld_w[m];
                        end
                        else begin
                            cyclic_argAck[s][m] <= 0;
                            cyclic_rdat_vld[s][m] <= 0;
                        end
                    end
                    cyclic_rdat[s] <= cyclic_rdat_w;
                end
            end
        `else
            always @(*) begin
                for (int m=0; m<CYCLIC_MAX_MUX_NUM; m++) begin
                    if (m<CYCLIC_BANK_MUX_NUM[s]) begin
                        //cyclic_argAck[s][m] = cyclic_argAck_w[m];
                        cyclic_rdat_vld[s][m] = cyclic_rdat_vld_w[m];
                    end
                    else begin
                        //cyclic_argAck[s][m] = 0;
                        cyclic_rdat_vld[s][m] = 0;
                    end
                end
                cyclic_rdat[s] = cyclic_rdat_w;
            end
            always @(posedge clk or negedge rstn) begin
                if (~rstn) begin
                    cyclic_argAck[s] <= '{default: '0};
                end
                else begin
                    for (int m=0; m<CYCLIC_MAX_MUX_NUM; m++) begin
                        if (m<CYCLIC_BANK_MUX_NUM[s]) begin
                            cyclic_argAck[s][m] <= cyclic_argAck_w[m];
                        end
                        else begin
                            cyclic_argAck[s][m] <= 0;
                        end
                    end
                end
            end
        `endif
		//------ request mux ------//
		reqMux #(
			.RANGE_TYPE 	( "CYCLIC"					),
			.MUX_NUM    	( CYCLIC_BANK_MUX_NUM[s]	),
			.AW		        ( XMEM_AW       			),
			.DW		        ( CYCLIC_BANK_DW			),
            .PORT_IDX       ( 0                         )
		)
		inst_reqMux_cyclic (
			.rstn			( rstn					        ),
			.clk			( clk					        ),
			//the config registers
			.rangeStart		( rangeStart					),
			.mux_num 		( cyclic_mux_num	[s]	        ),
			.base 			( cyclic_base_w     	        ),	//byte address
			.in2Type		( cyclic_in2Type_w  	        ),
			.in2Width		( cyclic_in2Width_w 	        ),
			.in2Wport		( cyclic_in2Wport_w 	        ),
			//connnect to functional accelerator
			.f_argVld		( cyclic_argVld_w		        ),
			.f_argAck		( cyclic_argAck_w		        ),
			.f_adr			( cyclic_adr_w			        ),
			.f_wdat			( cyclic_wdat_w			        ),
			.f_rdat			( cyclic_rdat_w                 ),
			.f_rdat_vld		( cyclic_rdat_vld_w             ),
            //--
			.matched		( cyclic_matched_r [s]            ),
            .risc_argWe     ( risc_we_r                       ),
            .risc_argRe     ( risc_re_r                       ),
            .risc_argAck    ( risc_argAck_cyclic[s]         ),
            .risc_argAdr    ( risc_adr_r[XMEM_AW-1:0]       ),
            .risc_argPartIdx( partIdx_r                 ),
            .risc_argWdat   ( risc_di_cyclic                ),
            .risc_argRdat   ( risc_do_cyclic[s]             ),

			//--
			.mux_re			( cyclic_mux_re 	[s]	        ),
			.mux_we			( cyclic_mux_we 	[s]	        ),
			.mux_len		( cyclic_mux_len	[s]	        ),
			.mux_adr		( cyclic_mux_adr	[s]         ),
            .mux_part_idx   ( cyclic_mux_part_idx [s]       ),
			.mux_din		( cyclic_mux_din	[s]         ),
			.mux_dout		( cyclic_mux_dout	[s]	        )
		);

		//------ cal bankAdr ------//
		cal_bankAdr #(
			.RANGE_TYPE 	( "CYCLIC"			),
			.BANK_ADR_WIDTH ( CYCLIC_BANK_AW	)
		)
		inst_cal_bankAdr_cyclic  (
			.adr				( cyclic_mux_adr	[s]		), 				//global address
			.partIdx			( cyclic_mux_part_idx[s]	),
			//From Risc
			//.rangeStart			( rangeStart				),
			.subRangeStart		( cyclic_subRangeStart	),
			.subBankStart	    ( cyclic_subBankStart	    ),
			.subBankSize	    ( cyclic_subBankSize	    ),
			//
			.bankAdr			( cyclic_mux_bankAdr[s]		)
		);

		//byte address --> word address
		assign cyclic_mux_wordAdr[s] = cyclic_mux_bankAdr[s]>>2;

		`ifdef ENABLE_CYCLIC_BANK
		//------ cyclic bank ------//
		cyclic_bank #(
			.ADDR_WIDTH ( CYCLIC_BANK_AW	),
			.DATA_WIDTH ( CYCLIC_BANK_DW/4	)
		)
		inst_cyclic_bank (
			.rstn		( rstn						),
			.clk		( clk						),
			.re			( cyclic_mux_re			[s]	),
			.we			( cyclic_mux_we			[s]	),
			.len		( cyclic_mux_len		[s]	),
			.wordAdr	( cyclic_mux_wordAdr	[s]	),
			.din		( cyclic_mux_din 		[s] ),
			.dout		( cyclic_mux_dout 		[s]	)
		);
		`else 
			assign cyclic_mux_dout[s] = 0;
		`endif 
		

	end
endgenerate


	
	
	
endmodule






