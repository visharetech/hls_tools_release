### xgen user guide

Feature: Automatic generate the verilog code from xmem_func.csv and custom_connection_tbl.txt. The custom_connection_tbl file contains the bank address of each signal

Usage: pyhon3 xgen.py --xmem-data [xmem_func.csv] --xmem-model [custom_connection_tbl.txt] --export-common-dir [export_commom_folder] --export-conn-dir [export_conn_folder]

```console
python3 xgen.py --xmem-data example/xmem_func.csv --xmem-model example/custom_connection_tbl.txt --export-common-dir example --export-conn-dir example --export-tb-dir example --export-tb-xnet-dir example --export-sim-dir example
```

```mermaid
graph TD;

src([c_source])
dest([custom_connection.sv])

src--> clang_parser\nstruct2v;
src--> vitis_hls_tools;
clang_parser\nstruct2v-- xmem info (var name, type and address offset) --> autonet.gen_xgen_csv;
vitis_hls_tools-- rtl_code --> autonet.parse_rtl;
autonet.parse_rtl -- signal (name, input/output type, width, array_type) --> autonet.gen_xgen_csv;
autonet.gen_xgen_csv-- xmem_func_tb.csv --> xmem_model;
xmem_model -- custom_connection_tbl.txt --> xgen;
autonet.gen_xgen_csv -- xmem_func_tb.csv --> xgen;
xgen --> dest;

```