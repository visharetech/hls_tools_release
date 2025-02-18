///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company            : ViShare Technology Limited
// Designed by        : Edward Leung
// Date Created       : 2023-06-26
// Description        : RISCV HLS AP_CTRL interface with arbiter.
// Version            : v1.0 - First version.
//                    : v1.1 - With ap_start & ap_done fifo
//                    : v1.2 - Improve latency of ap ctrl
//                    : v1.3 - Profiling counter for ap control.
//                    : v1.4 - With function arbiter.
//                    : v1.5 - New definition of profiling counters.
//                    : v1.6 - Riscv can access xmem1
//                    : v1.7 - Each HLS has its own profiling counters.
//                           - Clear profiling counter by RISCV.
//                           - Call count added.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
`define AP_PROFILE_ALL
//edward 2024-12-04: If AP_PROFILE_ALL (RV_NUM=4, HLS_PARENT=9, HLS_NUM=32), LUT=24974, Freq=300MHz(slack=0.206)
module riscv_ap_ctrl_bus_v1 import xcache_param_pkg::*; import hls_long_tail_pkg::*;
#(
    parameter ENABLE_PROFILE   = 0,
    parameter RV_NUM           = 4,
    parameter RV_CHILD_ID      = 0,
    parameter HLS_PARENT       = 1,
    parameter HLS_NUM          = 8,
    parameter HLS_ARG_WIDTH    = 32,
    parameter HLS_ARG_VECTOR   = 8,
    parameter HLS_RET_WIDTH    = 32,
    parameter HLS_RET_VECTOR   = 1,
    parameter XMEM_ADDR_WIDTH  = 16,
    parameter XMEM_DATA_WIDTH  = 32, 
    parameter DMA_ADDR_WIDTH   = 20,
    parameter DMA_DATA_WIDTH   = 32,
    parameter XMEM_TOTAL_DEPTH = -1, 
    parameter ENABLE_XMEM1_RW  = 0,
	parameter RV_IDX_BITS      = (RV_NUM == 1)? 1 : $clog2(RV_NUM)
)
(
    input                                   clk,
    input                                   rstn,
    //Riscv IO
    input                                   rv_re    [RV_NUM],
    input        [3 : 0]                    rv_we    [RV_NUM],
    input        [31 : 0]                   rv_addr  [RV_NUM],
    input        [31 : 0]                   rv_wdata [RV_NUM],
    output logic                            rv_ready [RV_NUM],
    output logic                            rv_valid [RV_NUM],
    output logic [31 : 0]                   rv_rdata [RV_NUM],
    //HLS ap_ctrl (for porfiling)
    input                                   ap_rv_req     [RV_NUM],
    input        [31:0]                     ap_rv_id      [RV_NUM],    
    input                                   ap_hls_req    [HLS_PARENT],
    input        [31:0]                     ap_hls_id     [HLS_PARENT],
    input                                   ap_hls_retReq [HLS_PARENT],
    input                                   ap_hls_retPop [HLS_PARENT],
    input                                   ap_arb_start  [HLS_NUM],
    input                                   ap_start      [HLS_NUM],
    input                                   ap_done       [HLS_NUM],
    input                                   ap_busy       [HLS_NUM],
    input        [7:0] 		                ap_core       [HLS_NUM],
    input                                   ap_dc_ready   [HLS_NUM],
    input                                   ap_xmem_ready [HLS_NUM],
    input                                   ap_ret_ready  [HLS_NUM],
   
    //XMEM (v2)
    input                                   xmem2_rdy,
    output logic                            xmem2_re,
    output logic [3 : 0]                    xmem2_we,
    output logic [XMEM_ADDR_WIDTH - 1 : 0]  xmem2_ad,
    output logic [XMEM_DATA_WIDTH - 1 : 0]  xmem2_di,
    input        [XMEM_DATA_WIDTH - 1 : 0]  xmem2_do,
    //XMEM (v1) - for debug
    input                                   xmem1_rdy,
    output logic                            xmem1_re,
    output logic [3 : 0]                    xmem1_we,
    output logic [XMEM_ADDR_WIDTH - 1 : 0]  xmem1_ad,
    output logic [XMEM_DATA_WIDTH - 1 : 0]  xmem1_di,
    input        [XMEM_DATA_WIDTH - 1 : 0]  xmem1_do,    
    //DMA
    input                                   dma_rdy,
    output logic                            dma_re,
    output logic                            dma_we,
    output logic [DMA_ADDR_WIDTH - 1 : 0]   dma_ad,
    output logic [DMA_DATA_WIDTH - 1 : 0]   dma_di,
    input        [DMA_DATA_WIDTH - 1 : 0]   dma_do    
);

//RISCV command
localparam [3:0] XMEM2_ACCESS      = 0;    //HLS xmem (v2) access
localparam [3:0] XMEM1_ACCESS      = 1;    //HLS xmem (v1) access (for debug)
localparam [3:0] DMA_ACCESS        = 2;    //Access DMA in long tail functions
localparam [3:0] GET_HLS_CYCLE     = 3;    //Read profiling cycle (total)
localparam [3:0] GET_HLS_DC_BUSY   = 4;    //Read profiling cycle (dc cache miss)
localparam [3:0] GET_HLS_XMEM_BUSY = 5;    //Read profiling cycle (xmem2 not ready)
localparam [3:0] GET_HLS_FARB_BUSY = 6;    //Read profiling cycle (func_arbiter not ready)
localparam [3:0] CLR_HLS_PROF      = 7;    //Clear profiling counter
localparam [3:0] GET_HLS_CALL_CNT  = 8;    //Read profiling call count

//Others
localparam CMD_IDX_BITS          = 4;
//localparam RV_IDX_BITS           = (RV_NUM == 1)? 1 : $clog2(RV_NUM);
localparam HLS_IDX_BITS          = (HLS_NUM == 1)? 1 : $clog2(HLS_NUM);
localparam PARENT_IDX_BITS       = (HLS_PARENT == 1)? 1 : $clog2(HLS_PARENT);

//Command
logic [CMD_IDX_BITS - 1 : 0]    rv_cmd       [RV_NUM];
logic [19 : 0]                  rv_offset    [RV_NUM];
logic [7 : 0]                   rv_part      [RV_NUM];
logic [DMA_ADDR_WIDTH-1:0]      rv_dma_offset[RV_NUM];
logic [HLS_IDX_BITS-1:0]        rv_hls_id    [RV_NUM];
//XMEM (v2) requset
logic                           xmem2_req_re       [RV_NUM];
logic [3 : 0]                   xmem2_req_we       [RV_NUM];
logic [XMEM_ADDR_WIDTH - 1 : 0] xmem2_req_adr      [RV_NUM];
logic [XMEM_DATA_WIDTH - 1 : 0] xmem2_req_din      [RV_NUM];
logic                           xmem2_req_re_r     [RV_NUM];
logic [3 : 0]                   xmem2_req_we_r     [RV_NUM];
logic [XMEM_ADDR_WIDTH - 1 : 0] xmem2_req_adr_r    [RV_NUM];
logic [XMEM_DATA_WIDTH - 1 : 0] xmem2_req_din_r    [RV_NUM];
logic                           xmem2_req_not_rdy_r[RV_NUM];
//XMEM (v1)requset
logic                           xmem1_req_re       [RV_NUM];
logic [3 : 0]                   xmem1_req_we       [RV_NUM];
logic [XMEM_ADDR_WIDTH - 1 : 0] xmem1_req_adr      [RV_NUM];
logic [XMEM_DATA_WIDTH - 1 : 0] xmem1_req_din      [RV_NUM];
logic                           xmem1_req_re_r     [RV_NUM];
logic [3 : 0]                   xmem1_req_we_r     [RV_NUM];
logic [XMEM_ADDR_WIDTH - 1 : 0] xmem1_req_adr_r    [RV_NUM];
logic [XMEM_DATA_WIDTH - 1 : 0] xmem1_req_din_r    [RV_NUM];
logic                           xmem1_req_not_rdy_r[RV_NUM];
//DMA requset
logic                           dma_req_re [RV_NUM];
logic                           dma_req_we [RV_NUM];
logic [DMA_ADDR_WIDTH - 1 : 0]  dma_req_adr[RV_NUM];
logic [DMA_DATA_WIDTH - 1 : 0]  dma_req_din[RV_NUM];
//DMA arbiter
logic                           dma_arb_vld;
logic [RV_IDX_BITS - 1 : 0]     dma_arb_sel;
logic [RV_IDX_BITS - 1 : 0]     dma_arb_rrpt;
logic [RV_IDX_BITS : 0]         tmp2;
//XMEM (v2) inteface
logic                           xmem2_not_rdy_r;
logic                           xmem2_re_r;
logic                           xmem2_re_2r;
logic                           xmem2_re_3r;
logic                           xmem2_rv_req;
logic [RV_IDX_BITS - 1 : 0]     xmem2_rv_idx;
logic [RV_IDX_BITS - 1 : 0]     xmem2_rv_idx_r;
logic [RV_IDX_BITS - 1 : 0]     xmem2_rv_idx_2r;
logic [RV_IDX_BITS - 1 : 0]     xmem2_rv_idx_3r;
logic [RV_IDX_BITS - 1 : 0]     xmem2_arb_rrpt;
logic [RV_IDX_BITS : 0]         tmp1;
//XMEM (v1) inteface
logic                           xmem1_not_rdy_r;
logic                           xmem1_re_r;
logic                           xmem1_rv_req;
logic [RV_IDX_BITS - 1 : 0]     xmem1_rv_idx;
logic [RV_IDX_BITS - 1 : 0]     xmem1_rv_idx_r;
//DMA inteface
logic                           dma_not_rdy;
logic                           dma_re_r;
logic [RV_IDX_BITS - 1 : 0]     dma_rv_idx;
logic [RV_IDX_BITS - 1 : 0]     dma_rv_idx_r;
logic                           dma_rdy_r;
//AP profiling
//cycle1: between ap_start and ap_done
//cycle2: between ap_start and ap_done but not include cache miss
`ifdef AP_PROFILE_ALL
logic                           hls_start      [RV_NUM][HLS_NUM];
logic [31 : 0]                  hls_cycle      [RV_NUM][HLS_NUM];
logic [31 : 0]                  hls_dc_busy    [RV_NUM][HLS_NUM];
logic [31 : 0]                  hls_xmem_busy  [RV_NUM][HLS_NUM];
logic [31 : 0]                  hls_farb_busy  [RV_NUM][HLS_NUM];
logic [31 : 0]                  hls_call_cnt   [RV_NUM][HLS_NUM];
`else
logic                           hls_start      [RV_NUM];
logic [31 : 0]                  hls_cycle      [RV_NUM];
logic [31 : 0]                  hls_dc_busy    [RV_NUM];
logic [31 : 0]                  hls_xmem_busy  [RV_NUM];
logic [31 : 0]                  hls_farb_busy  [RV_NUM];
logic [31 : 0]                  hls_call_cnt   [RV_NUM];
`endif
logic                           hls_call       [RV_NUM][HLS_NUM];
logic [HLS_IDX_BITS-1:0]        hls_id         [RV_NUM];
logic                           ap_rv_req_r    [RV_NUM];
logic [31 : 0]                  ap_rv_id_r     [RV_NUM];
logic                           ap_hls_req_r   [HLS_PARENT];
logic [31 : 0]                  ap_hls_id_r    [HLS_PARENT];
logic                           ap_hls_retReq_r[HLS_PARENT];
logic                           ap_hls_retPop_r[HLS_PARENT];
logic                           ap_arb_start_r [HLS_NUM];
logic                           ap_start_r     [HLS_NUM];
logic                           ap_done_r      [HLS_NUM];
logic                           ap_busy_r      [HLS_NUM];
logic [7 : 0]                   ap_core_r      [HLS_NUM];
logic                           ap_dc_ready_r  [HLS_NUM];
logic                           ap_xmem_ready_r[HLS_NUM];
logic                           ap_ret_ready_r [HLS_NUM];


//-----------------
// Address mapping
//-----------------
always_comb begin
    for (int i = 0; i < RV_NUM; i = i + 1) begin
        rv_cmd       [i] = rv_addr[i][20 +: CMD_IDX_BITS];
        rv_offset    [i] = rv_addr[i][0  +: XMEM_ADDR_WIDTH];
        rv_dma_offset[i] = rv_addr[i][0  +: DMA_ADDR_WIDTH]; 
        rv_hls_id    [i] = rv_addr[i][2  +: HLS_IDX_BITS]; 
    end
end

//-------------------------------------------------
//Riscv ready
//-------------------------------------------------
always_comb begin
    for (int i = 0; i < RV_NUM; i = i + 1) begin
        if ((rv_re[i] == 1 || rv_we[i] != 0) && rv_cmd[i] == XMEM2_ACCESS && (xmem2_not_rdy_r == 1 || xmem2_req_not_rdy_r[i] == 1)) begin
            rv_ready[i] = 0;
        end
        else if (ENABLE_XMEM1_RW && (rv_re[i] == 1 || rv_we[i] != 0) && rv_cmd[i] == XMEM1_ACCESS && (xmem1_not_rdy_r == 1 || xmem1_req_not_rdy_r[i] == 1)) begin
            rv_ready[i] = 0;
        end
        //Previous DMA access is not finish
        else if ((rv_re[i] == 1 || rv_we[i] != 0) && (dma_req_re[i] == 1 || dma_req_we[i] != 0)) begin
            rv_ready[i] = 0;
        end
        else begin
            rv_ready[i] = 1;
        end
    end
end

//-------------------------------------------------
//Riscv Read data & valid
//-------------------------------------------------
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        for (int i = 0; i < RV_NUM; i = i + 1) begin
            rv_valid[i] <= 0;
            rv_rdata[i] <= 0;
        end 
    end 
    else begin 
        for (int i = 0; i < RV_NUM; i = i + 1) begin
            if (xmem2_re_3r == 1 && xmem2_rv_idx_3r == i[RV_IDX_BITS - 1 : 0]) begin 
                rv_valid[i] <= 1;
                rv_rdata[i] <= xmem2_do;
            end
			else if (ENABLE_XMEM1_RW && xmem1_re_r == 1 && xmem1_rv_idx_r == i[RV_IDX_BITS - 1 : 0]) begin 
				rv_valid[i] <= 1;
				rv_rdata[i] <= xmem1_do;
			end 
            else if (dma_re_r == 1 && dma_rv_idx_r == i[RV_IDX_BITS - 1 : 0]) begin 
                rv_valid[i] <= 1;
                rv_rdata[i] <= dma_do;
            end
`ifdef AP_PROFILE_ALL
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_CYCLE) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_cycle[i][rv_hls_id[i]];
            end
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_DC_BUSY) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_dc_busy[i][rv_hls_id[i]];
            end
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_XMEM_BUSY) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_xmem_busy[i][rv_hls_id[i]];
            end
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_FARB_BUSY) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_farb_busy[i][rv_hls_id[i]];
            end
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_CALL_CNT) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_call_cnt[i][rv_hls_id[i]];
            end            
`else
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_CYCLE) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_cycle[i];
            end
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_DC_BUSY) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_dc_busy[i];
            end
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_XMEM_BUSY) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_xmem_busy[i];
            end
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_FARB_BUSY) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_farb_busy[i];
            end
            else if (rv_re[i] == 1 && rv_cmd[i] == GET_HLS_CALL_CNT) begin
                rv_valid[i] <= 1;
                rv_rdata[i] <= hls_call_cnt[i];
            end
`endif
            else begin
                rv_valid[i] <= 0;
            end
        end 
    end 
end 

//---------------------------------------
// HLS profiling cycle
//---------------------------------------
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        hls_start       <= '{default:'0};
        hls_call        <= '{default:'0};
        hls_id          <= '{default:'0};
        hls_cycle       <= '{default:'0};
        hls_dc_busy     <= '{default:'0};
        hls_xmem_busy   <= '{default:'0};
        hls_farb_busy   <= '{default:'0};        
        hls_call_cnt    <= '{default:'0};
        ap_rv_req_r     <= '{default:'0};
        ap_rv_id_r      <= '{default:'0};
        ap_hls_req_r    <= '{default:'0};
        ap_hls_id_r     <= '{default:'0};
        ap_hls_retReq_r <= '{default:'0};
        ap_hls_retPop_r <= '{default:'0};
        ap_arb_start_r  <= '{default:'0};
        ap_start_r      <= '{default:'0};
        ap_done_r       <= '{default:'0};
        ap_busy_r       <= '{default:'0};
        ap_core_r       <= '{default:'0};
        ap_dc_ready_r   <= '{default:'0};
        ap_xmem_ready_r <= '{default:'0};
        ap_ret_ready_r  <= '{default:'0};
    end
    else begin
        if (ENABLE_PROFILE == 1) begin
            ap_rv_req_r     <= ap_rv_req;
            ap_rv_id_r      <= ap_rv_id;
            ap_hls_req_r    <= ap_hls_req;
            ap_hls_id_r     <= ap_hls_id;
            ap_hls_retReq_r <= ap_hls_retReq;
            ap_hls_retPop_r <= ap_hls_retPop;
            ap_arb_start_r  <= ap_arb_start;
            ap_start_r      <= ap_start;
            ap_done_r       <= ap_done;
            ap_busy_r       <= ap_busy;
            ap_core_r       <= ap_core;
            ap_dc_ready_r   <= ap_dc_ready;
            ap_xmem_ready_r <= ap_xmem_ready;
            ap_ret_ready_r  <= ap_ret_ready;
`ifdef AP_PROFILE_ALL
            //Clear counter
            for (int c = 0; c < RV_NUM; c = c + 1) begin
                if (rv_we[c] && rv_ready[c] && rv_cmd[c] == CLR_HLS_PROF) begin
                    hls_cycle    [c][rv_hls_id[c][HLS_IDX_BITS-1:0]] <= 0;
                    hls_dc_busy  [c][rv_hls_id[c][HLS_IDX_BITS-1:0]] <= 0;
                    hls_xmem_busy[c][rv_hls_id[c][HLS_IDX_BITS-1:0]] <= 0;
                    hls_farb_busy[c][rv_hls_id[c][HLS_IDX_BITS-1:0]] <= 0;
                    hls_call_cnt [c][rv_hls_id[c][HLS_IDX_BITS-1:0]] <= 0; 
                end
            end
            //Start by RISCV
            for (int c = 0; c < RV_NUM; c = c + 1) begin
                if (ap_rv_req_r[c] == 1 && ap_rv_id_r[c] < HLS_NUM) begin
                    hls_start    [c][ap_rv_id_r[c][HLS_IDX_BITS-1:0]] <= 1;
                    //hls_cycle    [c][ap_rv_id_r[c][HLS_IDX_BITS-1:0]] <= 0;
                    //hls_dc_busy  [c][ap_rv_id_r[c][HLS_IDX_BITS-1:0]] <= 0;
                    //hls_xmem_busy[c][ap_rv_id_r[c][HLS_IDX_BITS-1:0]] <= 0;
                    //hls_farb_busy[c][ap_rv_id_r[c][HLS_IDX_BITS-1:0]] <= 0;
                end
            end
            //Start by HLS parent    
            for (int h = 0; h < HLS_PARENT; h = h + 1) begin
                if (ap_hls_req_r[h] == 1) begin
                    if (ap_hls_id_r[h] < HLS_NUM) begin
                        hls_start     [ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][ap_hls_id_r[h][HLS_IDX_BITS-1:0]] <= 1;                    
                        //hls_cycle     [ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][ap_hls_id_r[h][HLS_IDX_BITS-1:0]] <= 0;
                        //hls_dc_busy   [ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][ap_hls_id_r[h][HLS_IDX_BITS-1:0]] <= 0;
                        //hls_xmem_busy [ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][ap_hls_id_r[h][HLS_IDX_BITS-1:0]] <= 0;
                        //hls_farb_busy [ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][ap_hls_id_r[h][HLS_IDX_BITS-1:0]] <= 0;
                    end
                    //Pause during calling child (blocking)
                    if (ap_hls_retReq_r[h]) begin                        
                        hls_start[ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][HLS_PARENT_IDX[h]] <= 0;                                                
                        hls_call [ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][HLS_PARENT_IDX[h]] <= 1;
                    end
                end
                //Resmume from child call
                if (ap_hls_retPop_r[h] && hls_call[ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][HLS_PARENT_IDX[h]]) begin
                    hls_start[ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][HLS_PARENT_IDX[h]] <= ~(ap_done_r[HLS_PARENT_IDX[h]] & ap_ret_ready_r[HLS_PARENT_IDX[h]]);
                    hls_call [ap_core_r[HLS_PARENT_IDX[h]][RV_IDX_BITS-1:0]][HLS_PARENT_IDX[h]] <= 0;                  
                end
            end            
            //Profiling
            for (int c = 0; c < RV_NUM; c = c + 1) begin        
                for (int i = 0; i < HLS_NUM; i = i + 1) begin                    
                    if (hls_start[c][i]) begin
                        //Total cycle
                        hls_cycle[c][i] <= hls_cycle[c][i] + 1;
                        //Not selected by function arbiter
                        if (ap_core_r[i][RV_IDX_BITS-1:0] != c || ap_busy_r[i] == 0) begin
                            hls_farb_busy[c][i] <= hls_farb_busy[c][i] + 1;
                        end
                        else if (ap_core_r[i][RV_IDX_BITS-1:0] == c && ap_busy_r[i] == 1) begin
                            //Cache miss
                            if (~ap_dc_ready_r[i]) begin
                                hls_dc_busy[c][i] <= hls_dc_busy[c][i] + 1;
                            end
                            //XMEM busy
                            if ((ap_arb_start_r[i] & ~ap_start_r[i]) | ~ap_xmem_ready_r[i]) begin
                                hls_xmem_busy[c][i] <= hls_xmem_busy[c][i] + 1;
                            end
                            //Function arbiter (return) busy
                            if (ap_done_r[i] & ~ap_ret_ready_r[i]) begin
                                hls_farb_busy[c][i] <= hls_farb_busy[c][i] + 1;
                            end
                            //Done
                            if (ap_done_r[i] & ap_ret_ready_r[i]) begin
                                hls_start[c][i] <= 0;
                            end
                        end
                    end
                end
            end            
            //Call count
            for (int i = 0; i < HLS_NUM; i = i + 1) begin           
                if (ap_done_r[i] & ap_ret_ready_r[i]) begin            
                    hls_call_cnt[ap_core_r[i]][i] <= hls_call_cnt[ap_core_r[i]][i] + 1; 
                end
            end
`else
            for (int c = 0; c < RV_NUM; c = c + 1) begin
                //edward 2024-11-28: if hls start profiling, no accept another hls profile.
                if (ap_rv_req_r[c] & ~hls_start[c]) begin
                    hls_start    [c] <= (ap_rv_id_r[c] < HLS_NUM)? 1 : 0;
                    hls_id       [c] <= ap_rv_id_r[c];
                    hls_cycle    [c] <= 0;
                    hls_dc_busy  [c] <= 0;
                    hls_xmem_busy[c] <= 0;
                    hls_farb_busy[c] <= 0;
                end          
                else if (hls_start[c]) begin
                    //Total cycle
                    hls_cycle[c] <= hls_cycle[c] + 1;
                    //Not selected by function arbiter
                    if (ap_core_r[hls_id[c]][RV_IDX_BITS-1:0] != c || ap_busy_r[hls_id[c]] == 0) begin
                        hls_farb_busy[c] <= hls_farb_busy[c] + 1;
                    end
                    else begin
                        //Cache miss
                        if (~ap_dc_ready_r[hls_id[c]]) begin
                            hls_dc_busy[c] <= hls_dc_busy[c] + 1;
                        end
                        //XMEM busy
                        if ((ap_arb_start_r[hls_id[c]] & ~ap_start_r[hls_id[c]]) | ~ap_xmem_ready_r[hls_id[c]]) begin
                            hls_xmem_busy[c] <= hls_xmem_busy[c] + 1;
                        end
                        //Function arbiter (return) busy
                        if (ap_done_r[hls_id[c]] & ~ap_ret_ready_r[hls_id[c]]) begin
                            hls_farb_busy[c] <= hls_farb_busy[c] + 1;
                        end
                        //Done
                        if (ap_done_r[hls_id[c]] & ap_ret_ready_r[hls_id[c]]) begin
                            hls_start[c] <= 0;
                            hls_call_cnt[c] <= hls_call_cnt[c] + 1; 
                        end
                    end
                end
            end
`endif
        end
    end
end

//--------------------------------------------------------------
// RISCV xmem (v2) request
//--------------------------------------------------------------
always_comb begin        
    xmem2_req_re  = xmem2_req_re_r;
    xmem2_req_we  = xmem2_req_we_r;
    xmem2_req_adr = xmem2_req_adr_r;
    xmem2_req_din = xmem2_req_din_r;
    for (int i = 0; i < RV_NUM; i = i + 1) begin
        if (~xmem2_not_rdy_r & ~xmem2_req_not_rdy_r[i]) begin
            if (rv_cmd[i] == XMEM2_ACCESS) begin
                xmem2_req_re [i] = rv_re[i];
                xmem2_req_we [i] = rv_we[i];            
            end
            else begin
                xmem2_req_re [i] = 0;
                xmem2_req_we [i] = 0;
            end
            xmem2_req_adr[i] = rv_offset[i];
            xmem2_req_din[i] = rv_wdata[i];
        end
    end
end
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin       
        xmem2_req_re_r      <= '{default:'0};
        xmem2_req_we_r      <= '{default:'0};
        xmem2_req_adr_r     <= '{default:'0};
        xmem2_req_din_r     <= '{default:'0};
        xmem2_req_not_rdy_r <= '{default:'0};
    end
    else begin
        for (int i = 0; i < RV_NUM; i = i + 1) begin            
            xmem2_req_re_r [i]     <= xmem2_req_re [i];
            xmem2_req_we_r [i]     <= xmem2_req_we [i];
            xmem2_req_adr_r[i]     <= xmem2_req_adr[i];
            xmem2_req_din_r[i]     <= xmem2_req_din[i];
            xmem2_req_not_rdy_r[i] <= (xmem2_req_re[i] == 1 || xmem2_req_we [i] != 0) && (xmem2_rv_req == 1) && (xmem2_rv_idx != i);
        end
    end
end
//Round-robin arbiter
always_comb begin
    xmem2_re      = 0;
    xmem2_we      = 0;
    xmem2_ad      = xmem2_req_adr[0];
    xmem2_di      = xmem2_req_din[0];
    xmem2_rv_req  = 0;
    xmem2_rv_idx  = 0;
    for (int i = 0; i < RV_NUM; i = i + 1) begin
        tmp1 = xmem2_arb_rrpt + i[RV_IDX_BITS - 1 : 0];
        if (tmp1 >= RV_NUM) tmp1 = tmp1 - RV_NUM;
        if (xmem2_req_re[tmp1] == 1 || xmem2_req_we[tmp1] != 0) begin
            xmem2_re      = xmem2_req_re [tmp1] & xmem2_rdy;
            xmem2_we      = (xmem2_rdy)? xmem2_req_we[tmp1] : 0;
            xmem2_ad      = xmem2_req_adr[tmp1];
            xmem2_di      = xmem2_req_din[tmp1];
            xmem2_rv_req  = 1;
            xmem2_rv_idx  = tmp1;
            break;
        end
    end
end
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        xmem2_not_rdy_r <= 0;
        xmem2_re_r      <= 0;
        xmem2_re_2r     <= 0;
        xmem2_re_3r     <= 0;
        xmem2_rv_idx_r  <= 0;
        xmem2_rv_idx_2r <= 0;
        xmem2_rv_idx_3r <= 0;
        xmem2_arb_rrpt  <= 0;
    end
    else begin
        xmem2_not_rdy_r <= xmem2_rv_req & ~xmem2_rdy;
        xmem2_re_r      <= xmem2_re;
        xmem2_re_2r     <= xmem2_re_r;
        xmem2_re_3r     <= xmem2_re_2r;       
        xmem2_rv_idx_r  <= xmem2_rv_idx;
        xmem2_rv_idx_2r <= xmem2_rv_idx_r;
        xmem2_rv_idx_3r <= xmem2_rv_idx_2r;
        if (xmem2_rv_req) begin
            xmem2_arb_rrpt <= xmem2_rv_idx + 1;
        end
    end
end

//--------------------------------------------------------------
// RISCV xmem (v1) request
//--------------------------------------------------------------
always_comb begin        
    if (ENABLE_XMEM1_RW) begin
        xmem1_req_re  = xmem1_req_re_r;
        xmem1_req_we  = xmem1_req_we_r;
        xmem1_req_adr = xmem1_req_adr_r;
        xmem1_req_din = xmem1_req_din_r;    
        for (int i = 0; i < RV_NUM; i = i + 1) begin
            if (~xmem1_not_rdy_r & ~xmem1_req_not_rdy_r[i]) begin
                if (rv_cmd[i] == XMEM1_ACCESS) begin
                    xmem1_req_re [i] = rv_re[i];
                    xmem1_req_we [i] = rv_we[i];            
                end
                else begin
                    xmem1_req_re [i] = 0;
                    xmem1_req_we [i] = 0;
                end
                xmem1_req_adr[i] = rv_offset[i];
                xmem1_req_din[i] = rv_wdata[i];
            end
        end
    end
    else begin
        xmem1_req_re  = '{default:'0};
        xmem1_req_we  = '{default:'0};
        xmem1_req_adr = '{default:'0};
        xmem1_req_din = '{default:'0};    
    end
end
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin       
        xmem1_req_re_r      <= '{default:'0};
        xmem1_req_we_r      <= '{default:'0};
        xmem1_req_adr_r     <= '{default:'0};
        xmem1_req_din_r     <= '{default:'0};
        xmem1_req_not_rdy_r <= '{default:'0};
    end
    else begin
        if (ENABLE_XMEM1_RW) begin
            for (int i = 0; i < RV_NUM; i = i + 1) begin            
                xmem1_req_re_r [i]     <= xmem1_req_re [i];
                xmem1_req_we_r [i]     <= xmem1_req_we [i];
                xmem1_req_adr_r[i]     <= xmem1_req_adr[i];
                xmem1_req_din_r[i]     <= xmem1_req_din[i];
                xmem1_req_not_rdy_r[i] <= (xmem1_req_re[i] == 1 || xmem1_req_we [i] != 0) && (xmem1_rv_req == 1) && (xmem1_rv_idx != i);
            end
        end
    end
end
    
//--------------------------------------------------------------
//Priority arbiter (RISCV0 is the lowest priority)
//--------------------------------------------------------------
always_comb begin
    if (ENABLE_XMEM1_RW) begin
        xmem1_re     = 0;
        xmem1_we     = 0;
        xmem1_ad     = xmem1_req_adr[0];
        xmem1_di     = xmem1_req_din[0];
        xmem1_rv_req = 0;
        xmem1_rv_idx = 0;
        for (int i = 0; i < RV_NUM; i = i + 1) begin
            if (xmem1_req_re[i] == 1 || xmem1_req_we[i] != 0) begin
                xmem1_re     = xmem1_req_re [i] & xmem1_rdy;
                xmem1_we     = (xmem1_rdy)? xmem1_req_we[i] : 0;
                xmem1_ad     = xmem1_req_adr[i];
                xmem1_di     = xmem1_req_din[i];
                xmem1_rv_req = 1;
                xmem1_rv_idx = i;
            end
        end
    end
    else begin
        xmem1_re     = 0;
        xmem1_we     = 0;
        xmem1_ad     = 0;
        xmem1_di     = 0;
        xmem1_rv_req = 0;
        xmem1_rv_idx = 0;
    end
end
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        xmem1_not_rdy_r <= 0;
        xmem1_re_r      <= 0;
        xmem1_rv_idx_r  <= 0;
    end
    else begin
        if (ENABLE_XMEM1_RW) begin
            xmem1_not_rdy_r <= xmem1_rv_req & ~xmem1_rdy;
            xmem1_re_r      <= xmem1_re;
            xmem1_rv_idx_r  <= xmem1_rv_idx;
        end
    end
end

//---------------------
// RISCV DMA interface
//---------------------
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        dma_req_re    <= '{default: '0};
        dma_req_we    <= '{default: '0};
        dma_req_adr   <= '{default: '0};
        dma_req_din   <= '{default: '0};
    end
    else begin
        //=== RISCV ===
        for (int i = 0; i < RV_NUM; i = i + 1) begin
            //Write command
            if ((rv_we[i] != 0) && (rv_ready[i] != 0)) begin
                case(rv_cmd[i])
                    DMA_ACCESS: begin
                        dma_req_we [i] <= 1;
                        dma_req_adr[i] <= rv_dma_offset [i];
                        dma_req_din[i] <= rv_wdata      [i];
                    end
                endcase
            end
            //Read command
            if (rv_re[i] & rv_ready[i]) begin
                case(rv_cmd[i])
                    DMA_ACCESS: begin
                        dma_req_re [i] <= 1;
                        dma_req_adr[i] <= rv_dma_offset[i];
                    end
                endcase
            end
            //Clear DMA request
            if (dma_arb_vld && dma_arb_sel == i[RV_IDX_BITS - 1 : 0]) begin
                dma_req_re[i] <= 0;
                dma_req_we[i] <= 0;
            end
        end
    end
end

//----------------------------------------------------
// Round-robin arbiter to select RISCV to access DMA
//----------------------------------------------------
always_comb begin
    dma_arb_sel = 0;
    dma_arb_vld = 0;    
    for (int i = 0; i < RV_NUM; i = i + 1) begin
        tmp2 = dma_arb_rrpt + i[RV_IDX_BITS - 1 : 0];
        if (tmp2 >= RV_NUM) tmp2 = tmp2 - RV_NUM;
        if ((dma_req_re[tmp2] | dma_req_we[tmp2]) & ~dma_not_rdy) begin
            dma_arb_vld = 1;
            dma_arb_sel = tmp2;
            break;
        end
    end
end
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        dma_arb_rrpt <= 0;
    end
    else begin
        if (dma_arb_vld) begin
            dma_arb_rrpt <= dma_arb_sel + 1;
        end
    end
end

//----------------
// DMA interface
//----------------
//assign dma_not_rdy = (dma_re | dma_we) & ~dma_rdy_r;
assign dma_not_rdy = (dma_re | dma_we) & ~dma_rdy;
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        dma_re       <= 0;
        dma_we       <= 0;
        dma_ad       <= 0;
        dma_di       <= 0;
        dma_re_r     <= 0;
        dma_rv_idx   <= 0;
        dma_rv_idx_r <= 0;
        dma_rdy_r    <= 0;
    end
    else begin
        dma_rdy_r <= dma_rdy;
        dma_re_r  <= dma_re & dma_rdy;
        dma_rv_idx_r <= dma_rv_idx;
        if (~dma_not_rdy) begin
            if (dma_arb_vld) begin
                dma_re <= dma_req_re [dma_arb_sel];
                dma_we <= dma_req_we [dma_arb_sel];
                dma_ad <= dma_req_adr[dma_arb_sel];
                dma_di <= dma_req_din[dma_arb_sel];
                dma_rv_idx <= dma_arb_sel;
            end
            else begin
                dma_re <= 0;
                dma_we <= 0;
            end
        end
    end
end

//---------------------------------------
// Chipscope Debug
//---------------------------------------
(* mark_debug = "true" *) logic [HLS_NUM-1:0]        db_ap_arb_start;
(* mark_debug = "true" *) logic [HLS_NUM-1:0]        db_ap_start;
(* mark_debug = "true" *) logic [HLS_NUM-1:0]        db_ap_done;
(* mark_debug = "true" *) logic [HLS_NUM-1:0]        db_ap_busy;
(* mark_debug = "true" *) logic [HLS_NUM-1:0]        db_ap_dc_ready;
(* mark_debug = "true" *) logic [HLS_NUM-1:0]        db_ap_xmem_ready;
(* mark_debug = "true" *) logic [HLS_NUM-1:0]        db_ap_ret_ready;
//(* mark_debug = "true" *) logic [HLS_PARENT-1:0]     db_ap_hls_req;
//(* mark_debug = "true" *) logic [HLS_PARENT-1:0]     db_ap_hls_retReq;
//(* mark_debug = "true" *) logic [HLS_PARENT-1:0]     db_ap_hls_retPop;
//(* mark_debug = "true" *) logic [RV_NUM*HLS_NUM-1:0] db_hls_start;
//(* mark_debug = "true" *) logic [RV_NUM*HLS_NUM-1:0] db_hls_call;
always @ (posedge clk) begin
    for (int i = 0; i < HLS_NUM; i = i + 1) begin
        db_ap_arb_start [i] <= ap_arb_start [i];
        db_ap_start     [i] <= ap_start     [i];
        db_ap_done      [i] <= ap_done      [i];
        db_ap_busy      [i] <= ap_busy      [i];
        db_ap_dc_ready  [i] <= ap_dc_ready  [i];
        db_ap_xmem_ready[i] <= ap_xmem_ready[i];
        db_ap_ret_ready [i] <= ap_ret_ready [i];               
    end
    //for (int i = 0; i < HLS_PARENT; i = i + 1) begin
    //    db_ap_hls_req   [i] <= ap_hls_req   [i];
    //    db_ap_hls_retReq[i] <= ap_hls_retReq[i];
    //    db_ap_hls_retPop[i] <= ap_hls_retPop[i];
    //end
    //for (int i = 0; i < RV_NUM; i = i + 1) begin
    //    for (int j = 0; j < HLS_NUM; j = j + 1) begin
    //        db_hls_start[i * HLS_NUM + j] <= hls_start[i][j];
    //        db_hls_call [i * HLS_NUM + j] <= hls_call [i][j];
    //    end
    //end
end

endmodule
