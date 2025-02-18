`timescale 1ns / 1ps
// in each cycle, the dual ported version can read N-way data and/or write any one of the way.
module nway_sp_bram #(N=4, WIDTH=18, DEPTH=512)
(
	input 							clk,
// input /*[N-1:0]*/we[N],
 	input 	[N-1:0]				we/*[N]*/,
 	// input 							re,
	input 	[$clog2(DEPTH)-1:0] 	adr,
	input 	[WIDTH-1:0] 			wdat /*[N]*/,
	output 	[WIDTH-1:0] 			rdat[N]);


genvar i;
generate for (i = 0; i<N; i=i+1) begin
	  sp_bram #(WIDTH, DEPTH) mem_array(clk, we[i], adr, wdat/*[i]*/, rdat[i]);
end
endgenerate

endmodule



module sp_bram #(WIDTH=18, DEPTH=512)
(input clk,
input we,
input [$clog2(DEPTH)-1:0] adr,
input [WIDTH-1:0] wdat,
output reg [WIDTH-1:0] rdat);



(* ram_style = "distributed" *)reg [WIDTH-1:0] mem[DEPTH] ;//= '{WIDTH{DEPTH{0}}};
//initial
//begin
//	// for(int i=0;i<N;i++)
//		for(int j=0;j<DEPTH;j++)
//			mem[j] = '0;
//end

// always_ff @ (posedge clk) begin
always @(posedge clk) begin
	if(we) mem[adr] <=wdat;
	else rdat <= mem[adr];
end

endmodule

module sp_bram_no_reg #(WIDTH=18, DEPTH=512)
(input clk,
input we,
input [$clog2(DEPTH)-1:0] adr,
input [WIDTH-1:0] wdat,
output reg [WIDTH-1:0] rdat);



(* ram_style = "distributed" *)reg [WIDTH-1:0] mem[DEPTH] ;//= '{WIDTH{DEPTH{0}}};
//initial
//begin
//	// for(int i=0;i<N;i++)
//		for(int j=0;j<DEPTH;j++)
//			mem[j] = '0;
//end

// always_ff @ (posedge clk) begin
always @(posedge clk) begin
	if(we) mem[adr] <=wdat;
end
assign 	rdat = mem[adr];

endmodule


// in each cycle, the dual ported version can read N-way data and/or write any one of the way.
module nway_dp_bram #(N=4, WIDTH=18, DEPTH=32)
(
input clk,
input [N-1:0]we/*[N]*/,
input [$clog2(DEPTH)-1:0] wad, rad,
input [WIDTH-1:0] wdat,
output [WIDTH-1:0] rdat[N]);

 genvar i;
generate for ( i = 0; i<N; i=i+1) begin
      dp_bram #(WIDTH, DEPTH) mem_array(clk, we[i], rad, wad, wdat, rdat[i]);
end endgenerate

endmodule

module dp_bram #(WIDTH=18, DEPTH=512)
(input clk,
input we,
input [$clog2(DEPTH)-1:0] rad, wad,
input [WIDTH-1:0] wdat,
output reg [WIDTH-1:0] rdat);

(* ram_style = "block" *)reg [WIDTH-1:0] mem[DEPTH];
//initial
//begin
//    // for(int i=0;i<N;i++)
//        for(int j=0;j<DEPTH;j++)
//            mem[j] = '0;
//
//end

always/*_ff*/ @ (posedge clk) begin
    if(we) mem[wad] <= wdat;
    rdat            <= mem[rad];
end

endmodule


// module dp_bram#(parameter DW = 32, parameter AW = 5) (
//     input clk,
//     input [AW-1:0] ad0, ad1, output reg [DW-1:0] rdat0_r, rdat1_r,
//     input we, input [DW-1:0] wdat);
// (* ram_style ="block" *) reg [DW-1:0] mem [0:(1<<AW)-1];
//     always @(posedge clk) begin
//         if (we) begin
//             mem[ad0] <= wdat;
//         end
//         else begin
//             rdat0_r <= mem[ad0];
//             rdat1_r <= mem[ad1];
//         end
//     end
// endmodule



// // in each cycle, the dual ported version can read N-way data and/or write any one of the way.
// module nway_dp_bram #(N=4, WIDTH=18, DEPTH=32)
// (
// input clk,
// input [N-1:0]we/*[N]*/,
// input [$clog2(DEPTH)-1:0] wad, rad,
// input [WIDTH-1:0] wdat,
// output [WIDTH-1:0] rdat[N]);

//  genvar i;
// generate for ( i = 0; i<N; i=i+1) begin
//       dp_bram #(WIDTH, DEPTH) mem_array(clk, we[i], rad, wad, wdat, rdat[i]);
// end endgenerate

// endmodule