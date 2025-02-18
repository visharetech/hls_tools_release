#!/usr/bin/env python3

"""
Translate the input Verilog file into an output C header file
"""

import re
import argparse
import sys
import traceback

def enum_func_to_c():
    """ Translate the input Verilog file into an output C header file:
        1. Replace the localparam statements with #define statements
        2. Add a prefix of enum_ to the function names within the enum{} scope
    """
    
    try:
        parser = argparse.ArgumentParser(description='Change enum function in verilog code to C')
        parser.add_argument('-i', dest='verilog_file_path', metavar='[VERILOG_FILE]', type=str, help='verilog_file')
        parser.add_argument('-o', dest='c_header_file_path', metavar='[C_HEADER_FILE]', type=str, help='c_header_file')

        args = parser.parse_args()

        IFDEF_STATEMENT = '#ifndef _HLS_ENUM_H_\n'      \
                        '#define _HLS_ENUM_H_\n\n'

        ENDIF_STATEMENT = '#endif\n'
        
        IGNORE_STATEMENT = 'localparam [$clog2(HLS_NUM)-1:0] HLS_PARENT_IDX[HLS_PARENT]'
        
        with open(args.verilog_file_path, 'r', encoding='utf-8') as file:
            lines = file.readlines()

        with open(args.c_header_file_path, 'w', encoding='utf-8') as file:
            enum_found = False
            
            file.write(IFDEF_STATEMENT)
            
            for line in lines:
                # Use a regular expression to match localparam XXX = YYY; and generate #define XXX YYY
                # For example: localparam HLS_NUM = 39; became #define HLS_NUM 39
                pattern = r'localparam\s+(\w+)\s*=\s*(.*?);'
                replacement = r'#define \1 \2'
                line = re.sub(pattern, replacement, line)

                # Use a regular expression to insert the prefix enum_ string into the functions within the enum {} scope
                # For example: init_intra_neighbors_hls became enum_init_intra_neighbors_hls
                if 'enum {' in line:
                    line = 'typedef enum {\n'
                    enum_found = True
                elif '}' in line and enum_found:
                    enum_found = False
                elif enum_found:
                    line = re.sub(r'(//)?(\S+)', r'\1enum_\2', line)
                elif IGNORE_STATEMENT in line:
                    #ignore the subsequent content if reach IGNORE_STATEMENT
                    break
                file.write(line)

            file.write(ENDIF_STATEMENT)
    except Exception as e:
        # Print exception details
        exception_type = type(e).__name__
        exception_value = str(e)
        exception_traceback = traceback.format_exc()

        print(f"Exception: {exception_type}")
        print(f"Error Message: {exception_value}")
        print("Traceback:\n")
        print(exception_traceback)

        sys.exit(-1)
if __name__ == "__main__":
    enum_func_to_c()
