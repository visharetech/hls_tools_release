### Required external module
pip3 install colorama<br>
pip3 install tabulate<br>

### AUTONET user guide
Feature: Automatic generate verilog code and ModelSim testbench according to the #pragma AUTONET statement.

- Parse the localparam inside the verilog file
```
#pragma AUTONET LOCALPARAM hls_long_tail_pkg.sv
```

- Parse the RTL module
```
#pragma AUTONET LOADRTL a_hls.sv
```

- Create the instance from the verilog module
```
#pragma AUTONET INST a_hls inst_a
```

- Create the instance from the innerloop wrapper module. support option: pipeline=0 or 1 (default:1)
it will insert verilog code from {module_name}.innerloop.sv to corresponding testbench section.
Please check example/create_conn2/rtl/ff_hevc_extract_rbsp_1_hls.innerloop.sv for more information
```
#pragma AUTONET INNERLOOP a_hls inst_innerloop_a pipeline=1
```

- Override the connection node
```
#pragma AUTONET CONNECT a_inst.c b_inst.in AS x
```

- Gen verilog code here (optional. if missing this command, it will generate the verilog code before the endmodule statement)
```
#pragma AUTONET GEN_VERILOG
```

- Gen testbench (gen_hls_long_tail module will generate related testbench)
```
#pragma AUTONET GEN_TB gen_hls_long_tail
```

- Load C file, load_hls_intf module will parse [filepath], extract the C function declaration in the file. 
```
#pragma AUTONET LOAD_C load_hls_intf [filepath]
```

- Gen C file, gen_hls_ap_call module will generate C ap_call function to [filepath]
```
#pragma AUTONET GEN_C gen_hls_ap_call [filepath]
```

### Example
In example/create_conn2/hls_long_tail_instantiate.vh
```
#pragma AUTONET LOCALPARAM  hls_long_tail_pkg.sv
#pragma AUTONET LOADRTL     ff_hevc_get_sub_cu_zscan_id_hls.v
#pragma AUTONET LOADRTL     ff_hevc_set_neighbour_available_hls.v
#pragma AUTONET INST        ff_hevc_get_sub_cu_zscan_id_hls     inst_ff_hevc_get_sub_cu_zscan_id_hls
#pragma AUTONET INST        ff_hevc_set_neighbour_available_hls inst_ff_hevc_set_neighbour_available_hls
#pragma AUTONET GEN_TB      gen_hls_long_tail_tb
#pragma AUTONET LOAD_C      load_hls_intf                       c/hls.h
#pragma AUTONET GEN_C       gen_hls_ap_call                     c/hls_apcall.h
```

```console
python3 autonet.py example/create_conn2 export
```
It will search all verilog files in example/create_conn2, lookup the #pragma autonet keyword, generate verilog and related ModelSim testbench in export folder.
The #pragma LOAD_C and GEN_C statement will extract the function declaration in c/hls.h and generate relative C ap_call(...) in hls_apcall.cpp.

_________________

### struct2v User Guide
Feature: Automatic generate the xmem info.
It will automatic generate the localparam information (width, offset, depth) from the C struct.

Load by GDB
1. Load my_exec_program from GDB. 
2. Load the python script to parse the xmem_t struct.
```console
gdb my_exec_program
source struct2v.py
b main
r
struct2v xmem_t
```

it will parse the struct and generate the verilog file (struct_def.sv) at the same folder path.

Please see the example/struct2v for more information

_________________

### Appendix
#### Signal Type Decision
It will assign the signals into different categories (signal type) based on the following criteria.
After that, it will generate verilog code based on existed template.

 Signal Type | Criteria
--- | ---
ap_ctrl                                 | var equals to <br>ap_clk, ap_rst, ap_start, ap_done, ap_idle, ap_ready,<br>clk, sysclk, sys_clk, rd_clk, wr_clk,<br>rstn, rst_n, areset, reset, resetn, ap_rst_n
special_case                            | var starts with / match get_inline_mem, hcache, dataflow, bNeighborFlags
xmem_out                                | var declared in xmem and output mode
xmem_out_vld                            | var declared in xmem, ends with _vld and output port
xmem_in                                 | var declared in xmem and input mode
ap_memory_xmem                          | var declared in xmem ends with _addressX, weX, ceX, _dX, _qX
axi_stream_in / axi_stream_out          | var ends with _TDATA, _TVALID, _TREADY, _TUSER, _TKEEP..etc
in (ap_call input argument, maximum 8)  | var does not declare in xmem, input port 
ap_call return                          | var name is equals to ap_return
(invalid type, show error)              | var does not declare in xmem, output port
