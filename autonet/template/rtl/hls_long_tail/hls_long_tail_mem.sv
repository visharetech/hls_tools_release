module hls_long_tail_mem_sp # (
    parameter DEPTH = 16,
    parameter DBITS = 32,
    parameter ABITS = $clog2(DEPTH)
)
(
    input                        clk,
    input                        ce0,
    input                        we0,
    input        [ABITS - 1 : 0] address0,
    input        [DBITS - 1 : 0] d0,
    output logic [DBITS - 1 : 0] q0
);

logic [DBITS - 1 : 0] mem[DEPTH];
always @ (posedge clk) begin
    if (ce0) begin
        if (we0) mem[address0] <= d0;
        q0 <= mem[address0];
    end
end

endmodule


module hls_long_tail_mem_dp # (
    parameter DEPTH = 16,
    parameter DBITS = 32,
    parameter ABITS = $clog2(DEPTH)
)
(
    input                        clk,
    input                        ce0,
    input                        ce1,
    input                        we0,
    input                        we1,
    input        [ABITS - 1 : 0] address0,
    input        [ABITS - 1 : 0] address1,
    input        [DBITS - 1 : 0] d0,
    input        [DBITS - 1 : 0] d1,
    output logic [DBITS - 1 : 0] q0,
    output logic [DBITS - 1 : 0] q1
);

logic [DBITS - 1 : 0] mem[DEPTH];
always @ (posedge clk) begin
    if (ce0) begin
        if (we0) mem[address0] <= d0;
        q0 <= mem[address0];
    end
end
always @ (posedge clk) begin
    if (ce1) begin
        if (we1) mem[address1] <= d1;
        q1 <= mem[address1];
    end
end

endmodule


module hls_long_tail_multi_we_mem_sp # (
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


module hls_long_tail_multi_we_mem_dp # (
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


module hls_long_tail_array_partition_mem_dp # (
    parameter DEPTH = 16,
    parameter DBITS = 32,
    parameter BANK  = 4,
    parameter ABITS = $clog2(DEPTH)
)
(
    input                        clk,
    input                        ce0[BANK],
    input                        ce1[BANK],
    input                        we0[BANK],
    input                        we1[BANK],
    input        [ABITS - 1 : 0] address0[BANK],
    input        [ABITS - 1 : 0] address1[BANK],
    input        [DBITS - 1 : 0] d0[BANK],
    input        [DBITS - 1 : 0] d1[BANK],
    output logic [DBITS - 1 : 0] q0[BANK],
    output logic [DBITS - 1 : 0] q1[BANK]
);

localparam BANK_BITS = DBITS / BANK;

logic [DBITS - 1 : 0] mem[DEPTH];

generate
for (genvar i = 0; i < BANK; i = i + 1) begin : INST_BANK
    always @ (posedge clk) begin
        if (ce0[i]) begin
            if (we0[i]) begin
                mem[address0[i]] <= d0[i];
            end
        end
    end
    always @ (posedge clk) begin
        if (ce1[i]) begin
            if (we1[i]) begin
                mem[address1[i]] <= d1[i];
            end
        end
    end

    always @ (posedge clk) begin
        if (ce0[i]) begin
            q0[i] <= mem[address0[i]];
        end
    end
    always @ (posedge clk) begin
        if (ce1[i]) begin
            q1[i] <= mem[address1[i]];
        end
    end
end
endgenerate


endmodule





module hls_long_tail_multi_we_mem_dp_latency3 # (
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

logic [DBITS - 1 : 0] q0_r;
logic [DBITS - 1 : 0] q0_2r;
logic [DBITS - 1 : 0] q1_r;
logic [DBITS - 1 : 0] q1_2r;




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
        q0_r <= mem[address0];
    end
	q0_2r <= q0_r;
	q0 	  <= q0_2r;
end
always @ (posedge clk) begin
    if (ce1) begin
        q1_r <= mem[address1];
    end
	q1_2r <= q1_r;
	q1 	  <= q1_2r;
end

endmodule







module hls_long_tail_multi_we_mem_dp_dist #(
    parameter BANK  = 4,
    parameter DEPTH = 16,
    parameter DBITS = 32,
    parameter ABITS = $clog2(DEPTH)
)
(
    input                        clk,
	input 						 ce0,
	input 						 ce1,	
    input        [BANK  - 1 : 0] we0,
    input        [ABITS - 1 : 0] address0,
    input        [ABITS - 1 : 0] address1,	
    input        [DBITS - 1 : 0] d0,
    output logic [DBITS - 1 : 0] q0,
    output logic [DBITS - 1 : 0] q1
);
	
	localparam BANK_DBIT = DBITS/BANK;
	
	generate 
		for (genvar i=0; i<BANK; i++) begin: BANKS
			ram_sp_dist # (
				.DEPTH 	( DEPTH		),
				.DBITS	( BANK_DBIT	)
			)
			inst_ram_sp_dist(
						.clk		( clk									),
						.ce0		( ce0									),
						.ce1		( ce1									),
						.address0	( address0								),
						.address1	( address1								),
						.d0			( d0		[i*BANK_DBIT+:BANK_DBIT]	),
						.we0		( we0		[i]							),
						.q0			( q0 		[i*BANK_DBIT+:BANK_DBIT]	),
						.q1			( q1 		[i*BANK_DBIT+:BANK_DBIT]	)
			);
		end 
	endgenerate 
	
endmodule 


module ram_sp_dist #(
	parameter DEPTH = 16,
	parameter DBITS = 8,
	parameter ABITS = $clog2(DEPTH)
)
(
    input					clk,
	input 					ce0,
	input 					ce1,
    input [ABITS-1:0] 		address0,
    input [ABITS-1:0] 		address1,
    input [DBITS-1:0] 		d0,
    input 	        		we0,
    output reg [DBITS-1:0]	q0,
    output reg [DBITS-1:0]	q1
	
	
);

    (* ram_style = "distributed" *)    
    reg [7:0] mem [DEPTH];

    always @(posedge clk) begin
        if (we0) begin
            mem[address0] <= d0;
        end
    end
	
    always @(posedge clk) begin
		if (ce0) begin 
			q0 <= mem[address0];
		end 
	end 	
	
    always @(posedge clk) begin
		if (ce1) begin 
			q1 <= mem[address1];
		end 
	end 	
	
	
	
endmodule