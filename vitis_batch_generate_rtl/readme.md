### Description
Batch generate HLS functions from Xilinx Vitis HLS

### Usage
The function list is located at hls_func_list.txt. Add # to skip generating the functions.
The included c++ file path is located at hls.cfg.

* Run ./gen_hls.bat, which will batch generate the RTL by Xilinx Vitis HLS
* Run hls_report_2_csv.py, which will search and extract the content from the summary reports in the specified directory, and convert them into csv file.

```console
./gen_hls.bat
python3 hls_report_2_csv.py prj hls_summary.csv
```