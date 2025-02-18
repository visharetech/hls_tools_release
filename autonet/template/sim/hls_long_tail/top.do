#param_list = ${param_list}
#rtl_list = ${rtl_list}
#short_longtail_dir = ${short_longtail_dir}

transcript file ""
transcript file simulation.log

vlib work
vlib msim
vlib msim/xil_defaultlib
vlib blk_mem_gen_v8_4_5
vlib fifo_generator_v13_2_7
vlib unisims_ver
vlib unimacro_ver
vlib secureip
vlib xpm

#Include path
set XIL_SIM_LIB_PATH D:/XMlib/X2022MSE
#set XIL_SIM_LIB_PATH D:/xilinx_2022_me_10_7_sim_lib

set RTL_PATH ../rtl
set TB_PATH ../tb
set include_path "+incdir+$$RTL_PATH+$$RTL_PATH/xcache+$$TB_PATH+$$RTL_PATH/common+$$RTL_PATH/longtail_common_2/+$$RTL_PATH/${short_longtail_dir}/"

#set XMEM_LATENCY_1 1
#set define_macro +define+XMEM_LATENCY_1=$$XMEM_LATENCY_1

set define_macro +define+HLS_LOCAL_DCACHE=1
#set define_macro "+define+HLS_LOCAL_DCACHE=1+HLS_AP_CE_TEST=1+CUSTOM_CONN_RELOAD_TEST=1"

vmap xil_defaultlib msim/xil_defaultlib
vmap blk_mem_gen_v8_4_5         $$XIL_SIM_LIB_PATH/blk_mem_gen_v8_4_5/
vmap fifo_generator_v13_2_7	    $$XIL_SIM_LIB_PATH/fifo_generator_v13_2_7/
vmap unisims_ver                $$XIL_SIM_LIB_PATH/unisims_ver/
vmap unimacro_ver               $$XIL_SIM_LIB_PATH/unimacro_ver/
vmap secureip                   $$XIL_SIM_LIB_PATH/secureip/
vmap xpm                        $$XIL_SIM_LIB_PATH/xpm/


#RTL code
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ${param_list}
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ${rtl_list}

#fill_ref_samples
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/fill_ref_samples/rtl/fill_ref_samples_mtdma_pkg.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/fill_ref_samples/rtl/*.*v 
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/fill_ref_samples/hls/*.*v
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/fill_ref_samples/rtl/axil2xmem/*.*v 

#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/xcache_param_pkg.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/func_arbiter_pkg.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/cyclicCache/cyclicCache_pkg.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/mruCache/mru_pkg.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/coherence_cache/coherence_cache_pkg.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/${short_longtail_dir}/hls_long_tail_pkg.sv

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/${short_longtail_dir}/hls/*.*v

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/longtail_common_2/riscv_ap_ctrl_bus_v1.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/longtail_common_2/riscv_xcache_bus_v1.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/longtail_common_2/hls_long_tail_mem.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/longtail_common_2/hls_long_tail_top_v1.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/longtail_common_2/decBin_itf.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/${short_longtail_dir}/custom_connection.sv

#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xmem/reqMux.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xmem/cal_bankAdr.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xmem/cal_partIdx.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xmem/bank_filter.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xmem/scalar_bank.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xmem/array_bank.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xmem/cyclic_bank.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xmem/xmem.sv

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/reqMux_v4.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/cal_bankAdr_v2.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/bank_filter_v2.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/scalar_bank_v2.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/xcache.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/rfifo.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/fifo_with_bypass.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/array_mruCache_bank.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/xcache/cyclic_mruCache_bank.sv

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/mruCache/mruCache.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/mruCache/backend_opt.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/mruCache/speculative_mru.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/mruCache/multi_we_bram.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/mruCache/nway_mem.sv

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/cyclicCache/backend_opt.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/cyclicCache/cyclicCacheCore.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/cyclicCache/cyclicCache.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/cyclicCache/multi_we_bram.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/cyclicCache/nway_mem.sv

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/coherence_cache/cache_axi4_arbiter_v1.sv

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/call_arbiter_v4.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/copyEngine_v2.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/dpram.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/func_arbiter_v4.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/linked_fifo_v3a.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/mq_rrpop_fifo.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/return_arbiter_v5_2.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/func_arbiter/sync_fifo_v2.sv

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/dma_axiStream_axi4_t/dma_axiStream_axi4_pkg_t.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/dma_axiStream_axi4_t/dma_axi4_to_stream_t.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/dma_axiStream_axi4_t/dma_stream_to_axi4_v2_t.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/dma_axiStream_axi4_t/dma_axiStream_axi4_regs_t.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/dma_axiStream_axi4_t/dma_axiStream_axi4_top_t.sv

vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ./glbl.v

#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/register_fifo_v1.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/${short_longtail_dir}/innerloop.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/${short_longtail_dir}/innerloop_ff_hevc_extract_rbsp_1_hls.sv
#vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/${short_longtail_dir}/innerloop_ff_hevc_extract_rbsp_2_hls.sv

# Check whether innerloop module exist
set files [glob -nocomplain "../rtl/${short_longtail_dir}/innerloop_*.sv"]
if {[llength $$files] > 0} {
    vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/${short_longtail_dir}/innerloop.sv
    vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../rtl/${short_longtail_dir}/innerloop_*.sv
}

#Testbench
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../tb/cache_model.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../tb/dram_axi_sim_model_v2.sv
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path ../tb/tb_top.sv

#Run Simulation
vsim +vopt -voptargs="+acc" +nowarn8233 +nowarn8315 +notimingchecks +nospecify \
     -L xil_defaultlib \
     -L blk_mem_gen_v8_4_5 \
     -L fifo_generator_v13_2_7 \
     -L unisims_ver \
     -L unimacro_ver \
     -L secureip \
     -L xpm \
     -lib xil_defaultlib xil_defaultlib.glbl \
     tb_top

#Wave
do wave.do

#Start run
run 100ms
