import os
import sys
import re
import colorlog
import logging

from string import Template
from collections import OrderedDict

try:
    import clang.cindex
except ImportError:
    logging.critical('Please use pip to install clang library (pip3 install clang libclang)')
    sys.exit(-1)


class cparser:
    def __init__(self):
        self.verbose = False

    def enable_verbose(self):
        self.verbose = True

    def config(self, clang_path):
        clang.cindex.Config.set_library_path(clang_path)

    def extract_func(self, filename, clang_args):
        index = clang.cindex.Index.create()
        translation_unit = index.parse(filename, args=clang_args)
        
        func_list = OrderedDict()
        self._traverse_ast(translation_unit.cursor, filename, func_list)
        
        return func_list

    def _get_func_decl(self, cursor):
        # Get the location of the function declaration
        location = cursor.location
        if not location.file:
            return None

        # Get the source code range of the function
        start_offset = cursor.extent.start.offset
        end_offset = cursor.extent.end.offset

        # Extract the source code of the function
        with open(location.file.name, mode='rb') as f:
            f.seek(start_offset)
            content = f.read(end_offset - start_offset)

        code = content.decode()

        code = re.sub(r'//.*', '', code)                        #remove // comment
        code = re.sub(r'/\*.*?\*/', '', code, flags=re.DOTALL)  #remove /**/ comment
        code = code.split('{', 1)[0]                            #remove subsequent string after { 
        code = re.sub(r'\s+', ' ', code)                        #replace multiple space into single space
        code = code.replace('\r', '').replace('\n', '')         #remove newline character
        return code                                             #Finally, it will get IMPL(xxx) extract from the source

    def _traverse_ast(self, node, filter_filename, func_list):
        if node.kind == clang.cindex.CursorKind.FUNCTION_DECL:
            if node.location.file:
                file_name = node.location.file.name
                if file_name != filter_filename:
                    if self.verbose:
                        colorlog.debug(f'skip parse {file_name}')
                    return
        
            func_name = node.spelling
            
            return_type = node.result_type.spelling
            

            raw_func_decl = self._get_func_decl(node)
            if 'IMPL(' in raw_func_decl:
                print(f'IMPL(xxx) Function: {func_name}')
                is_impl_func = True
            else:
                print(f'General Function: {func_name}')
                is_impl_func = False

            param_list = []
            # Print function parameters
            for arg in node.get_arguments():
                param_type = arg.type.spelling
                param_name = arg.spelling

                if self.verbose:
                    colorlog.debug(f'##    parameter:{param_type} : {param_name}')
                param_list.append((param_type, param_name))

            #return the function info as dictionary
            func_list[func_name] = {
                'return_type'   : return_type,
                'para'          : param_list,
                'func_impl'     : raw_func_decl,
                'is_impl_func'  : is_impl_func,
                'visible'       : True
            }

        # Recurse through children nodes
        for child in node.get_children():
            self._traverse_ast(child, filter_filename, func_list)



#if __name__ == "__main__":
#    config('/usr/lib/llvm-6.0/lib')
#    
#    #include_dir = '/mnt/d/Frank/openhevc_hls/openHEVC_accelerator/openHEVC-hevc_rext/source'
#    #cpp_filename = '/mnt/d/Frank/openhevc_hls/openHEVC_accelerator/openHEVC-hevc_rext/source/libavcodec/hevc_hls.cpp'
#
#    include_dir = '/mnt/d/Frank/kvazaar_hls/kvazaar_nht_version/src'
#    cpp_filename = '/mnt/d/Frank/kvazaar_hls/kvazaar_nht_version/src/hls.cpp'
#    
#    args = ['-I' + include_dir]
#    args.append('-DCAPTURE_COSIM')
#    
#    extract_func(source_file, cflags)


