#export_common_dir: ${export_common_dir}
#export_conn_dir: ${export_conn_dir}
#export_tb_xnet_dir: ${export_tb_xnet_dir}

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

#set XIL_SIM_LIB_PATH "W:/Projects/Vishare/vsRisc5/xilinx_2022_me_10_7_sim_lib"
#set XIL_SIM_LIB_PATH "C:/xilinx_2022_me_10_7_sim_lib"
set XIL_SIM_LIB_PATH "D:/xilinx_2022_me_10_7_sim_lib"




echo $$XIL_SIM_LIB_PATH
vmap xil_defaultlib msim/xil_defaultlib
vmap blk_mem_gen_v8_4_5 $$XIL_SIM_LIB_PATH/blk_mem_gen_v8_4_5/
vmap fifo_generator_v13_2_7 $$XIL_SIM_LIB_PATH/fifo_generator_v13_2_7/
vmap unisims_ver $$XIL_SIM_LIB_PATH/unisims_ver/
vmap unimacro_ver $$XIL_SIM_LIB_PATH/unimacro_ver/
vmap secureip $$XIL_SIM_LIB_PATH/secureip/
vmap xpm $$XIL_SIM_LIB_PATH/xpm/



# Defines (FPGA)
#set define_macro "+define+_VIVADO_"

#+XMEM_LATENCY_1
set XILINX_MODE 1
set ENABLE_SIM 1
set ENABLE_CYCLIC_BANK 1
set define_macro +define+XILINX_MODE=$$XILINX_MODE+ENABLE_SIM=$$ENABLE_SIM+ENABLE_CYCLIC_BANK=$$ENABLE_CYCLIC_BANK

# Include paths
set include_path "+incdir+../rtl+${export_tb_xnet_dir}+../rtl/common+${export_conn_dir}+${export_common_dir}"


# parameters, macro, data types
vlog -64 -incr -lint -sv -work xil_defaultlib $$include_path $$define_macro \
"../rtl/xcache/xcache_param_pkg.sv" \
"../rtl/fill_ref_samples/rtl/fill_ref_samples_mtdma_pkg.sv" \
"${export_conn_dir}/hls_long_tail_pkg.sv" \
"../rtl/cyclicCache/cyclicCache_pkg.sv" \
"../rtl/coherence_cache/coherence_cache_pkg.sv" \
"../rtl/coherence_cache/cache_axi4_arbiter_v1.sv" \
"../rtl/mruCache/mru_pkg.sv" \
"../rtl/xcache/reqMux_v4.sv" \
"../rtl/xcache/cal_bankAdr_v2.sv" \
"../rtl/xcache/bank_filter_v2.sv" \
"../rtl/xcache/scalar_bank_v2.sv" \
"../rtl/xcache/xcache.sv" \
"../rtl/xcache/rfifo.sv" \
"../rtl/xcache/fifo_with_bypass.sv" \
"../rtl/xcache/array_mruCache_bank.sv" \
"../rtl/xcache/cyclic_mruCache_bank.sv" \
"../rtl/mruCache/mruCache.sv" \
"../rtl/mruCache/backend_opt.sv" \
"../rtl/mruCache/speculative_mru.sv" \
"../rtl/mruCache/multi_we_bram.sv" \
"../rtl/mruCache/nway_mem.sv" \
"../rtl/cyclicCache/backend_opt.sv" \
"../rtl/cyclicCache/cyclicCacheCore.sv" \
"../rtl/cyclicCache/cyclicCache.sv" \
"../rtl/cyclicCache/multi_we_bram.sv" \
"../rtl/cyclicCache/nway_mem.sv" \
"${export_conn_dir}/custom_connection.sv" \
"${export_tb_xnet_dir}/dram_axi_sim_model_v2.sv" \
"${export_tb_xnet_dir}/tb_xnet.sv"



############
# Testbench
############
vlog -work xil_defaultlib "glbl.v"

###########################
# Load Design to Simulator
###########################
#Xilinx Simulation
# Run Simulation
vsim +vopt -voptargs="+acc" +nowarn8233 +nowarn8315 +notimingchecks +nospecify \
     -L xil_defaultlib \
     -L blk_mem_gen_v8_4_5 \
     -L fifo_generator_v13_2_7 \
     -L unisims_ver \
     -L unimacro_ver \
     -L secureip \
     -L xpm \
	 -lib xil_defaultlib xil_defaultlib.tb_xnet xil_defaultlib.glbl


##############
# Wave Format
##############
#do wave.do
do wave_xnet.do

################
# Run Simulator
################
run -all














