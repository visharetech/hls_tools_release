#!/bin/bash

link_func_arb_argv=(
"--dir=example/func_arbiter --parent pred_inter_chroma_pixel_hls.v --child blockcopy_pp_hls.v interp_horiz_pp_hls.v interp_vert_pp_hls.v interp_horiz_ps_hls.v filterVertical_sp_hls.v --out example/func_arbiter/tb/draft_func_arb_tb2.sv"
"--dir=example/func_arbiter --parent pred_inter_chroma_pixel_hls.v pred_inter_chroma_pixel_hls_dup1.v --child blockcopy_pp_hls.v interp_horiz_pp_hls.v interp_vert_pp_hls.v interp_horiz_ps_hls.v filterVertical_sp_hls.v --out example/func_arbiter/tb/draft_func_arb_tb2.sv"
)

case $1 in
    1)
        echo "python3 func_arb.py ${link_func_arb_argv[0]}"
        python3 func_arb.py ${link_func_arb_argv[0]}
        ;;
    2)
        echo "python3 func_arb.py ${link_func_arb_argv[1]}"
        python3 func_arb.py ${link_func_arb_argv[1]}
        ;;
    *)
        echo "Invalid test_id (1 or 2)"
        echo "Usage: ./test_func_arb.sh [test_id]"
        ;;
esac
    
#test 1 parent, 5 child
#python3 func_arb.py --dir=example/func_arbiter --parent pred_inter_chroma_pixel_hls.v --child blockcopy_pp_hls.v interp_horiz_pp_hls.v interp_vert_pp_hls.v interp_horiz_ps_hls.v filterVertical_sp_hls.v --out example/func_arbiter/tb/draft_func_arb_tb2.sv

#test 2 parent, 5 child
#python3 func_arb.py --dir=example/func_arbiter --parent pred_inter_chroma_pixel_hls.v pred_inter_chroma_pixel_hls_dup1.v --child blockcopy_pp_hls.v interp_horiz_pp_hls.v interp_vert_pp_hls.v interp_horiz_ps_hls.v filterVertical_sp_hls.v --out example/func_arbiter/tb/draft_func_arb_tb2.sv
