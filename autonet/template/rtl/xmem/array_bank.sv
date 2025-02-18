
/*
	array_bank = single_port_bank

*/

`timescale 1ns/1ps

module array_bank import xmem_param_pkg::*;  #(AW=10, DW=32) (
	input                   clk,
	input 					we0,
	input [1:0] 			len0,
	input [XMEM_AW-1:0]		adr0,
	input [DW-1:0]			din0,
	output logic [DW-1:0]	dout0
);

localparam WR_MEM = 1;
localparam RD_MEM = 0;

logic [3:0] 	bank_we0;
logic [DW-1:0]	bank_din0;
wire  [DW-1:0]	bank_dout0;

logic [1:0] 	len0_r;
logic [1:0] 	adr0_r;
logic [XMEM_AW-1:0]		adr0_w;

always @ (posedge clk) begin
	len0_r <= len0;
	adr0_r <= adr0;
end

always @ (*) begin
	bank_we0 	= getWriteMask	(we0,  adr0[1:0], len0);
	bank_din0	= shiftData_wr(len0, adr0[1:0], din0);
	dout0		= shiftData_rd(adr0_r[1:0], bank_dout0);
    adr0_w = adr0[XMEM_AW-1:2];//>>2;
end

multi_we_mem_sp #(
    .DEPTH(1<<AW),
    .DBITS(32),
    .BANK(4),
    .ABITS(AW)
) inst_multi_we_mem_sp (
    .clk		( clk			),
    .ce0		( 1'b1			),
    .we0		( bank_we0		),
    .address0	( adr0_w[AW-1:0]),
    .d0			( bank_din0		),
    .q0			( bank_dout0	)
);

/*
function [31:0] shiftData;
	input [1:0] len;
	input [1:0] adr;
	input [31:0] word;
	if(len==3) 			shiftData=word;
	else if (len==1) 	shiftData=word[15:0]<<(adr[1]*16);
	else 				shiftData=word[7:0]<<(adr[1:0]*8);
endfunction
*/

/*function [31:0] shiftData;
	input [1:0] len;
	input [1:0] adr;
	input [31:0] word;
	if(len==3) 			shiftData=word;
	else if (len==1) 	shiftData[15:0]=word>>(adr[1]*16);
	else 				shiftData[7:0] =word>>(adr[1:0]*8);
endfunction*/

function [31:0] shiftData_wr;
	input [1:0] len;
	input [1:0] adr;
	input [31:0] word;
    /*case (adr[1:0])
        2'd1: shiftData_wr = {word[23:0],  word[7:0]};
        2'd2: shiftData_wr = {word[15:0], word[31:16]};
        2'd3: shiftData_wr = {word[7:0], word[23:0]};
        default: shiftData_wr = word;
    endcase*/
    case (adr[1:0])
        2'd1: shiftData_wr = {word[23:0],  8'b0};
        2'd2: shiftData_wr = {word[15:0], 16'b0};
        2'd3: shiftData_wr = {word[7:0], 24'b0};
        default: shiftData_wr = word;
    endcase
endfunction

function [31:0] shiftData_rd;
	input [1:0] adr;
	input [31:0] word;
	//shiftData_rd = word >> (adr[1:0]*8);
    case (adr[1:0])
        2'd1: shiftData_rd = {8'b0, word[31:8]};
        2'd2: shiftData_rd = {16'b0, word[31:16]};
        2'd3: shiftData_rd = {24'b0, word[31:24]};
        default: shiftData_rd = word;
    endcase
endfunction



function [3:0] getWriteMask;
	input we;
	input [1:0] byteAdr;
	input [1:0] len;
	if(we==0) 			getWriteMask=0;
	else begin
		if(len==3) 		getWriteMask=4'b1111;
		else if(len==1) getWriteMask= byteAdr[1] ? 4'b1100 : 4'b0011;
		else 			getWriteMask= 1<<byteAdr[1:0];
	end
endfunction

endmodule



module multi_we_mem_sp # (
    parameter DEPTH = 16,
    parameter DBITS = 32,
    parameter BANK  = 4,
    parameter ABITS = $clog2(DEPTH)
)
(
    input                        clk,
    input                        ce0,
    input        [BANK  - 1 : 0] we0,
    input        [ABITS - 1 : 0] address0,
    input        [DBITS - 1 : 0] d0,
    output logic [DBITS - 1 : 0] q0
);

localparam BANK_BITS = DBITS / BANK;

logic [DBITS - 1 : 0] mem[DEPTH];

logic [7:0] b0;
logic [7:0] b1;
logic [7:0] b2;
logic [7:0] b3;
logic [31:0] data = 0;


/*initial begin

	for (int i=0; i<DEPTH; i++) begin
		b0 = data++;
		b1 = data++;
		b2 = data++;
		b3 = data++;
		mem[i] = {b3, b2, b1, b0} ;
	end

	//mem = '{default: '0} ;

end*/

generate
for (genvar i = 0; i < BANK; i = i + 1) begin : INST_BANK
    always @ (posedge clk) begin
        if (ce0) begin
            if (we0[i]) begin
                mem[address0][(i + 1) * BANK_BITS - 1 : i * BANK_BITS] <= d0[(i + 1) * BANK_BITS - 1 : i * BANK_BITS];
            end
        end
    end
end
endgenerate

always @ (posedge clk) begin
    if (ce0) begin
        q0 <= mem[address0];
    end
end

endmodule
