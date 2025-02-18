`timescale 1ns / 1ps
/*
multi_we_sp_dist #(
	.NUM_COL(NUM_COL),
	.COL_WIDTH(COL_WIDTH),
	.ADDR_WIDTH(ADDR_WIDTH),
) instance_name (
	.clk(clk),
	.re(re),
	.we(we),
	.adr(adr),
	.wdat(wdat),
	.rdat(rdat)
);
*/
module multi_we_sp_dist #(
    parameter NUM_COL = 4,
    parameter COL_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = NUM_COL*COL_WIDTH
) (
    input clk,
    input re,
    input [COL_WIDTH/8-1:0]     we[NUM_COL],
    input [ADDR_WIDTH-1:0]      adr,
    input [COL_WIDTH-1:0]       wdat,
    output reg [COL_WIDTH-1:0]  rdat[NUM_COL]
);

    // Core Memory
    (* ram_style = "distributed" *)
    reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
    integer i, j;
    always @ (posedge clk) begin
        if(re) begin
            for(i=0;i<NUM_COL;i=i+1) begin
                rdat[i] <= ram_block[adr][i*COL_WIDTH +: COL_WIDTH];
            end
        end
        else begin
            for(i=0;i<NUM_COL;i=i+1) begin
                for(j=0;j<COL_WIDTH/8;j=j+1) begin
                    if(we[i][j]) begin
                        ram_block[adr][(i*COL_WIDTH + j*8) +: 8] <= wdat[j*8 +: 8];
                    end
                end
            end
        end
    end
endmodule

module multi_we_sp_bram #(
    parameter NUM_COL = 4,
    parameter COL_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = NUM_COL*COL_WIDTH
) (
    input                          clk,
    input                          re,
    input      [COL_WIDTH/8-1:0]   we[NUM_COL],
    input      [ADDR_WIDTH-1:0]    adr,
    input      [COL_WIDTH-1:0]     wdat,
    output reg [COL_WIDTH-1:0]     rdat[NUM_COL]
);
    // Core Memory
    reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
    integer i, j;
    always @ (posedge clk) begin
        if(re) begin
            for(i=0;i<NUM_COL;i=i+1) begin
                rdat[i] <= ram_block[adr][i*COL_WIDTH +: COL_WIDTH];
            end
        end
        else begin
            for(i=0;i<NUM_COL;i=i+1) begin
                for(j=0;j<COL_WIDTH/8;j=j+1) begin
                    if(we[i][j]) begin
                        ram_block[adr][(i*COL_WIDTH + j*8) +: 8] <= wdat[j*8 +: 8];
                    end
                end
            end
        end
    end
endmodule

module multi_we_sp_bram_v2 #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 8
) (
    input                          clk,
    input                          re,
    input      [DATA_WIDTH/8-1:0]  we,
    input      [ADDR_WIDTH-1:0]    adr,
    input      [DATA_WIDTH-1:0]    wdat,
    output reg [DATA_WIDTH-1:0]    rdat
);
    // Core Memory
    reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
    integer j;
    always @ (posedge clk) begin
        if(re) begin
            rdat <= ram_block[adr];
        end
        else begin
            for(j=0; j<DATA_WIDTH/8; j=j+1) begin
                if(we[j]) begin
                    ram_block[adr][j*8 +: 8] <= wdat[j*8 +: 8];
                end
            end
        end
    end
endmodule


module multi_we_dp_bram #(
    parameter NUM_COL = 4,
    parameter COL_WIDTH = 8,
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = NUM_COL*COL_WIDTH
) (
    input                          clk,
    input                          re,
    input      [COL_WIDTH/8-1:0]   we[NUM_COL],
    input      [ADDR_WIDTH-1:0]    rad,
    input      [ADDR_WIDTH-1:0]    wad,
    input      [COL_WIDTH-1:0]     wdat,
    output reg [COL_WIDTH-1:0]     rdat[NUM_COL]
);
    // Core Memory
    reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
    integer i, j;
    always @ (posedge clk) begin
        if(re) begin
            for(i=0;i<NUM_COL;i=i+1) begin
                rdat[i] <= ram_block[rad][i*COL_WIDTH +: COL_WIDTH];
            end
        end
        for(i=0;i<NUM_COL;i=i+1) begin
            for(j=0;j<COL_WIDTH/8;j=j+1) begin
                if(we[i][j]) begin
                    ram_block[wad][(i*COL_WIDTH + j*8) +: 8] <= wdat[j*8 +: 8];
                end
            end
        end
    end
endmodule


//testbench access of the i(th) way: inst_name.ram[0].dp_dist_inst.ram_block[i]);
module nway_dp_dist #(
    parameter N=2,
    parameter DATA_WIDTH=1,
    parameter ADDR_WIDTH=9,
    parameter RAM_TYPE = "distributed"
) (
  input clk,
  input [N-1:0] we,
  input re,
  input [ADDR_WIDTH-1:0] rad,
  input [ADDR_WIDTH-1:0] wad,
  input [DATA_WIDTH-1:0] wdat,
  output logic [DATA_WIDTH*N-1:0] rdat
);

  // Generate N instances of dp_dist
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin :ram
      dp_dist #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .RAM_TYPE(RAM_TYPE)
      ) dp_dist_inst (
        .clk(clk),
        .re(re),
        .we(we[i]),
        .rad(rad),
		.wad(wad),
        .wdat(wdat),
        .rdat(rdat[i*DATA_WIDTH +: DATA_WIDTH])
      );
    end
  endgenerate
endmodule

//testbench access of the i(th) way: inst_name.ram[0].sp_dist_inst.ram_block[i]);
module nway_sp_dist #(
    parameter N=2,
    parameter DATA_WIDTH=1,
    parameter ADDR_WIDTH=9,
    parameter RAM_TYPE = "distributed"
)(
    input clk,
    input [N-1:0] we,
    input re,
    input [ADDR_WIDTH-1:0] adr,
    input [DATA_WIDTH-1:0] wdat,
    output logic [DATA_WIDTH*N-1:0] rdat
);

  // Generate N instances of dp_dist
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin :ram
      sp_dist #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .RAM_TYPE(RAM_TYPE)
      ) sp_dist_inst (
        .clk(clk),
        .re(re),
        .we(we[i]),
        .adr(adr),
        .wdat(wdat),
        .rdat(rdat[i*DATA_WIDTH +: DATA_WIDTH])
      );
    end
  endgenerate
endmodule


module sp_dist #(
    parameter DATA_WIDTH = 1,
    parameter ADDR_WIDTH = 9,
    parameter RAM_TYPE = "distributed"
)(
    input clk, re, we,
    input[ADDR_WIDTH-1:0] adr,
    input [DATA_WIDTH-1:0] wdat,
    output logic [DATA_WIDTH-1:0] rdat
);
    (* ram_style = RAM_TYPE *)
    reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
	//initial begin
	//	rdat=0;
	//end
	always @ (posedge clk) begin
		if(re) begin
			rdat <= ram_block[adr];
		end
		else if(we) begin
			ram_block[adr]<= wdat;
		end
	end
endmodule


module dp_dist #(
    parameter DATA_WIDTH = 1,
    parameter ADDR_WIDTH = 9,
    parameter RAM_TYPE = "distributed"
)(
    input clk, re, we,
    input[ADDR_WIDTH-1:0] rad, wad,
    input [DATA_WIDTH-1:0] wdat,
    output logic [DATA_WIDTH-1:0] rdat
);
    (* ram_style = RAM_TYPE *)
    reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
	always @ (posedge clk) begin
		if(re) begin
			rdat <= ram_block[rad];
		end
		if(we) begin
			ram_block[wad]<= wdat;
		end
	end
endmodule


module multi_we_sp_bram_single_wdat
#( 	parameter NUM_COL = 4,
	parameter COL_WIDTH = 8,
	parameter ADDR_WIDTH = 10,
	parameter DATA_WIDTH = NUM_COL*COL_WIDTH ) (
	input clk,
	input re,
	input [NUM_COL-1:0] we,
	input [ADDR_WIDTH-1:0] adr,
	input [DATA_WIDTH-1:0] wdat,
	output reg [DATA_WIDTH-1:0] dout );
// Core Memory
reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];
integer i;
always @ (posedge clk) begin
	if(re) begin
		dout <= ram_block[adr];
	end
	else if(we) begin
		for(i=0;i<NUM_COL;i=i+1) begin
			if(we[i]) begin
				ram_block[adr][i*COL_WIDTH +: COL_WIDTH] <= wdat[i*COL_WIDTH +: COL_WIDTH];
			end
		end
	end
end
endmodule


module multi_we_tp_bram
#( 	parameter NUM_COL = 2,
	parameter COL_WIDTH = 1,
	parameter ADDR_WIDTH = 9,
	parameter DATA_WIDTH = NUM_COL*COL_WIDTH // Data Width in bits
	) (

input clk,
input enaA,
input [NUM_COL-1:0] weA,
input [ADDR_WIDTH-1:0] adrA,
input [DATA_WIDTH-1:0] dinA,
output reg [DATA_WIDTH-1:0] doutA,

input enaB,
input [NUM_COL-1:0] weB,
input [ADDR_WIDTH-1:0] adrB,
input [DATA_WIDTH-1:0] dinB,
output reg [DATA_WIDTH-1:0] doutB
);


// Core Memory
(* ram_style = "distributed" *)
reg [DATA_WIDTH-1:0] ram_block [(2**ADDR_WIDTH)-1:0];

integer i;
// Port-A Operation
always @ (posedge clk) begin
	if(enaA) begin
		for(i=0;i<NUM_COL;i=i+1) begin
			if(weA[i]) begin
				ram_block[adrA][i*COL_WIDTH +: COL_WIDTH] <= dinA[i*COL_WIDTH +: COL_WIDTH];
			end
		end
		doutA <= ram_block[adrA];
	end
end

// Port-B Operation:
always @ (posedge clk) begin
	if(enaB) begin
	for(i=0;i<NUM_COL;i=i+1) begin
		if(weB[i]) begin
			ram_block[adrB][i*COL_WIDTH +: COL_WIDTH] <= dinB[i*COL_WIDTH +: COL_WIDTH];
		end
	end
	doutB <= ram_block[adrB];
end
end

endmodule // bytewrite_tdp_ram_rf
