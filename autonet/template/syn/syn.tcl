set RTL_PATH      "../rtl"

# ###########################
# create project
# ###########################
#create_project hls_long_tail_top -part xc7k325tffg676-2 -force
#create_project hls_long_tail_top -part xc7k410tffg676-2 -force	
create_project hls_long_tail_top -part xcvu19p-fsva3824-2-e -force

# ###########################
# macro
# ###########################
set define_macro [format "HLS_LOCAL_DCACHE=1"]

# ###########################
# include path
# ###########################
set include_path [format "%s %s/xcache %s/common %s/longtail_common_2 %s/longtail_hevc_2" $RTL_PATH $RTL_PATH $RTL_PATH $RTL_PATH $RTL_PATH]


# ###########################
# set property
# ###########################
set_property source_mgmt_mode DisplayOnly [current_project]
set_param project.singleFileAddWarning.Threshold 1000
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
set_property target_language Verilog [current_project]
set_property verilog_define $define_macro [current_fileset]
set_property verilog_define $define_macro [get_filesets sim_1]
set_property include_dirs $include_path [current_fileset]
set_property include_dirs $include_path [get_filesets sim_1]

# ###########################
# Packages
# ###########################
add_files -norecurse $RTL_PATH/xcache/xcache_param_pkg.sv 
add_files -norecurse $RTL_PATH/func_arbiter/func_arbiter_pkg.sv 
add_files -norecurse $RTL_PATH/common/commander_system_pkg.sv 
add_files -norecurse $RTL_PATH/longtail_hevc_2/hls_long_tail_pkg.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/fill_ref_samples_mtdma_pkg.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/mtdma_pkg.sv
add_files -norecurse $RTL_PATH/cyclicCache/cyclicCache_pkg.sv
add_files -norecurse $RTL_PATH/mruCache/mru_pkg.sv
add_files -norecurse $RTL_PATH/coherence_cache/coherence_cache_pkg.sv
add_files -norecurse $RTL_PATH/dma_axiStream_axi4_t/dma_axiStream_axi4_pkg_t.sv

# ###########################
# Source
# ###########################
# fill_ref_samples
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/fill_ref_samples_dataflow_itf.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/fill_ref_samples_mtdma_top.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/fill_ref_samples_mtdma_top_wrp.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/fill_ref_samples_wrp.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/mtdma_v4.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/scan.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/sync_fifo.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/sync_fifo1.sv
add_files -norecurse $RTL_PATH/fill_ref_samples/hls/
add_files -norecurse $RTL_PATH/fill_ref_samples/rtl/axil2xmem/
# HLS
add_files -norecurse $RTL_PATH/longtail_hevc_2/hls/
add_files -norecurse $RTL_PATH/longtail_common_2/riscv_ap_ctrl_bus_v1.sv
add_files -norecurse $RTL_PATH/longtail_common_2/riscv_xcache_bus_v1.sv
add_files -norecurse $RTL_PATH/longtail_common_2/hls_long_tail_mem.sv
add_files -norecurse $RTL_PATH/longtail_common_2/hls_long_tail_top_v1.sv
add_files -norecurse $RTL_PATH/longtail_common_2/decBin_itf.sv
add_files -norecurse $RTL_PATH/longtail_hevc_2/custom_connection.sv
# xcache
add_files -norecurse $RTL_PATH/xcache/reqMux_v4.sv
add_files -norecurse $RTL_PATH/xcache/cal_bankAdr_v2.sv
add_files -norecurse $RTL_PATH/xcache/bank_filter_v2.sv
add_files -norecurse $RTL_PATH/xcache/scalar_bank_v2.sv
add_files -norecurse $RTL_PATH/xcache/xcache.sv
add_files -norecurse $RTL_PATH/xcache/rfifo.sv
add_files -norecurse $RTL_PATH/xcache/fifo_with_bypass.sv
add_files -norecurse $RTL_PATH/xcache/array_mruCache_bank.sv
add_files -norecurse $RTL_PATH/xcache/cyclic_mruCache_bank.sv
add_files -norecurse $RTL_PATH/mruCache/mruCache.sv
add_files -norecurse $RTL_PATH/mruCache/backend_opt.sv
add_files -norecurse $RTL_PATH/mruCache/speculative_mru.sv
add_files -norecurse $RTL_PATH/mruCache/multi_we_bram.sv
add_files -norecurse $RTL_PATH/mruCache/nway_mem.sv
#add_files -norecurse $RTL_PATH/cyclicCache/backend_opt.sv
add_files -norecurse $RTL_PATH/cyclicCache/cyclicCacheCore.sv
add_files -norecurse $RTL_PATH/cyclicCache/cyclicCache.sv
#add_files -norecurse $RTL_PATH/cyclicCache/multi_we_bram.sv
#add_files -norecurse $RTL_PATH/cyclicCache/nway_mem.sv
add_files -norecurse $RTL_PATH/coherence_cache/cache_axi4_arbiter_v1.sv
# func_arb
add_files -norecurse $RTL_PATH/func_arbiter/call_arbiter_v4.sv
add_files -norecurse $RTL_PATH/func_arbiter/copyEngine_v2.sv
add_files -norecurse $RTL_PATH/func_arbiter/dpram.sv
add_files -norecurse $RTL_PATH/func_arbiter/func_arbiter_v4.sv
add_files -norecurse $RTL_PATH/func_arbiter/linked_fifo_v3a.sv
add_files -norecurse $RTL_PATH/func_arbiter/mq_rrpop_fifo.sv
add_files -norecurse $RTL_PATH/func_arbiter/return_arbiter_v5_2.sv
add_files -norecurse $RTL_PATH/func_arbiter/sync_fifo_v2.sv
# axiDMA
add_files -norecurse $RTL_PATH/dma_axiStream_axi4_t/dma_axi4_to_stream_t.sv
add_files -norecurse $RTL_PATH/dma_axiStream_axi4_t/dma_stream_to_axi4_v2_t.sv
add_files -norecurse $RTL_PATH/dma_axiStream_axi4_t/dma_axiStream_axi4_regs_t.sv
add_files -norecurse $RTL_PATH/dma_axiStream_axi4_t/dma_axiStream_axi4_top_t.sv
# innerloop
add_files -norecurse $RTL_PATH/longtail_hevc_2/innerloop.sv
add_files -norecurse $RTL_PATH/longtail_hevc_2/innerloop_ff_hevc_extract_rbsp_1_hls.sv
add_files -norecurse $RTL_PATH/longtail_hevc_2/innerloop_ff_hevc_extract_rbsp_2_hls.sv

# ###########################
# remove unused file
# ###########################
remove_files $RTL_PATH/longtail_hevc_2/hls/decBin_itf.v

# ###########################
#  .v to .sv
# ###########################
set_property file_type "SystemVerilog" [get_files $RTL_PATH/longtail_hevc_2/hls/ff_hevc_extract_rbsp_1_hls.v]
set_property file_type "SystemVerilog" [get_files $RTL_PATH/longtail_hevc_2/hls/ff_hevc_extract_rbsp_2_hls.v]

# ###########################
# add xdc file
# ###########################
read_xdc constraints.xdc

# ###########################
# set top module
# ###########################
set_property top hls_long_tail_top_v1 [current_fileset]

# ###########################
# Suprress warning message
# ###########################
# [Synth 8-5974] attribute "use_dsp48" has been deprecated, please use "use_dsp" instead
# [Synth 8-3936] Found unconnected internal register '' and it is trimmed from '' to '' bits.
# [Synth 8-6014] Unused sequential element was removed.
# [Synth 8-3917] design has port driven by constant 0
# [Synth 8-7129] Port in module is either unconnected or has no load
# [Synth 8-3332] Sequential element is unused and will be removed from module.
# [Synth 8-11067] parameter declared inside package shall be treated as localparam
# [Synth 8-6057] Memory defined in module implemented as Ultra-Ram has no pipeline registers. It is recommended to use pipeline registers to achieve high performance.
# [Synth 8-11357] Potential Runtime issue for 3D-RAM or RAM from Record/Structs for RAM with registers
# [Synth 8-4767] Trying to implement RAM in registers. Block RAM or DRAM implementation is not possible; see log for reasons.
# [Synth 8-7032] RAM have possible Byte Write pattern, however the data width is not multiple of supported byte widths of 8 or 9 .
# [Synth 8-6841] Block RAM originally specified as a Byte Wide Write Enable RAM cannot take advantage of ByteWide feature and is implemented with single write enable per RAM due to following reason.
# [Synth 8-7080] Parallel synthesis criteria is not met
# [XPM_CDC_GRAY: TCL-1000] The source and destination clocks are the same.
#                          This will add unnecessary latency to the design. Please check the design for the following:
#                          1) Manually instantiated XPM_CDC modules: Xilinx recommends that you remove these modules.
#                          2) Xilinx IP that contains XPM_CDC modules: Verify the connections to the IP to determine whether you can safely ignore this message.
# [XPM_CDC_SINGLE: TCL-1000] The source and destination clocks are the same.
#                          This will add unnecessary latency to the design. Please check the design for the following:
#                          1) Manually instantiated XPM_CDC modules: Xilinx recommends that you remove these modules.
#                          2) Xilinx IP that contains XPM_CDC modules: Verify the connections to the IP to determine whether you can safely ignore this message.
set_msg_config -suppress -id {Synth 8-5974}
set_msg_config -suppress -id {Synth 8-3936}
set_msg_config -suppress -id {Synth 8-6014}
set_msg_config -suppress -id {Synth 8-3917}
set_msg_config -suppress -id {Synth 8-7129}
set_msg_config -suppress -id {Synth 8-3332}
set_msg_config -suppress -id {Synth 8-11067}
#set_msg_config -suppress -id {Synth 8-6057}
#set_msg_config -suppress -id {Synth 8-11357}
#set_msg_config -suppress -id {Synth 8-4767}
#set_msg_config -suppress -id {Synth 8-7032}
#set_msg_config -suppress -id {Synth 8-6841}
set_msg_config -suppress -id {Synth 8-7080}
set_msg_config -suppress -id {XPM_CDC_GRAY: TCL-1000}
set_msg_config -suppress -id {XPM_CDC_SINGLE: TCL-1000}
# Warnings related to Xilinx MIG
set_msg_config -suppress -string ddr4_v2_2
set_msg_config -suppress -string ddr4_0
set_msg_config -suppress -string bd_9054

# ###########################
# Start GUI
# ###########################
start_gui
