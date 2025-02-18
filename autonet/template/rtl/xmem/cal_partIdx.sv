

module cal_partIdx import xmem_param_pkg::*;
(
	input [XMEM_AW-1:0]							adr, 				//global address from RISCV
	//From Risc
	input [LOG2_MAX_PARTITION:0]				partNum,
	input [XMEM_AW-1:0]							rangeStart 			[MAX_PARTITION+1],
	output logic [LOG2_MAX_PARTITION-1:0]	    partIdx
);

//--------------------------------------------------
//Logic
//--------------------------------------------------
always_comb begin
	for (int p=partNum-1; p>=0; p--) begin
		if(adr<(getRangeEnd(p, rangeStart)+1)) 	partIdx=p;
		else 						break;
	end
end


endmodule