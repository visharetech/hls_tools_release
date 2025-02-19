#!/bin/bash

#Please ensure below packages were installed
#sudo apt update
#sudo apt install build-essential cmake git wget gcc-multilib g++-multilib libclang-dev clang python3 python3-pip nano
#pip3 install colorama
#pip3 install clang
#pip3 install libclang
#pip3 install tabulate

#specify the vitis_hls path
xilinx_vitis=/mnt/d/Xilinx/Vitis_HLS/2023.2/bin/vitis_hls

#specify the project path
project_dir=$(dirname $(pwd))
#project_dir=~/hls_tools/tutorial_example

#specify the hls_tools path
hls_tools_dir=$(dirname $(dirname $(pwd)))
#hls_tools_dir=~/hls_tools/

##################################################################################

autonet_prj_dir=${hls_tools_dir}/autonet/workspace/tutorial_example
autonet_export_dir=${hls_tools_dir}/autonet/export/tutorial_example

rtl_dir_name=longtail_example
prj_rtl_conn_dir=${autonet_prj_dir}/rtl/${rtl_dir_name}/
export_rtl_common_dir=${autonet_export_dir}/rtl/longtail_common_2/
export_rtl_conn_dir=${autonet_export_dir}/rtl/${rtl_dir_name}/
export_rtl_tb_dir=${autonet_export_dir}/tb/
export_rtl_tb_xnet_dir=${autonet_export_dir}/tb_xnet
export_sim_dir=${autonet_export_dir}/sim

#XMEM header file (Extract xmem info)
xmem_header_file=${project_dir}/source/xmem.h

#Auto generate hls_enum.h 
enum_header_file=${project_dir}/source/hls_enum.h

#HLS source file (Extract function name and autonet cksum)
hls_src_file=${project_dir}/source/hls.cpp
prefix_src=hls

# tcl script for HLS
hls_file=("source/hls.cpp")
hls_tb_file=("source/hls_tb.cpp")

# gcc build cmd in csim_build_tb()
csim_gcc_build_file='source/hls.cpp source/hls_tb.cpp'

linux_build_dir=${project_dir}/build/linux/
hls_src_dir=$(dirname "$hls_src_file")

##################################################################################

# Set color variables
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
NONE='\e[0m'

prompt_user() {
    #prompt message, return Y or N
    local prompt_message=$1
    local input

    read -p "$prompt_message" input

    while [[ "${input^^}" != "Y" && "${input^^}" != "N" ]]; do
        echo "Invalid input. Please enter 'y' or 'n'."
        read -p "$prompt_message" input
    done

    echo "${input^^}"
}

prompt_exit(){
    read -p "Do you want to continue the task? (y/n) " input

    while [[ "${input^^}" != "Y" && "${input^^}" != "N" ]]; do
        echo "Invalid input. Please enter 'y' or 'n'."
        read -p "Do you want to continue the task? (y/n) " input
    done

    # Check the user's input
    if [[ "${input^^}" == "Y" ]]; then
        echo "Continuing the task..."
        # Add your task commands here
    else
        exit -1
    fi
}

check_system() {
    echo -e "${GREEN}### Check system ###${NONE}"
    local clang_path_argv=""
    if [ -n "$clang_path" ]; then
        clang_path_argv="-l ${clang_path}"
    fi
        
    python3 ${hls_tools_dir}/autonet/struct2v_clang.py --self-check
    if [ $? -ne 0 ]; then
        echo "system check error: struct2v_clang return error"
        echo -e "The system cannot build 32-bit program. Please install the following library to continue\nsudo apt update;  sudo apt install gcc-multilib g++-multilib libclang-dev clang"
        exit -1
    fi

    echo "System check success: clanglib can use 32bit arch (-m32 flag)"
    
    if [ ! -d "${project_dir}" ]; then
        echo "${project_dir} does not exist"
        exit -1
    fi
}

sync_tgcapture() {
    echo -e "${GREEN}### Sync tgcapture ###${NONE}"
    src_dir=$current_dir
    dest_dir=${project_dir}/source/

    # List of source filenames
    source_files=("tgload.h" "tgcapture.h" "tgcapture.cpp")

    # Loop through each source filename
    for filename in "${source_files[@]}"; do
        # Construct the source and destination file paths
        source_file="$src_dir/$filename"
        destination_file="$dest_dir/$filename"

        # Check if the files are different
        if ! cmp -s "$source_file" "$destination_file"; then
            # Perform the copy
            cp "$source_file" "$destination_file"
            echo "File '$filename' copied successfully."
        else
            echo "Files '$filename' are already matching. No copy needed."
        fi
    done
}

build(){
    # Build
    echo -e "${GREEN}### Build ###${NONE}"
    cd ${linux_build_dir}
    #rm ./CMakeCache.txt
    source ./make-Makefiles.sh -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCAPTURE_COSIM=0
    #make
    if [ $? -eq 0 ]; then
        echo "Build successfully."
    else
        echo "Build failed."
        exit -1
    fi
    
    cd -
}

build_for_capture(){
    # Build
    echo -e "${GREEN}### Build (Start capture) ###${NONE}"
    cd ${linux_build_dir}
    #rm ./CMakeCache.txt
    source ./make-Makefiles.sh -DCAPTURE_COSIM=1
    #make
    if [ $? -eq 0 ]; then
        echo "Build (Start Capture) build successfully."
    else
        echo "Build (Start Capture) build failed."
        exit -1
    fi
    
    cd -
}

start_capture(){
    echo -e "${GREEN}### Run program to capture testdata###${NONE}"
    
    local dest_dir1=${autonet_prj_dir}/sim/
    local dest_dir2=${hls_tools_dir}/vitis_batch_generate_rtl/prj/capture_data/
    
    cd ${linux_build_dir}
    #rm ${linux_build_dir}*_output*.bin
    #rm ${linux_build_dir}*_decoder_bin*.dat
    #rm ${dest_dir1}*_output*.bin
    #rm ${dest_dir1}*_decoder_bin*.dat
    #rm ${dest_dir2}*_output*.bin
    
    #run the script under linux_build_dir
    source ./run.sh
    
    mkdir -p ${dest_dir1}
    cp ${linux_build_dir}*_output*.bin ${dest_dir1}
    if [ $? -eq 0 ]; then
        echo "copy testdata to ${dest_dir1} directory successfully."
    else
        echo "copy testdata to ${dest_dir1} directory failed."
        exit -1
    fi

    #copy *_decode_bin.dat if file exists
    if find ${linux_build_dir} -maxdepth 1 -name "*_decode_bin*.dat" | grep -q .; then
        cp ${linux_build_dir}*_decode_bin*.dat ${dest_dir1}
        if [ $? -eq 0 ]; then
            echo "copy decode_bin to ${dest_dir1} directory successfully."
        else
            echo "copy decode_bin to ${dest_dir1} directory failed."
            exit -1
        fi
    fi

    cd -
    
    mkdir -p ${dest_dir2}
    cp ${linux_build_dir}*_output*.bin ${dest_dir2}
    if [ $? -eq 0 ]; then
        echo "copy testdata to ${dest_dir2} directory successfully."
    else
        echo "copy testdata to ${dest_dir2} directory failed."
        exit -1
    fi

    #copy *_decode_bin.dat if file exists
    if find ${linux_build_dir} -maxdepth 1 -name "*_decode_bin*.dat" | grep -q .; then
        cp ${linux_build_dir}*_decode_bin*.dat ${dest_dir2}
        if [ $? -eq 0 ]; then
            echo "copy decode_bin to ${dest_dir2} directory successfully."
        else
            echo "copy decode_bin to ${dest_dir2} directory failed."
            exit -1
        fi
    fi

    cd -
}

clang_get_xmem() {
    #Get xmem
    echo -e "${GREEN}### Get XMEM by clang ###${NONE}"
    
    mkdir -p ${prj_rtl_conn_dir}
    
    gcc -c ${xmem_header_file}
    if [ $? -ne 0 ]; then
        echo "compile ${xmem_header_file} by gcc failed"
        exit -1
    fi
    
    local clang_path_argv=""
    if [ -n "$clang_path" ]; then
        clang_path_argv="-l ${clang_path}"
    fi
        
    python3 ${hls_tools_dir}/autonet/struct2v_clang.py -i ${xmem_header_file} ${clang_path_argv} -o ${prj_rtl_conn_dir}/xmem.info
    
    if [ $? -ne 0 ]; then
        echo "clang_get_xmem failed"
        exit -1
    fi
}

extract_func_name() {
    #Extract function list by using extract_func_name.py
    echo -e "${GREEN}### Extract Function Name ###${NONE}"

    mkdir -p ${prj_rtl_conn_dir}
    mkdir -p ${autonet_prj_dir}/c/
    
    echo -e "${GREEN}Step 1. Extract function number${NONE}"
    
    local func_filter_argv=""
    local prog_argv=""


    if [[ "$1" == --* ]]; then
        prog_argv=$1
        shift
    fi

    if [ $# -ne 0 ]; then
        func_filter_argv="--func-filter $@"
    fi

    local clang_path_argv=""
    if [ -n "$clang_path" ]; then
        clang_path_argv="-l ${clang_path}"
    fi

    #echo "$func_filter_argv"
    
    python3 ${hls_tools_dir}/extract_func_name/extract_func_name.py \
        --src ${hls_src_file}   \
        ${func_filter_argv}     \
        ${clang_path_argv}      \
        --cflags="-I${project_dir}/source"  \
        --json              ${hls_tools_dir}/cosim_code_generator/function_list.json        \
        --short-func-list   ${hls_tools_dir}/vitis_batch_generate_rtl/hls_func_list.txt     \
        --autonet-pragma    ${prj_rtl_conn_dir}/hls_long_tail_instantiate.vh                \
        --autonet-enum      ${prj_rtl_conn_dir}/enum_func.info                              \
        --autonet-cheader   ${autonet_prj_dir}/c/hls.h                                      \
        --arg-keyword       HEVCCONTEXT_ARG DCACHE_ARG                                      \
        ${prog_argv}

    if [ $? -ne 0 ]; then
        echo "Extract function name failed"
        exit -1
    fi
    
    if [ "$option" = "capture" ] || [ "$option" = "csim" ] || [ "$option" = "cosim" ] || [ "$option" = "cosimwave" ]; then
	    echo "*** Skip generate ${enum_header_file} ***"
	    return
    fi
    if [ $# -eq 1 ] && ( [ "$option" = "hls" ] || [ "$option" = "xhls" ] ); then
        echo "*** Skip generate ${enum_header_file} because only 1 HLS function perform synthesis ***"
        return
    fi
    
    echo -e "${GREEN}Step 2. Run update_enum_num.py to update enum function number${NONE}"
    #Update enum function number
    python3 ${hls_tools_dir}/extract_func_name/update_enum_num.py ${prj_rtl_conn_dir}/enum_func.info
    if [ $? -eq 0 ]; then
        echo "run update_enum_num.py successfully."
    else
        echo "run update_enum_num.py failed."
        exit -1
    fi
    
    echo -e "${GREEN}Step 3. Generate ${enum_header_file} ${NONE}"
    python3 ${hls_tools_dir}/extract_func_name/enum_func_to_c.py -i ${prj_rtl_conn_dir}/enum_func.info -o ${enum_header_file}.tmp
    if [ $? -eq 0 ]; then
        echo "run update_enum_num.py successfully."
    else
        echo "run update_enum_num.py failed."
        exit -1
    fi

    cat ${enum_header_file}.tmp

    cmp -s ${enum_header_file}.tmp ${enum_header_file}
    if [ $? -ne 0 ]; then
        local overwrite_enum=$(prompt_user "Could you want to update the enum function header file? The parent function may need to resynthesis if enum id of child function are changed (y/n)")
        if [ "$overwrite_enum" == "Y" ]; then
            cp ${enum_header_file}.tmp ${enum_header_file}
        fi
    fi
}

merge_hls_long_tail_pkg() {
    #Merge hls_long_tail_pkg.vh
    echo -e "${GREEN}### Merge hls_long_tail_pkg.sv ###${NONE}"

    mkdir -p ${prj_rtl_conn_dir}

    python3 ${hls_tools_dir}/autonet/merge_hls_long_tail_pkg.py \
        ${prj_rtl_conn_dir}/xmem.info        \
        ${prj_rtl_conn_dir}/enum_func.info   \
        ${prj_rtl_conn_dir}/hls_long_tail_pkg.sv
}

gen_hls_tcl_script(){
    echo -e "${GREEN}### Generate TCL script for HLS ###${NONE}"

    cd ${hls_tools_dir}/vitis_batch_generate_rtl
    
    local platform="undef"
    local file_path=""
    local hls_exec=$1
    local hls_cflags=${@:2}
    
    mkdir -p ${prj_rtl_conn_dir}/hls
    mkdir -p prj

    if [ ! -e $xilinx_vitis ]; then
        echo "$xilinx_vitis does not exist"
        exit -1
    fi

    # check whether it is running on WSL
    if command -v wslpath > /dev/null 2>&1; then
        echo "Bash is running on WSL"
        platform="wsl"
        
        echo -E "$(wslpath -w $xilinx_vitis) -f ./gen_hls.tcl" > gen_hls.bat
        echo "generated gen_hls.bat"
    else
        platform="linux"
        echo -E "$xilinx_vitis -f ./gen_hls.tcl" > gen_hls.sh
        echo "generated gen_hls.sh"
    fi

    local cfg_file="hls.cfg"
    echo -E "set hls_file {" > "$cfg_file"
    for file in "${hls_file[@]}"
    do
        if [[ "$platform" == "wsl" ]]; then
            #convert to windows path
            file_path=$(wslpath -w $project_dir//$file)
            
            #convert \ to /
            echo -E "    \"$file_path\"" | tr '\\' '/' >> "$cfg_file"
        else
            file_path=$project_dir/$file
            echo -E "    \"$file_path\"" >> "$cfg_file"
        fi
    done
    echo -E "}" >> "$cfg_file"


    echo -E "set hls_tb_file {" >> "$cfg_file"
    for file in "${hls_tb_file[@]}"
    do
        if [[ "$platform" == "wsl" ]]; then
            #convert to windows path
            file_path=$(wslpath -w $project_dir/$file)
            
            #convert \ to /
            echo -E "    \"$file_path\"" | tr '\\' '/' >> "$cfg_file"
        else
            file_path=$project_dir/$file
            echo -E "    \"$file_path\"" >> "$cfg_file"
        fi
    done
    echo -E "}" >> "$cfg_file"

    if [[ "$platform" == "wsl" ]]; then
        #convert to windows path
        file_path=$(wslpath -w ${prj_rtl_conn_dir}/hls)
        
        #convert \ to /
        echo -E "set dest \"$file_path\"" | tr '\\' '/' >> "$cfg_file"

        echo -E "set hls_exec \"$hls_exec\"" >> "$cfg_file"
        
        echo -E "set hls_cflags \"$hls_cflags\"" >> "$cfg_file"
    else
        file_path=${prj_rtl_conn_dir}/hls
        echo -E "set dest \"$file_path\"" >> "$cfg_file"

        echo -E "set hls_exec \"$hls_exec\"" >> "$cfg_file"
        
        echo -E "set hls_cflags \"$hls_cflags\"" >> "$cfg_file"
    fi

    echo "TCL '$cfg_file' created"
    cd -
}

gen_hls(){
    cd ${hls_tools_dir}/vitis_batch_generate_rtl

    local result_log="result.log"

    rm ${result_log}

    if command -v wslpath > /dev/null 2>&1; then
        echo "Bash is running on WSL"
        
        local wsl_current_path=$(wslpath -w .)
        cmd.exe /c "${wsl_current_path}\\gen_hls.bat" | tee ${result_log}
        if [ $? -eq 0 ]; then
            echo "gen HLS successfully."
        else
            echo "gen HLS failed."
            exit -1
        fi
    else
        source ./gen_hls.sh | tee ${result_log}
        if [ $? -eq 0 ]; then
            echo "gen HLS successfully."
        else
            echo "gen HLS failed."
            exit -1
        fi
    fi

    if [ ! -f ${result_log} ]; then
      echo "result.log does not exist."
    fi

    if grep -q "ERROR" ${result_log}; then
        echo "HLS synthesis contains error"
        grep "ERROR" ${result_log}
        prompt_exit
    else
        echo "HLS synthesis run successfully "
    fi
    
    cd -
}

gen_hls_summary(){
    echo -e "${GREEN}### Generate HLS report summary ###${NONE}"
    cd ${hls_tools_dir}/vitis_batch_generate_rtl
    
    local func_filter_argv=""
    
    if [ $# -ne 0 ]; then
        func_filter_argv="--func $@"
    fi

    python3 hls_report_2_csv.py --dir prj --csv hls_summary.csv ${func_filter_argv}
    if [ $? -eq 0 ]; then
        echo "HLS report passed. no issue found."
    else
        echo "HLS report contains issue."
        prompt_exit
    fi
    cd -
}

auto_gen_tb() {
    # auto generate HLS testbench
    echo -e "${GREEN}### Auto Generate Testbench ###${NONE}"
    cd ${hls_tools_dir}/cosim_code_generator
    python3 cli.py function_list.json ${prefix_src} --count ${capture_count} --interval ${capture_interval}
    if [ $? -eq 0 ]; then
        echo "gen cosim function successfully."
    else
        echo "gen cosim function failed."
        exit -1
    fi
    cd -

    # overwrite testbench source
    echo -e "${GREEN}### Copy capture and testbench ###${NONE}"
    cp ${hls_tools_dir}/cosim_code_generator/${prefix_src}_config.h ${hls_src_dir}
    if [ $? -eq 0 ]; then
        echo "${prefix_src}_config copied successfully."
    else
        echo "${prefix_src}_config copy failed."
        exit -1
    fi
    
    cp ${hls_tools_dir}/cosim_code_generator/${prefix_src}_capture.cpp ${hls_src_dir}
    if [ $? -eq 0 ]; then
        echo "${prefix_src}_capture copied successfully."
    else
        echo "${prefix_src}_capture copy failed."
        exit -1
    fi

    cp ${hls_tools_dir}/cosim_code_generator/${prefix_src}_tb.cpp ${hls_src_dir}
    if [ $? -eq 0 ]; then
        echo "${prefix_src}_tb copied successfully."
    else
        echo "${prefix_src}_tb copy failed."
        exit -1
    fi

}

run_autonet(){
    echo -e "${GREEN}### Run autonet###${NONE}"

    cd ${hls_tools_dir}/autonet

    echo -e "${GREEN}Step 1. Run autonet $1 ${NONE}"

    rm -rf ${autonet_export_dir}

    python3 autonet.py ${autonet_prj_dir} ${autonet_export_dir} $1 --rtl-conn-dir ${rtl_dir_name} --cksum-file ${xmem_header_file} ${hls_src_file}
    
    if [ $? -eq 0 ]; then
        echo "run autonet successfully."
    else
        echo "run autonet failed."
        exit -1
    fi
    cd -

    echo -e "${GREEN}Step 2. Copy hls_apcall.h to ${prefix_src}_apcall.h${NONE}"
    cp ${autonet_export_dir}/c/hls_apcall.h ${hls_src_dir}/${prefix_src}_apcall.h
    if [ $? -eq 0 ]; then
        echo "hls_apcall.h copied to ${prefix_src}_apcall.h successfully."
    else
        echo "hls_apcall.h copy to ${hls_src_dir}/${prefix_src}_apcall.h failed."
        exit -1
    fi
    
    echo -e "${GREEN}Step 3. Copy hls_apcall.cpp to ${prefix_src}_apcall.cpp${NONE}"
    cp ${autonet_export_dir}/c/hls_apcall.cpp ${hls_src_dir}/${prefix_src}_apcall.cpp
    if [ $? -eq 0 ]; then
        echo "hls_apcall.cpp copied to ${prefix_src}_apcall.cpp successfully."
    else
        echo "hls_apcall.cpp copy to ${hls_src_dir}/${prefix_src}_apcall.cpp failed."
        exit -1
    fi

    echo -e "${GREEN}Step 4. Copy xmem1_conn.vh${NONE}"
    cp xmem1_conn.vh ${export_rtl_common_dir}
    if [ $? -eq 0 ]; then
        echo "xmem1_conn.vh copied to ${export_rtl_common_dir} successfully."
    else
        echo "xmem1_conn.vh copy to ${export_rtl_common_dir} failed."
        exit -1
    fi

    echo -e "${GREEN}Step 5. Copy hls_dma_instantiate.vh${NONE}"
    cp hls_dma_instantiate.vh ${export_rtl_common_dir}
    if [ $? -eq 0 ]; then
        echo "hls_dma_instantiate.vh copied to ${export_rtl_common_dir} successfully."
    else
        echo "hls_dma_instantiate.vh copy to ${export_rtl_common_dir} failed."
        exit -1
    fi
}

replace_dcache_pattern(){
    echo -e "${GREEN}Replace dcache address pattern${NONE}"
    cd ${hls_tools_dir}/autonet
    python3 ./replace_pattern.py --dir ${autonet_export_dir}/rtl/ --search="dcache_address0 = 'bx;" --replace="dcache_address0 = 0; //by replace_pattern.py"
    
    if [ $? -eq 0 ]; then
        echo "replace_pattern.py success"
    else
        echo "replace_pattern.py failed"
        exit -1
    fi

    cd -
}

print_usage(){
    echo "Usage: ./run.sh [all|xmem|capture|csim|hls|cosim|cosimwave|autonet]"
}

check_and_reorder_xmem(){
    echo -e "${GREEN}check xmem${NONE}"
    python3 ${hls_tools_dir}/xgen/check_xmem.py --xmem-conf xmem_config.txt --xmem-data ${export_rtl_conn_dir}/xmem_func.csv
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "check_xmem success"
    elif [ $exit_code -eq $((0xE1)) ]; then
        echo "check_xmem return 0xE1, reorder xmem"

        local clang_path_argv=""
        if [ -n "$clang_path" ]; then
            clang_path_argv="-l ${clang_path}"
        fi

        #execute check_xmem.py
        python3 ${hls_tools_dir}/xgen/reorder_xmem.py ${clang_path_argv} --xmem-conf xmem_config.txt --src ${xmem_header_file} --csv ${export_rtl_conn_dir}/xmem_func.csv -o ${xmem_header_file}

        if [ $? -eq 0 ]; then
            echo "reorder the xmem element in ${xmem_header_file}, please review the xmem.h source and run xgen again"
            local gen_xmem_model=$(prompt_user "After review, generate xmem model with the modified xmem.h? (y/n)")
            if [ "$gen_xmem_model" == "N" ]; then
                exit 0
            fi
            build
            clang_get_xmem
            merge_hls_long_tail_pkg
            run_autonet --conn-handler=xgen
            replace_dcache_pattern
        else
            exit -1
        fi
    else
        echo "xgen return failed" 
        exit -1
    fi
}

run_xmem_model(){
    echo -e "${GREEN}Step 1. Run xmem model${NONE}"
    local current_dir=$(pwd)
    chmod +x ${hls_tools_dir}/xgen/xmem_model
    ${hls_tools_dir}/xgen/xmem_model  ${export_rtl_conn_dir}/xmem_func.csv               \
                                      ${export_rtl_conn_dir}/custom_connection_tbl.txt   \
                                      ${export_rtl_conn_dir}/xadr.txt                    \
                                      ${export_rtl_conn_dir}/bank_mux_params.svh         \
                                      ${export_rtl_conn_dir}/hw_xmem_info.dat            \
                                      ${export_rtl_conn_dir}/xmem_param.h                \
                                      ${export_rtl_conn_dir}/xmem_param.vh               \
                                      ${export_rtl_conn_dir}/accessFunc.txt              \
                                      ${current_dir}/xmem_config.txt

    if [ $? -ne 0 ]; then
        echo "run xmem model failed"
        exit -1
    fi
    
    echo -e "${GREEN}Step 2. Copy xmem_model generated files to sim directory${NONE}"
    cp ${export_rtl_conn_dir}/custom_connection_tbl.txt \
       ${export_rtl_conn_dir}/xadr.txt                  \
       ${export_rtl_conn_dir}/hw_xmem_info.dat          \
       ${autonet_export_dir}/sim/
    if [ $? -eq 0 ]; then
        echo "copy xmem_model generated files to ${autonet_export_dir}/sim/ directory successfully."
    else
        echo "copy xmem_model generated files to ${autonet_export_dir}/sim/ directory failed."
        exit -1
    fi
    
    echo -e "${GREEN}Step 3. Copy xmem_param.h to source directory${NONE}"
    cp ${export_rtl_conn_dir}/xmem_param.h \
       ${project_dir}/source/
    if [ $? -eq 0 ]; then
        echo "copy xmem_param.h to ${project_dir}/source/ directory successfully."
    else
        echo "copy xmem_param.h to ${project_dir}/source/ directory failed."
        exit -1
    fi
}

run_xgen(){
    echo -e "${GREEN}Step 1. Run xgen to generate xmem rtl${NONE}"

    mkdir -p ${export_rtl_tb_xnet_dir}
    mkdir -p ${export_sim_dir}

    python3 ${hls_tools_dir}/xgen/xgen.py --xmem-conf xmem_config.txt                                       \
                                          --xmem-data ${export_rtl_conn_dir}/xmem_func.csv                  \
                                          --xmem-model  ${export_rtl_conn_dir}/custom_connection_tbl.txt    \
                                          --export-common-dir  ${export_rtl_common_dir}                     \
                                          --export-conn-dir    ${export_rtl_conn_dir}                       \
                                          --export-tb-dir      ${export_rtl_tb_dir}                         \
                                          --export-tb-xnet-dir ${export_rtl_tb_xnet_dir}                    \
                                          --export-sim-dir     ${export_sim_dir}

    if [ $? -eq 0 ]; then
        echo "xgen success"
    elif [ $? -eq $((0xE1)) ]; then
        echo "xgen return 0xE1, reorder xmem"
        echo "please review the xmem.h source code and run xgen again"
        exit -1
    else
        echo "xgen return failed" 
        exit -1
    fi
}

handle_segfault() {
    echo "Segmentation fault detected!"
    # Perform additional cleanup or error-handling tasks here
    exit 139  # Exit the script with a non-zero status
}

#### PROGARM START ####

# Trap the SIGSEGV signal and call the handle_segfault function
trap 'handle_segfault' SIGSEGV

echo "HLS tools directory: $hls_tools_dir"

# Check arguments

if [ $# -lt 1 ]; then
    echo -e "${RED}Argument is missing. run all the tasks${NONE}"
    option="all"
elif [ "$1" = "help" ]; then
    print_usage
    exit 0
elif [ "$1" = "all" ] || [ "$1" = "xall" ] || [ "$1" = "xmem" ] || [ "$1" = "capture" ] || [ "$1" = "csim" ] || [ "$1" = "hls" ] || [ "$1" = "xhls" ] || [ "$1" = "cosim" ] || [ "$1" = "cosimwave" ] || [ "$1" = "autonet" ] || [ "$1" = "xgen" ]; then
    option=$1
else
    echo -e "${RED}Invalid argument${NONE}"
    print_usage
    exit -1
fi

capture_count=10000
if [ "$option" = "capture" ] && [[ $2 =~ ^[0-9]+$ ]]; then   #check if the argument is a number
    capture_count=$2
    shift
fi

capture_interval=1
if [ "$option" = "capture" ] && [[ $2 =~ ^[0-9]+$ ]]; then   #check if the argument is a number
    capture_interval=$2
    shift
fi


if [ $# -ge 2 ]; then
    func=${@:2}
fi

if [ "$func" = "all" ]; then
    func=""
fi

if [ -f "$func" ]; then
    echo "Recognize $func is a file to store the function list"
    # Use sed to skip the line starts with # in the file
    # Use tr to convert newline to space
    func=$(sed '/^#/d' "$func" | tr -s '\r\n' ' ')
fi

if [ "$option" = "all" ] || [ "$1" = "xall" ]; then
    sel_synth_only=$(prompt_user "Cosimulation takes lots of time. Could you just run HLS synthesis only? (y/n)")
fi

# xhls command set all hls function module with ap_ce signal
extract_func_name_argv=""
gen_hls_cflags=""
if [ "$option" = "xhls" ] || [ "$option" = "xgen" ]; then
    extract_func_name_argv="--ap-ce"
    gen_hls_cflags=" -DXMEM_ARRAY_LATENCY_3=1"
fi

### Run the task ###
check_system
#sync_tgcapture
extract_func_name $extract_func_name_argv $func

if [ "$option" = "all" ] || [ "$option" = "xall" ] || [ "$option" = "capture" ] || [ "$option" = "csim" ] || [ "$option" = "hls" ] || [ "$option" = "xhls" ] || [ "$option" = "cosim" ] || [ "$option" = "cosimwave" ]; then
    auto_gen_tb
fi

if [ "$option" = "all" ] || [ "$option" = "xall" ] || [ "$option" = "xmem" ] || [ "$option" = "autonet" ] || [ "$option" = "xgen" ]; then
    build
    clang_get_xmem    #extract the xmem info by clang
    merge_hls_long_tail_pkg
fi

if [ "$option" = "all" ] || [ "$option" = "xall" ] || [ "$option" = "capture" ]; then
    build_for_capture
    start_capture
fi

if [ "$option" = "all" ] || [ "$option" = "xall" ] || [ "$option" = "csim" ]; then
    #ap_int<?> is specialized for Vitis HLS, cannot built from native g++ compiler.
    #Use cosim to verify.
    gen_hls_tcl_script 0 $gen_hls_cflags
    gen_hls
fi

if [ "$sel_synth_only" == "Y" ] || [ "$option" = "hls" ] || [ "$option" = "xhls" ]; then
    #$hls_exec set to 1 to perform synthesis only
    gen_hls_tcl_script 1 $gen_hls_cflags
    gen_hls
    gen_hls_summary $func
fi

if [ "$sel_synth_only" == "N" ] || [ "$option" = "cosim" ]; then
    #$hls_exec set to 2 to perform synthesis and cosim
    gen_hls_tcl_script 2 $gen_hls_cflags
    gen_hls
    gen_hls_summary $func
fi

if [ "$sel_synth_only" == "N" ] || [ "$option" = "cosimwave" ]; then
    #$hls_exec set to 3 to perform synthesis and cosim (wave viewer)
    gen_hls_tcl_script 3 $gen_hls_cflags
    gen_hls
    gen_hls_summary $func
fi

if [ "$option" = "all" ] || [ "$option" = "autonet" ]; then
    run_autonet --conn-handler=hls
    replace_dcache_pattern
fi

if [ "$option" = "xall" ] || [ "$option" = "xgen" ]; then
    run_autonet --conn-handler=xgen
    replace_dcache_pattern
    check_and_reorder_xmem
    run_xmem_model
    run_xgen
fi

exit 0
