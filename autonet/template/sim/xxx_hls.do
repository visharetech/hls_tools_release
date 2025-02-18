transcript file ""
transcript file simulation.log

vlib work
vlib msim
vlib msim/xil_defaultlib
vlib blk_mem_gen_v8_4_4
vlib fifo_generator_v13_2_5
vlib axis_clock_converter_v1_1_21
vlib axis_infrastructure_v1_1_0
vlib unisims_ver
vlib unimacro_ver
vlib secureip
vlib xpm


#set XIL_SIM_LIB_PATH "D:/xilinx_2019_me_10_7_sim_lib"
#set XIL_SIM_LIB_PATH "D:/xilinx_2020_me_10_7_sim_lib"
#set XIL_SIM_LIB_PATH "D:/XMlib/X20202MSE104"
#set XIL_SIM_LIB_PATH "C:/prjct/xilinx_2020_me_10_7_sim_lib"
set XIL_SIM_LIB_PATH "${simlib_path}"

vmap xil_defaultlib msim/xil_defaultlib
vmap blk_mem_gen_v8_4_4 $$XIL_SIM_LIB_PATH/blk_mem_gen_v8_4_4/
vmap fifo_generator_v13_2_5 $$XIL_SIM_LIB_PATH/fifo_generator_v13_2_5/
vmap axi_clock_converter_v2_1_21 $$XIL_SIM_LIB_PATH/axi_clock_converter_v2_1_21/
vmap axis_infrastructure_v1_1_0 $$XIL_SIM_LIB_PATH/axis_infrastructure_v1_1_0/
vmap unisims_ver $$XIL_SIM_LIB_PATH/unisims_ver/
vmap unimacro_ver $$XIL_SIM_LIB_PATH/unimacro_ver/
vmap secureip $$XIL_SIM_LIB_PATH/secureip/
vmap xpm $$XIL_SIM_LIB_PATH/xpm/

#Compile RTL
set include_path "+incdir+../rtl/common+../rtl/hls+../tb+../rtl/osd/rtl+../rtl/uvf/rtl"
#set define_macro "+define+TESTBENCH_INIT_ROM+AXI4_MEMORY_MODEL+sg25E=1+den1024Mb=1+x16=1"
#set define_macro "+define+_VIVADO_+BOOTUP_START_NO_DELAY+AXI4_MEMORY_MODEL+sg25E=1+den1024Mb=1+x16=1"
#set define_macro "+define+_VIVADO_+TESTBENCH_INIT_ROM+AXI4_MEMORY_MODEL+sg25E=1+den1024Mb=1+x16=1"
#set define_macro "+define+_VIVADO_+AXI4_MEMORY_MODEL+FIFO_LOCAL_DRAM_SIM+sg25E=1+den1024Mb=1+x16=1"
#set define_macro "+define+_VIVADO_+AXI4_MEMORY_MODEL+sg25E=1+den1024Mb=1+x16=1"
set define_macro "+define+_VIVADO_+AXI4_MEMORY_MODEL"



#RTL module
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path \
${rtl_filepath}


#testbench
vlog -incr -lint -sv -work xil_defaultlib $$define_macro $$include_path \
"../sim/glbl.v" \
"../tb/${dut}_tb.sv"


# compile glbl module
vlog -work xil_defaultlib "glbl.v"

# Run Simulation
vsim +vopt -voptargs="+acc" +nowarn8233 +nowarn8315 +notimingchecks +nospecify \
     -L xil_defaultlib \
	 -lib xil_defaultlib xil_defaultlib.top_tb xil_defaultlib.glbl

set NumericStdNoWarnings 1
set StdArithNoWarnings 1


do ${dut}_wave.do

#Start run
#run 1ms
run -all