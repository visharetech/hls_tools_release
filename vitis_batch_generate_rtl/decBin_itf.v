`timescale 1ns/1ns

(* use_dsp = "simd" *)
(* dont_touch = "1" *)
module decBin_itf (    
    input           ap_clk,
    input           ap_rst,
    input           ap_ce,
    input           ap_start,
    input           ap_continue,
    output          ap_idle,
    output          ap_done,
    output          ap_ready,    
    input  [8 : 0]  ctx,
    output          ap_return
);
endmodule