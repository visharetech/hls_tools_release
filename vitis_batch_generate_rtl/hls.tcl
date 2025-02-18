############################################################
## This file is generated automatically by Vitis HLS.
## Please DO NOT edit it.
## Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
############################################################


if {[file exists "prj/hls.app"]} {
    file delete "prj/hls.app"
}

#close any existed project
close_project

open_project prj
set_top ${func_name}

# set the macro to only test dedicated function
# -DXXX works
# but -DXXX=1 has bug in Xilinx Vitis HLS

set func_name_upper [string toupper $func_name]
set tb_config_prefix "-DTBCONFIG_$func_name_upper"

set cflags "$tb_config_prefix $hls_cflags"

puts "cflags:${cflags}"

foreach file $hls_file {
    if {[string length $cflags] > 0} {
        add_files $file -cflags $cflags
    } else {
        add_files $file
    }
}

foreach file $hls_tb_file {
    if {[string length $cflags] > 0} {
        add_files -tb $file -cflags $cflags
    } else {
        add_files -tb $file
    }
}

if {$decBin_itf == 1} {
	add_files -blackbox decBin_itf.json
}

open_solution -reset "${func_name}_sol" -flow_target vivado
set_part {xcvu19p-fsvb3824-2-e}
create_clock -period 3.3 -name default

#100MHz clock
#create_clock -period 10 -name default

if {$hcache == 1 || $ap_ce == 1} {
	config_interface -clock_enable=true
}

#csim_design

if {$hls_exec == 0} {
    #Only perform csim
    csim_design

} elseif {$hls_exec == 1} {
	# Run Synthesis and Exit
	csynth_design
	
} elseif {$hls_exec == 2} {
	# Run Synthesis, RTL Simulation and Exit
	csynth_design
	cosim_design
} elseif {$hls_exec == 3} { 
	# Run Synthesis, RTL Simulation (wave debug) and Exit
	csynth_design
	cosim_design -wave_debug -trace_level port 
} elseif {$hls_exec == 4} { 
	# Run Synthesis, RTL Simulation, RTL implementation and Exit
	csynth_design
	cosim_design
	export_design
} else {
	# Default is to exit after setup
	csynth_design
}

close_solution
close_project