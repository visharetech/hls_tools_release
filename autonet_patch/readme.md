## Description
This Python script provides patch integration with search capability, allowing for effective modifications based on the provided patch file.

## Usage
```console
python3 autonet_patch.py --patch openhevc_pragma.patch --path ~/hls_tools/autonet/example/openhevc/
```

## Patch File Syntax
| Syntax                    | Description                                                                                      |
| ------------------------- | -----------------------------------------                                                        |
| #                         | comment                                                                                          |
| ${path}                   | the variable equals to --path argument, can only be used in [filepath] and [command] field only  |
| [filepath]                | destination file                                                                                 |
| @@@ [str\|regexpr]        | search each line incrementally until the string or regular expression is matched                 |
| +++ [str]                 | add the string                                                                                   |
| --- [str\|regexpr]        | search each line incrementally, remove the line if string or regular expression is matched       |
| cmd [command]             | execute command                                                                                  |


## Example

### open file
```console
[${path}/rtl/hls_long_tail_instantiate.vh]
```

### search pattern until the line is matched
```console
@@@ #pragma AUTONET LOCALPARAM  hls_long_tail_pkg.sv
```

### Append the string
```console
+++ //<-- edit manually begin
+++ #pragma AUTONET LOCALPARAM  fill_ref_samples_hls/rtl/fill_ref_samples_mtdma_pkg.sv
+++ #pragma AUTONET LOADRTL     fill_ref_samples_hls/rtl/fill_ref_samples_mtdma_top.sv
+++ #pragma AUTONET LOADRTL     hls/hevc_find_frame_end.sv
+++ //-->
```

### Search and remove the line
```console
--- r'#pragma\s+AUTONET\s+INST\s+ff_hevc_extract_rbsp_1_hls'
--- r'#pragma\s+AUTONET\s+INST\s+ff_hevc_extract_rbsp_2_hls'
--- r'#pragma\s+AUTONET\s+INST\s+ff_hevc_extract_rbsp_2_hls_test'
```

### Execute cp command
```console
cmd cp -v ${path}/rtl/custom/ff_hevc_extract_rbsp_1_hls.v ${path}/rtl/hls/
```

