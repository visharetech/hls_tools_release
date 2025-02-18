`timescale 1ns/1ns
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company            : ViShare Technology Limited
// Designed by        : Edward Leung
// Date Created       : 2023-05-02
// Description        : DecodeBin interface used by residual coding HLS.
//                      It acts as a blockbox when HLS synthesis.
// Version            : v1.0   - First version.
//                      v1.1   - Handle case if request during ap_ce=0.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module decBin_itf # (
    parameter PIPELINE = 1
)
(
    //ap_ctrl_hs
    input                 ap_clk,
    input                 ap_rst,
    //(* mark_debug = "true" *)
    input                 ap_ce,
    //(* mark_debug = "true" *)
    input                 ap_start,
    input                 ap_continue,
    //(* mark_debug = "true" *)
    output logic          ap_idle,
    //(* mark_debug = "true" *)
    output logic          ap_done,
    //(* mark_debug = "true" *)
    output logic          ap_ready,    
    //Input & Output
    input  [8 : 0]        ctx,
    output logic          ap_return,
    //DecodeBin Interface
    output logic [8 : 0]  get_inline_mem_addr_o,
    output logic          get_inline_mem_addr_o_ap_vld,
    input                 get_inline_mem_addr_o_ap_rdy,    
    input                 get_inline_mem_data_i,
    input                 get_inline_mem_data_i_ap_vld
);

//Busy
logic busy;
always @ (posedge ap_clk or posedge ap_rst) begin
    if (ap_rst) begin
        busy <= 0;
    end
    else begin
        if (PIPELINE == 1) begin
            if (ap_ce) begin        
                if (ap_start & ap_ready) begin
                    busy <= 1;
                end
                else if (ap_done) begin
                    busy <= 0;
                end
            end
        end
        else begin
            if (ap_start & ~busy) begin
                busy <= 1;
            end
            else if (ap_done) begin
                busy <= 0;
            end
        end
    end
end

//DecodeBin not ready
logic req_not_ready;
logic [8 : 0] ctx_r;
always @ (posedge ap_clk or posedge ap_rst) begin
    if (ap_rst) begin
        req_not_ready <= 0;
        ctx_r         <= 0;
    end
    else begin
        if (get_inline_mem_addr_o_ap_vld & ~get_inline_mem_addr_o_ap_rdy & ~req_not_ready) begin
            req_not_ready <= 1;
            ctx_r         <= ctx;
        end
        else if (req_not_ready & get_inline_mem_addr_o_ap_rdy) begin
            req_not_ready <= 0;        
        end
    end
end

//ap_ctrl_hs
always_comb begin
    ap_idle = ~ap_start & ~busy;
    //edward 2024-06-28: remove ap_ce dependency because case "ap_start & (~busy | ap_done) & ~ap_ce" seems not happened.
    //edward 2024-10-31: rollback with ap_ce
    //edward 2024-11-20: remove ap_ce only for PIPELINE=1
    if (PIPELINE == 1)
        ap_ready = (ap_start /*& ap_ce*/) & (~busy | ap_done);
    else
        ap_ready = ap_done;
end

//Address
always_comb begin
    get_inline_mem_addr_o = (req_not_ready)? ctx_r : ctx;
    //edward 2024-06-27: remove ap_ce because it is already considered in ap_ready
    //edward 2024-10-31: rollback with ap_ce
    //edward 2024-11-20: remove ap_ce only for PIPELINE=1
    if (PIPELINE == 1)
        get_inline_mem_addr_o_ap_vld = (ap_start /*& ap_ce*/ & ap_ready) | req_not_ready;
    else
        get_inline_mem_addr_o_ap_vld = (ap_start & ~busy) | req_not_ready;
end

//Return Data
//edward 2024-10-31: handle case if ap_ce=0 during return
logic get_inline_mem_data_r;
logic get_inline_mem_data_i_ap_vld_r;
always_comb begin
    ap_done = (get_inline_mem_data_i_ap_vld | get_inline_mem_data_i_ap_vld_r);
    ap_return = get_inline_mem_data_i_ap_vld_r? get_inline_mem_data_r : get_inline_mem_data_i;
end
always @ (posedge ap_clk or posedge ap_rst) begin
    if (ap_rst) begin
        get_inline_mem_data_i_ap_vld_r <= 0;
        get_inline_mem_data_r          <= 0;        
    end
    else begin
        if (get_inline_mem_data_i_ap_vld & ~ap_ce) begin
            get_inline_mem_data_i_ap_vld_r <= get_inline_mem_data_i_ap_vld;
            get_inline_mem_data_r          <= get_inline_mem_data_i;
        end
        else if(get_inline_mem_data_i_ap_vld_r & ap_ce) begin
            get_inline_mem_data_i_ap_vld_r <= 0;
            get_inline_mem_data_r          <= 0;
        end
    end
end
//-------------------------
// Debug
//-------------------------
// synthesis translate_off
// synopsys translate_off
logic dbg;
always @ (posedge ap_clk) begin
    dbg <= ap_start & (~busy | ap_done) & ~ap_ce;
end
// synopsys translate_on
// synthesis translate_on

endmodule