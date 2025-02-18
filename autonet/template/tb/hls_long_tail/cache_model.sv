//New cache model for #pragma HLS interface port=dcache mode=ap_memory storage_type=ram_1p latency=3

module cache_model
#(
    parameter int  CORES          = 4,
    parameter real MISS_RATE      = 0.5, 
    parameter int  MAX_MISS_CYCLE = 8,
    parameter int  DEPTH          = 256,
    parameter int  DBITS          = 32,
    parameter int  ABITS          = $clog2(DEPTH)
)
(
    input              clk,
    input              rstn,
    input              hls_ap_ce[CORES],
    output             ready    [CORES],
    input  [ABITS-1:0] address0 [CORES],
    input              ce0      [CORES],
    input              we0      [CORES],
    input  [3:0]       we_mask  [CORES],
    input  [DBITS-1:0] d0       [CORES],
    output logic [DBITS-1:0] q0 [CORES],
    output logic       q0_vld   [CORES]
);

localparam int MISS_RATE_INT = MISS_RATE * 100;

logic [7:0] mem[DEPTH] = '{default:'0};
logic [ABITS-1:0] address0_r[CORES];
logic [31:0]      miss_cycle[CORES];

logic [DBITS-1:0]	q[CORES];
logic      		 	q_vld[CORES];
logic [DBITS-1:0]	q_r[CORES];
logic      		 	q_vld_r[CORES];


function int rand_num(int range);
    return ($random & 32'h7fffffff) % (range + 1);
endfunction

always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        address0_r <= '{default:'0};
        miss_cycle <= '{default:'0};

        q 		<= '{default:'0};
        q_vld 	<= '{default:'0};
		
        q_r 	<= '{default:'0};
        q_vld_r <= '{default:'0};
		
        q0      <= '{default:'0};
        q0_vld  <= '{default:'0};
    end
    else begin        
        
        for (int i = 0; i < CORES; i++) begin
            if (hls_ap_ce[i]) begin
                q_r[i] 		<= q[i];
                q_vld_r[i]	<= q_vld[i];
        
                q0[i] 		<= q_r[i];
                q0_vld[i]	<= q_vld_r[i];
            
                q_vld[i]    <= 0;
            
                //Write memory
                if (ce0[i] & ready[i]) begin
                    address0_r[i] <= address0[i];
                    if (we0[i]) begin
                        if (we_mask[i][0]) begin
                            mem[address0[i]] <= d0[i][7:0];
                        end
                        if (we_mask[i][1]) begin
                            mem[address0[i]+1] <= d0[i][15:8];
                        end
                        if (we_mask[i][2]) begin
                            mem[address0[i]+2] <= d0[i][23:16];
                        end
                        if (we_mask[i][3]) begin
                            mem[address0[i]+3] <= d0[i][31:24];
                        end
                    end else begin
                        miss_cycle[i] <= rand_num(MAX_MISS_CYCLE - 1) + 1;
                    end
                    
                end
                
                q[i] <= {mem[address0[i]+3], mem[address0[i]+2], mem[address0[i]+1], mem[address0[i]]};
                if (ce0[i] & ready[i] & ~we0[i]) begin 
                    q_vld[i]	<= 1'b1;
                end		
                //Model cache miss randomly
//              if (miss_cycle[i] == 0) begin
                    //no operation
//              end else if (miss_cycle[i] == 1) begin
//                  miss_cycle[i] <= 0;
                    /*
                    q0[i] <= {mem[address0_r[i]+3], mem[address0_r[i]+2], mem[address0_r[i]+1], mem[address0_r[i]]};
                    q0_vld[i] <= 1'b1;
                    */
//              end else begin
//                  miss_cycle[i] <= miss_cycle[i] - 1'b1;
//              end
            end
        end
    end
end

generate
for (genvar c = 0; c < CORES; c++) begin
    //assign ready[c] = (miss_cycle[c] == 0 && rstn) ? 1'b1 : 1'b0;
    assign ready[c] = 1;
end
endgenerate


endmodule