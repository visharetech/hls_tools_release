`include "common.vh"

package xmem_param_pkg;




	//===============================================================
	//Enum
	//===============================================================
	typedef enum {
		MEM_TYPE_SCALAR,
		MEM_TYPE_ARRAY,
		MEM_TYPE_CYCLIC,
		MEM_TYPE_MAX
	} memType_t;

	enum {
		SCALAR_S=-1,
		ARRAY_S,
		CYCLIC_S,
		SUB_RANGE_ALL
	} subRng_t;

	enum {
		CMD_SET_SBANK,
		CMD_SET_RPORT,
		CMD_SET_APORT,
		CMD_SET_PART,
		CMD_PART_NUM,
		CMD_RANGE_START,
		//For SCALAR range
		CMD_SCALAR_MUX_NUM,
		CMD_SCALAR_FUNC_IDX,
		CMD_SCALAR_ARG_IDX,
		CMD_SCALAR_BASE,
		CMD_SCALAR_IS_ARRAY,
		CMD_SCALAR_TYPE,
		CMD_SCALAR_WIDTH,
		CMD_SCALAR_WPORT,
		//--
		CMD_SCALAR_SUB_RNG_START,
		CMD_SCALAR_SUB_PART_START,
		CMD_SCALAR_SUB_PART_DEPTH,

		//For ARRAY range
		CMD_ARRAY_MUX_NUM,
		CMD_ARRAY_FUNC_IDX,
		CMD_ARRAY_ARG_IDX,
		CMD_ARRAY_BASE,
		CMD_ARRAY_IS_ARRAY,
		CMD_ARRAY_TYPE,
		CMD_ARRAY_WIDTH,
		CMD_ARRAY_WPORT,
		//--
		CMD_ARRAY_SUB_RNG_START,
		CMD_ARRAY_SUB_PART_START,
		CMD_ARRAY_SUB_PART_DEPTH,

		//For CYCLIC range
		CMD_CYCLIC_MUX_NUM,
		CMD_CYCLIC_FUNC_IDX,
		CMD_CYCLIC_ARG_IDX,
		CMD_CYCLIC_BASE,
		CMD_CYCLIC_IS_ARRAY,
		CMD_CYCLIC_TYPE,
		CMD_CYCLIC_WIDTH,
		CMD_CYCLIC_WPORT,
		//--
		CMD_CYCLIC_SUB_RNG_START,
		CMD_CYCLIC_MAX_SUB_RNG_START,
		CMD_CYCLIC_SUB_PART_START,
		CMD_CYCLIC_SUB_PART_DEPTH

	} cmd_t;


	enum {
		IDLE,
		READ,
		WRITE,
		READ_WRITE
	} type_t;

	//===============================================================
	//localparams
	//===============================================================

	localparam XMEM_AW 				= 18;    //32
	localparam XMEM_PART_AW 		= 16;
    localparam PART_IDX_W           = 3;
	localparam XMEM_DW 				= 32;

	localparam XMEM_CONFIG_ABIT		= 19;		//23

	localparam RISC_AWIDTH 			= 32;
	localparam RISC_DWIDTH 			= 32;

	localparam CORES					= 4;
	localparam MAX_FUNC 				= 256;

	localparam SUPERBANK				= 32;
	localparam DUAL_PORT 			= 2;		//DUAL port = 2 port


    `include "bank_mux_params.svh"


	localparam logic [31:0] MAX_BANK_NUM = BANK_NUM[MEM_TYPE_SCALAR] + BANK_NUM[MEM_TYPE_ARRAY] + BANK_NUM[MEM_TYPE_CYCLIC];



	localparam logic [31:0] LOG2_MAX_PARTITION = (MAX_PARTITION==1) ? 1 : $clog2(MAX_PARTITION);


	localparam SCALAR_BANK_DEPTH	= BANK_DEPTH[MEM_TYPE_SCALAR];		//unit: word address (4 bytes)
	localparam SCALAR_BANK_AW 	= $clog2(SCALAR_BANK_DEPTH);
	localparam SCALAR_BANK_DW 	= XMEM_DW;

	localparam ARRAY_BANK_DEPTH	= BANK_DEPTH[MEM_TYPE_ARRAY];
	localparam ARRAY_BANK_AW 	= $clog2(ARRAY_BANK_DEPTH);
	localparam ARRAY_BANK_DW 	= XMEM_DW;

	localparam CYCLIC_BANK_DEPTH	= BANK_DEPTH[MEM_TYPE_CYCLIC];
	localparam CYCLIC_BANK_AW 	= $clog2(CYCLIC_BANK_DEPTH);
	localparam CYCLIC_BANK_DW 	= XMEM_DW*4;






	//===============================================================
	//Functions
	//===============================================================
	function logic[XMEM_AW-1:0] getRangeEnd;
		input [LOG2_MAX_PARTITION-1:0] 	    partIdx;
		input logic [XMEM_AW-1:0] 			rangeStart[MAX_PARTITION+1];
		begin
			getRangeEnd = rangeStart[partIdx+1]-1;
		end
	endfunction


    //===============================================================
    //Top/Left Pixel (XMEM1)
    //===============================================================
    localparam MAX_FWIDTH                 = 2048;
    localparam MAX_CTU                    = 64;
    function [31:0] top_pixel_addr(input [1:0] part, input [1:0] cidx, input [12:0] x0, input shift);
        return (part << 15) + (cidx * MAX_FWIDTH) + (x0 >> shift);
    endfunction
    function [31:0] left_pixel_addr(input [1:0] part, input [1:0] cidx, input [12:0] y0, input shift);
        return (part << 15) + (cidx * MAX_CTU) + ((y0 & (MAX_CTU - 1)) >> shift);
    endfunction
    function [31:0] topleft_pixel_addr(input [1:0] part, input [1:0] cidx, input [12:0] y0, input shift);
        return (part << 15) + (cidx * MAX_CTU) + ((y0 & (MAX_CTU - 1)) >> shift) + (MAX_CTU * 3) + 3;
    endfunction

endpackage
