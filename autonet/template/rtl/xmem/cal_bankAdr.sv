

module cal_bankAdr import xmem_param_pkg::*; #(
	parameter string RANGE_TYPE 		= "SCALAR",
	parameter BANK_ADR_WIDTH 			= 32
)
(
	input [XMEM_AW-1:0]					adr, 				//global address
	input [LOG2_MAX_PARTITION-1:0]	    partIdx,
	//From Risc
//	input [XMEM_AW-1:0]					rangeStart 			[MAX_PARTITION],
	input [XMEM_AW-1:0]					subRangeStart		[MAX_PARTITION],
	input [XMEM_AW-1:0]					subBankStart	    [MAX_PARTITION],
	input [XMEM_AW-1:0]					subBankSize	[MAX_PARTITION],
	//result:
	output logic [XMEM_AW-1:0]	        bankAdr
);

//--------------------------------------------------
//Singals
//--------------------------------------------------
logic [XMEM_AW-1:0]						_subRangeStart;
logic [XMEM_AW-1:0]						_subBankStart;
logic [XMEM_AW-1:0]						_subBankSize;
//logic [XMEM_AW-1:0]						partAdr;
logic [XMEM_AW-1:0]						bankAdr_tmp;

//--------------------------------------------------
//Logic
//--------------------------------------------------
always_comb begin

	//partAdr = adr - rangeStart[partIdx];
    _subBankStart 	= subBankStart[partIdx];

	if (RANGE_TYPE == "SCALAR") begin
		bankAdr_tmp = (((adr >> 2) / BANK_NUM[MEM_TYPE_SCALAR]) << 2) + (adr & 3) + _subBankStart;
	end
	else if (RANGE_TYPE == "ARRAY" || RANGE_TYPE == "CYCLIC") begin
		_subRangeStart 	= subRangeStart[partIdx];
		_subBankSize 	= subBankSize[partIdx];
		//bankAdr 		= ((adr - _subRangeStart) % _subBankSize) + _subBankStart;
		bankAdr_tmp 		= ((adr - _subRangeStart) & (_subBankSize - 1)) + _subBankStart;
	end
    bankAdr = bankAdr_tmp;//[BANK_ADR_WIDTH-1:0];
end

endmodule