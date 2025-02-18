
//`include "vcap.vh"

/*

	cyclic_bank = wideMem

*/

`timescale 1ns/1ps

module cyclic_bank #(ADDR_WIDTH=11, DATA_WIDTH=32)(
	input rstn, clk,
	input re, we,
	input [1:0] len,
	input [ADDR_WIDTH-1:0] wordAdr,
//	input [DATA_WIDTH-1:0] din[4],
//	output logic [DATA_WIDTH-1:0] dout[4]
	input [3:0][DATA_WIDTH-1:0] din,
	output logic [3:0][DATA_WIDTH-1:0] dout
);
// assume address is word-aligned; don't not support half-word or byte access

/*
memory layout1
mem0	mem1
0:e		1:e
2:e		3:e
4		5:o
6:o		7:o
8:o		9
*/

reg [ADDR_WIDTH-1:0] wordAdr_r;
logic [ADDR_WIDTH-2:0] mem0_adr, mem1_adr;
logic [DATA_WIDTH-1:0] din00, din01, din10, din11;
logic we00, we01, we10, we11;
wire [DATA_WIDTH-1:0] dout00, dout01, dout10, dout11;

cyclic_dpram #(.DATA_WIDTH(32), .ADDR_WIDTH(ADDR_WIDTH-1) )  mem0(clk, we00, we01, re, mem0_adr, din00, din01, dout00, dout01);
cyclic_dpram #(.DATA_WIDTH(32), .ADDR_WIDTH(ADDR_WIDTH-1) )  mem1(clk, we10, we11, re, mem1_adr, din10, din11, dout10, dout11);

/*
always @ (*) begin
	{we11, we01, we10, we00} = 0;

	if(wordAdr[0]==0) begin //# even address
		mem0_adr=wordAdr/2;
		mem1_adr=wordAdr/2;
//		{din11, din01, din10, din00} <= {din[3], din[2], din[1], din[0]} ;
		{din11, din01, din10, din00} = {din[3], din[2], din[1], din[0]} ;
		if(we) begin
			we00=1;
			if(len>=1) we10=1;
			if(len>=2) we01=1;
			if(len==3) we11=1;
		end
	end
	else begin 				//# odd address
		mem1_adr=wordAdr/2;
		mem0_adr=wordAdr/2 + 1 ;
//		{din01, din11, din00, din10} <= {din[3], din[2], din[1], din[0]} ;
		{din01, din11, din00, din10} = {din[3], din[2], din[1], din[0]} ;
		if(we) begin
			we10=1;
			if(len>=1) we00=1;
			if(len>=2) we11=1;
			if(len==3) we01=1;
		end
	end


	if(wordAdr_r[0]==0) begin //# even address
		{dout[0], dout[1], dout[2], dout[3]} = {dout00, dout10, dout01, dout11};
	end
	else begin 					//# odd address
		{dout[0], dout[1], dout[2], dout[3]} = {dout10, dout00, dout11, dout01};
	end
end
*/


always @ (*) begin
	{we11, we01, we10, we00} = 0;

	if(we) begin
	   case({wordAdr[0], len})
        //------------------------------------------------------      	   
       'b000: begin we00=1;                         end 
       'b001: begin we00=1; we10=1;                 end 
       'b010: begin we00=1; we10=1; we01=1;         end 
       'b011: begin we00=1; we10=1; we01=1; we11=1; end 
       
        //------------------------------------------------------      	   
       'b100: begin we10=1;                         end 
       'b101: begin we10=1; we00=1;                 end 
       'b110: begin we10=1; we00=1; we11=1;         end 
       'b111: begin we10=1; we00=1; we11=1; we01=1; end 
	   endcase
    end 
    
	if(wordAdr[0]==0) begin //# even address
		mem0_adr=wordAdr/2;
		mem1_adr=wordAdr/2;
		{din11, din01, din10, din00} = {din[3], din[2], din[1], din[0]} ;
	end
	else begin 				//# odd address
		mem1_adr=wordAdr/2;
		mem0_adr=wordAdr/2 + 1 ;
		{din01, din11, din00, din10} = {din[3], din[2], din[1], din[0]} ;
	end


	if(wordAdr_r[0]==0) begin //# even address
		{dout[0], dout[1], dout[2], dout[3]} = {dout00, dout10, dout01, dout11};
	end
	else begin 					//# odd address
		{dout[0], dout[1], dout[2], dout[3]} = {dout10, dout00, dout11, dout01};
	end
end


always @ (posedge clk or negedge rstn) begin
	if(~rstn) wordAdr_r<=0;
	else wordAdr_r<=wordAdr;
end

endmodule

module cyclic_dpram #(DATA_WIDTH = 32,  ADDR_WIDTH = 9, usr_ram_style="auto" ) (
  input                  clk,
  input                  we0, we1, re,
  input  [ADDR_WIDTH-1:0] adr,
  input  [DATA_WIDTH-1:0] din0,din1,
  output reg [DATA_WIDTH-1:0] dout0, dout1 );
// ram_style: auto | block | distributed
(* ram_style = usr_ram_style *)	reg [DATA_WIDTH-1:0] ram[(1 << ADDR_WIDTH)-1:0];



logic [7:0] b0;
logic [7:0] b1;
logic [7:0] b2;
logic [7:0] b3;
logic [31:0] data = 0;


/*initial begin
	for (int i=0; i<(1 << ADDR_WIDTH); i++) begin
		b0 = data++;
		b1 = data++;
		b2 = data++;
		b3 = data++;
		ram[i] = {b3, b2, b1, b0} ;
	end
end*/



/*
initial begin
	for(int i=0; i<(1<<ADDR_WIDTH); i++) begin
		ram[i]=i;
	end
end
*/
always @(posedge clk) begin
	if(we0)		ram[adr] <= din0;
	//if(we1) 	ram[adr+1] <= din1;

	if(re) begin
		dout0 <= ram[adr];
		//dout1 <= ram[adr+1];
	end
end

always @(posedge clk) begin
	if(we1) 	ram[adr+1] <= din1;
	if(re) begin
		dout1 <= ram[adr+1];
	end
end

endmodule


//inserting the following before other code: gen_rstn_clk tb(rstn, clk);
module gen_rstn_clk(output logic rstn, clk);
	initial begin
		rstn = 0;
		#6
		rstn = 1;
	end

	initial begin
		clk = 1;
		forever #5 clk = ~clk;
	end

	always @(negedge clk) begin
		$display("rstn=%d at %d", rstn, $time);
	end
endmodule


module test;
gen_rstn_clk tb(rstn, clk);

parameter ADR=10;
parameter DATA=32;
reg [ADR-1:0] wordAdr;
reg re, we;
reg [1:0] len;
reg [DATA-1:0] din[4];
wire logic [DATA-1:0] dout[4];

wideMem #(.ADDR_WIDTH(ADR), .DATA_WIDTH(DATA) ) wmem(rstn, clk, re, we, len, wordAdr, din, dout);

initial begin
	we=0; re=0; len=0;
	#15;
	we=0;
	wordAdr=3; re=1;
	#10
	//`capture4(dout[0], dout[1], dout[2], dout[3]);
	$display("write 10~13 at 3");
	we=1; re=0; len=3;
	din[0]=10; din[1]=11; din[2]=12; din[3]=13;
	#10
	wordAdr=3; re=1; we=0;
	#10
	//`capture4(dout[0], dout[1], dout[2], dout[3]);
	$finish;

end

endmodule
