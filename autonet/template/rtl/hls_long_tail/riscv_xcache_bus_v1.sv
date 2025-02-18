///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company            : ViShare Technology Limited
// Designed by        : Edward Leung
// Date Created       : 2025-01-24
// Description        : RISCV XCACHE interface with arbiter.
// Version            : v1.0 - First version.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module riscv_xcache_bus_v1 import xcache_param_pkg::*;
#(
    parameter RV_NUM      = 4,
    parameter ADDR_WIDTH  = 32,
    parameter DATA_WIDTH  = 32, 
	parameter RV_IDX_BITS = (RV_NUM == 1)? 1 : $clog2(RV_NUM)
)
(
    input                             clk,
    input                             rstn,
    //Riscv IO
    input        [7 : 0]              rv_part  [RV_NUM],
    input                             rv_re    [RV_NUM],
    input        [3 : 0]              rv_we    [RV_NUM],
    input        [31 : 0]             rv_addr  [RV_NUM],
    input        [31 : 0]             rv_wdata [RV_NUM],
    output logic                      rv_ready [RV_NUM],
    output logic                      rv_valid [RV_NUM],
    output logic [31 : 0]             rv_rdata [RV_NUM],
    //XCACHE
    input                             mem_rdy,
    output logic [7 : 0]              mem_part,
    output logic                      mem_re,
    output logic [3 : 0]              mem_we,
    output logic [ADDR_WIDTH - 1 : 0] mem_ad,
    output logic [DATA_WIDTH - 1 : 0] mem_di,
    input        [DATA_WIDTH - 1 : 0] mem_do,
    input                             mem_do_vld
);

logic                       rv_req;
logic [31 : 0]              rv_addr2[RV_NUM];
logic [RV_IDX_BITS - 1 : 0] rv_idx;
logic [RV_IDX_BITS - 1 : 0] rv_idx_buf[4];
logic [1 : 0]               rv_idx_buf_head;
logic [1 : 0]               rv_idx_buf_tail;
logic [RV_IDX_BITS - 1 : 0] arb_rrpt;
logic [RV_IDX_BITS : 0]     tmp1;


//--------------------------------------------------------------
// RISCV request
//--------------------------------------------------------------
always_comb begin
    rv_req = 0;
    rv_idx = 0;
    for (int i = 0; i < RV_NUM; i = i + 1) begin
        tmp1 = arb_rrpt + i[RV_IDX_BITS - 1 : 0];
        if (tmp1 >= RV_NUM) tmp1 = tmp1 - RV_NUM;
        if (rv_re[tmp1] == 1 || rv_we[tmp1] != 0) begin
            rv_req = 1;
            rv_idx = tmp1;
            break;
        end
    end
    mem_part = rv_part [rv_idx];
    mem_re   = rv_re   [rv_idx];
    mem_we   = rv_we   [rv_idx];
    mem_ad   = rv_addr [rv_idx];
    mem_di   = rv_wdata[rv_idx];
    for (int i = 0; i < RV_NUM; i = i + 1) begin
        rv_ready[i] = mem_rdy & (rv_idx == i);
    end
end
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        arb_rrpt        <= 0;
        rv_idx_buf      <= '{default:'0};
        rv_idx_buf_head <= 0;
        rv_idx_buf_tail <= 0;
    end
    else begin
        if (rv_req) begin
            arb_rrpt <= rv_idx + 1;
        end
        if (rv_req & mem_re & mem_rdy) begin
            rv_idx_buf[rv_idx_buf_tail] <= rv_idx;
            rv_idx_buf_tail <= rv_idx_buf_tail + 1;
        end
        if (mem_do_vld) begin
            rv_idx_buf_head <= rv_idx_buf_head + 1;
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
            if (mem_do_vld == 1 && rv_idx_buf[rv_idx_buf_head] == i[RV_IDX_BITS - 1 : 0]) begin 
				rv_valid[i] <= 1;
				rv_rdata[i] <= mem_do;
			end 
            else begin
                rv_valid[i] <= 0;
            end
        end 
    end 
end 
    

endmodule
