::set DEST=..\..\rtl\hls

:: Added decodeBin interface to HLS verilog code if needed
:: python addmem.py [source_file] [module_name] > [destination_file]

::python addmem.py prj\ff_hevc_skip_flag_decode_hls_sol\syn\verilog\ff_hevc_skip_flag_decode_hls.v ff_hevc_skip_flag_decode_hls > %DEST%\ff_hevc_skip_flag_decode_hls.v
::copy %DEST%\ff_hevc_skip_flag_decode_hls.v prj\ff_hevc_skip_flag_decode_hls_sol\syn\verilog\ff_hevc_skip_flag_decode_hls.v

python addmem.py prj\%1_sol\syn\verilog\%1.v %1 > tmp.v
copy tmp.v prj\%1_sol\syn\verilog\%1.v