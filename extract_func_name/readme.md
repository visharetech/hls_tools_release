### Prerequisite
libclang-dev

In Ubuntu,
```console
sudo apt-get install libclang-dev
```

### Description
Add IMPL() macro for each HLS function by using clang library, hls_modified.cpp will be generated.<br>
./hls_add_impl [hls_source_file_path]

```console
clang++ hls_add_impl.cpp -I /usr/lib/llvm-6.0/include/ -L /usr/lib/llvm-6.0/lib/ -lclang -o hls_add_impl
./hls_add_impl hls.cpp
```

Extract function name and its parameter which contains IMPL(xxx) to file<br>
./python3 cli.py --src [function_list.txt] (--func-filter [func_filter]+) --func-list [file] --short-func-list [file] --autonet-pragma [file] --autonet-enum [file] --autonet-cheader [file]

```console
python3 extract_func_name.py \
    --src               hls.cpp                                 \
    --func-filter       calc4x4BlockValueNHT_hls calculateSubCUPartionNHT_hls setNhtSplitVal_hls getNhtSplitVal_hls calcEncOrderStraight_hls getSubCuGeom_1_hls getSubCuGeom_2_hls     \
    --func-list         function_list.txt                       \
    --short-func-list   hls_func_list.txt                       \
    --autonet-pragma    hls_long_tail_instantiate.vh            \
    --autonet-enum      enum_func.info                          \
    --autonet-cheader   hls.h
```