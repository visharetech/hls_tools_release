# Tutorial

This example demonstrates how to use the hls_tools to:
* Capture the test data
* Batch synthesis
* Run c simulation
* Run cosimulation
* Run xgen to connect these hls functions to xmem

## Environment
* Windows with WSL installed, running Ubuntu 22.04. Vitis HLS is installed on the host (Windows)
* Ubuntu 22.04, Vitis HLS is installed

## Prerequisites package
```console
sudo apt update
sudo apt install build-essential cmake git wget gcc-multilib g++-multilib libclang-dev clang python3 python3-pip nano
```

## Download the hls_tools and related example
```console
#suppose the project is place in /mnt/d/project/
cd /mnt/d/project/
git clone https://github.com/frankvisharegrp/hls_tools.git
```

## Install required package in python venv
```console
cd hls_tools/tutorial_example/hls_tools_script/
chmod +x ./run.sh
pip3 install colorama
pip3 install clang
pip3 install libclang
pip3 install tabulate
```

## Edit the Vitis and Project Path in run.sh
Edit run.sh. Ensure the xilinx_vitis, project_dir and hls_tools_dir are correct.

## Capture test data
Below commands will automatic generate the function to capture the test data (hls_capture.cpp),
It will run the build/linux/make-Makefiles.sh -DCAPTURE_COSIM=1 to capture 10000 test data.
The test data will be placed on hls_tools/vitis_batch_generate_rtl/prj/capture_data for csim or cosim purpose.
```console

./run.sh capture all

# you may select a specific function for capturing
./run.sh capture array_xor

# Append the capture count to explicitly capture 100 test data 
./run.sh capture 100 array_xor
```

## Batch Synthesis
If the vitis hls is installed on Windows, it will invoke the vitis_hls for batch synthesis. 
The synthesis summary (e.g. Latency, LUT, FF count) will be shown on the console.
The detail synthesis result could be found in hls_tools/vitis_batch_generate_rtl/prj/ subdirectory.
```console
./run.sh xhls all

# you may select a specific function for synthesis
./run.sh xhls array_xor
```

## Run Vitis C simulation
It will perform C simulation on Vitis HLS, the test date is loaded from directory hls_tools/vitis_batch_generate_rtl/prj/capture_data which is generated from 'capture' command previously
```console
./run.sh csim all

# you may select a specific function for c simulation
./run.sh csim array_xor
```

## Run Vitis cosimulation
It will perform cosimulation on Vitis HLS, the test date is loaded from directory hls_tools/vitis_batch_generate_rtl/prj/capture_data which is generated from 'capture' command previously.
```console
./run.sh cosim all

# you may select a specific function for cosimulation
./run.sh cosim array_xor
```

## Run Vitis cosimulation with waveform shown
It will perform cosimulation on Vitis HLS. After cosimulation, vitis will be started and show the waveform.
```console
./run.sh cosimwave all

# you may select a specific function for cosimulation
./run.sh cosimwave array_xor
```

## Link all the hls by xgen
After run the xgen script, the RTL will be exported to hls_tools/autonet/export/tutorial_example directory.
You could customize the export directory in run.sh $autonet_export_dir.

```console
./run.sh xgen all

# you may select any specific function for xgen
./run.sh xgen array_xor vector_add
```

## (Optional) Test the example on riscv simulator
```console
# Download the riscv cross-compile toolchain
cd ~
wget -O riscv32-toolchain.tar.gz https://github.com/stnolting/riscv-gcc-prebuilt/releases/download/rv32i-4.0.0/riscv32-unknown-elf.gcc-12.1.0.tar.gz

# Extract the toolchain to /opt/riscv
sudo mkdir -p /opt/riscv
sudo tar -xzf riscv32-toolchain.tar.gz -C /opt/riscv/

# append the PATH to ~/.bashrc
echo 'export PATH=$PATH:/opt/riscv/bin' >> ~/.bashrc
source ~/.bashrc

#check riscv gcc -v is installed successfully
riscv32-unknown-elf-gcc -v

# Build the program and run on the simulator
cd ~/hls_tools/tutorial_example/build/riscv32-sim
source ./make-Makefiles.sh
chmod +x asim
./asim --elfFileName example.elf
```
