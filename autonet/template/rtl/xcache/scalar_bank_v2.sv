

/*
	scalar_bank = dual_port_bank

*/
`timescale 1ns/1ps

//
module scalar_bank_v2 import xcache_param_pkg::*; #(AW=10, BYTE_AW=12, DW=32) (
input clk,
input re0, re1,
input we0, we1,
input [1:0] len0, len1,
input [BYTE_AW-1:0] adr0, adr1,
input [DW-1:0] din0, din1,
output logic [DW-1:0] dout0, dout1,
output logic 		  dout0_vld, dout1_vld

);


//--------------------------------------------
//parameters 
//--------------------------------------------
logic [3:0] bank_we0, bank_we1;
logic [DW-1:0] bank_din0, bank_din1;
wire  [DW-1:0] bank_dout0, bank_dout1;
logic [1:0] len0_r, len1_r;
logic [1:0] adr0_r, adr1_r;
logic [AW-1:0] adr0_w, adr1_w;

always @ (posedge clk) begin
	len0_r <= len0;
	len1_r <= len1;
	adr0_r <= adr0;
	adr1_r <= adr1;
	
	dout0_vld <= re0;
	dout1_vld <= re1;
end

always @ (*) begin
	bank_we0 = getWriteMask(we0, adr0[1:0], len0);
	bank_we1 = getWriteMask(we1, adr1[1:0], len1);
	bank_din0 = shiftData_wr(len0, adr0[1:0], din0);
	bank_din1 = shiftData_wr(len1, adr1[1:0], din1);

	//dout0 = shiftData(len0, adr0[1:0], bank_dout0);
	//dout1 = shiftData(len1, adr1[1:0], bank_dout1);

	dout0 = shiftData_rd(adr0_r[1:0], bank_dout0);
	dout1 = shiftData_rd(adr1_r[1:0], bank_dout1);

    adr0_w = adr0[BYTE_AW-1:2];// >> 2;
    adr1_w = adr1[BYTE_AW-1:2];// >> 2;
end

multi_we_mem_dp #(
    .DEPTH(1<<AW),
    .DBITS(32),
    .BANK(4),
    .ABITS(AW)
) inst_multi_we_mem_dp (
    .clk(clk),
    .ce0(1'b1),
    .ce1(1'b1),
    .we0(bank_we0),
    .we1(bank_we1),
    .address0(adr0_w[AW-1:0]),
    .address1(adr1_w[AW-1:0]),
    .d0(bank_din0),
    .d1(bank_din1),
    .q0(bank_dout0),
    .q1(bank_dout1)
);


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



module multi_we_mem_dp # (
    parameter DEPTH = 16,
    parameter DBITS = 32,
    parameter BANK  = 4,
    parameter ABITS = $clog2(DEPTH)
)
(
    input                        clk,
    input                        ce0,
    input                        ce1,
    input        [BANK  - 1 : 0] we0,
    input        [BANK  - 1 : 0] we1,
    input        [ABITS - 1 : 0] address0,
    input        [ABITS - 1 : 0] address1,
    input        [DBITS - 1 : 0] d0,
    input        [DBITS - 1 : 0] d1,
    output logic [DBITS - 1 : 0] q0,
    output logic [DBITS - 1 : 0] q1
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

//	mem = '{default: '0} ;
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
    always @ (posedge clk) begin
        if (ce1) begin
            if (we1[i]) begin
                mem[address1][(i + 1) * BANK_BITS - 1 : i * BANK_BITS] <= d1[(i + 1) * BANK_BITS - 1 : i * BANK_BITS];
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
always @ (posedge clk) begin
    if (ce1) begin
        q1 <= mem[address1];
    end
end

endmodule
