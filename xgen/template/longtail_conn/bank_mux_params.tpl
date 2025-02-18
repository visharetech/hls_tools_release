localparam logic [31:0] BANK_NUM[MEM_TYPE_MAX] = '{
	${func_bank_num}
};

localparam logic [31:0] BANK_DEPTH[MEM_TYPE_MAX] = '{
	${func_bank_depth}
};

localparam logic [31:0] MAX_PARTITION = ${max_partition};

localparam logic [31:0] SCALAR_BANK_MUX_NUM[BANK_NUM[MEM_TYPE_SCALAR]][DUAL_PORT]	= '{
	${func_scalar_bank_mux_num}
};

localparam logic [31:0] SCALAR_MAX_MUX_NUM = ${func_scalar_max_mux_num};

localparam logic [31:0] ARRAY_BANK_MUX_NUM[BANK_NUM[MEM_TYPE_ARRAY]] = '{
	${func_array_bank_mux_num}
};

localparam logic [31:0] ARRAY_MAX_MUX_NUM = ${func_array_max_mux_num};

localparam logic [31:0] CYCLIC_BANK_MUX_NUM[BANK_NUM[MEM_TYPE_CYCLIC]] = '{
    ${func_cyclic_bank_mux_num}
};

localparam logic [31:0] CYCLIC_MAX_MUX_NUM = ${func_cyclic_max_mux_num};

