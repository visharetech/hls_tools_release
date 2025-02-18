

module bank_filter import xmem_param_pkg::*;
(
	input [XMEM_PART_AW-1:0]	        adr, 				//global address from RISCV
	input [LOG2_MAX_PARTITION-1:0]	    partIdx,
    input                               risc_cmd_en,
	//From Risc
	input [XMEM_AW-1:0]					rangeStart 			[MAX_PARTITION],
	input [XMEM_AW-1:0]					subRangeStart		[MAX_PARTITION][2],
	input [XMEM_AW-1:0]					subBankSize			[MAX_PARTITION][MEM_TYPE_MAX],
	//
    output logic [XMEM_AW-1:0]          adr_o,
	output logic 						matched_scalar[BANK_NUM[MEM_TYPE_SCALAR]],
	output logic 						matched_array[BANK_NUM[MEM_TYPE_ARRAY]],
	output logic 						matched_cyclic[BANK_NUM[MEM_TYPE_CYCLIC]]
);

    logic [XMEM_AW-1:0]                 bank;
    logic [XMEM_AW-1:0]                 partAdr;
    logic [XMEM_AW-1:0]					_subRangeStart;
    logic [XMEM_AW-1:0]					_subBankSize;
    logic                               arr_cyc_sel;

    always_comb begin
        partAdr = adr;// - rangeStart[partIdx];
        adr_o = adr; //+ rangeStart[partIdx];
        bank = 0;
        matched_scalar = '{default: 0};
        matched_array = '{default: 0};
        matched_cyclic = '{default: 0};
        _subRangeStart = 0;
        _subBankSize = 0;
        arr_cyc_sel = 0;
        if (partAdr<subRangeStart[partIdx][MEM_TYPE_ARRAY-1] && !risc_cmd_en) begin
            bank = (partAdr >> 2) % BANK_NUM[MEM_TYPE_SCALAR];
            matched_scalar[bank] = 1;
        end
        else if (!risc_cmd_en) begin
            if (partAdr<subRangeStart[partIdx][MEM_TYPE_CYCLIC-1]) begin
                _subRangeStart 	= subRangeStart[partIdx][MEM_TYPE_ARRAY-1];
                _subBankSize 	= subBankSize[partIdx][MEM_TYPE_ARRAY];
            end
            else begin
                _subRangeStart 	= subRangeStart[partIdx][MEM_TYPE_CYCLIC-1];
                _subBankSize 	= subBankSize[partIdx][MEM_TYPE_CYCLIC];
                arr_cyc_sel = 1;
            end
            //bank = ((partAdr - _subRangeStart) / _subBankSize);
            bank = div_subBankSize(partAdr - _subRangeStart, _subBankSize);

            if (!arr_cyc_sel) begin
                matched_array[bank] = 1;
            end
            else begin
                matched_cyclic[bank] = 1;
            end
        end
    end

    function logic [XMEM_AW-1:0] div_subBankSize(input [XMEM_AW-1:0] val, input [XMEM_AW-1:0] sbBankDepth);
        div_subBankSize = -1;
        for (int i=0; i<XMEM_AW; i++) begin
            if (sbBankDepth[i]) begin
                div_subBankSize = val >> i;
                break;
            end
        end
    endfunction

endmodule