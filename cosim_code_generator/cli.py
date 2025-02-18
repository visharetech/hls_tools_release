#!/usr/bin/env python3

""" command line interface for cosim code generator """

import argparse
import colorlog
import re
import sys
import json
import traceback
from config import config
from functions import process_function_head, gen_code_from_template

def main():
    """ main program """
    try:
        parser = argparse.ArgumentParser(description='Cosim Code Generator')
        parser.add_argument('in_file', metavar='JSON_FILE', type=str, help='json file')
        parser.add_argument('out_file', metavar='EXPORT_COSIM_PREFIX', type=str, help='cosim file prefix')
        parser.add_argument('-n', '--count', dest='capture_count', metavar='CAPTURE_COUNT', type=int, default=10000, help='capture count')
        parser.add_argument('--interval', dest='capture_interval', metavar='CAPTURE_INTERVAL', type=int, default=1, help='capture interval')
        args = parser.parse_args()

        colorlog.init(file_log=False, console_log=True)

        func_list = {}

        # Open the json file for reading
        with open(args.in_file, 'r', encoding='utf-8') as fin:
            func_list = json.load(fin)

        capture_code_all = ''
        tb_testcase = ''
        tb_config = '#ifndef {0}\n    #define {0:<40} 0\n#endif\n\n'.format('TBCONFIG_ALL')
        tb_main_body = ''

        parent_func_list = [func_name for func_name, func_info in func_list.items() if 'FUNC_ARBITER_ARG' in func_info['func_impl'] and func_info['visible']]
        parent_func_list_len = len(parent_func_list)
        if parent_func_list_len > 1:
            colorlog.warning('Only support capture data from single parent function')
            for func_name in parent_func_list:
                colorlog.info(func_name)
            #sys.exit(-1)
            config.parent_func = parent_func_list[0]
        elif parent_func_list_len == 1:
            config.parent_func = parent_func_list[0]

        for func_name, func_info in func_list.items():
            is_remark, func_name, capture_code_string, tb_code_string = process_function_head(func_name, func_info)

            if func_name is None:
                continue

            capture_code_all += capture_code_string
            tb_testcase += tb_code_string

            define_macro = f'TBCONFIG_{func_name.upper()}'
            
            if is_remark:
                pass
            else:
                tb_config += f'#ifndef {define_macro}\n    #define {define_macro:<40} 0\n#endif\n\n'
            
            tb_main_body += f'    test_{func_name}();\n'

        print(f'In {args.out_file}.cpp, please add #include "{args.out_file}_config.h"')
        print('Please also rename the implemented function to IMPL(func)')

        # write {out_file}_config.h
        config_file = f'{args.out_file}_config.h'
        with open(config_file, 'w', encoding='utf-8') as outf:
            print(f'Generate {config_file}')
            keyword = {
                'header_def' : args.out_file.upper()
            }
            code = gen_code_from_template('tb_config.tpl', keyword)
            outf.write(code)

        # write {out_file}_capture.cpp
        capture_file = f'{args.out_file}_capture.cpp'
        with open(capture_file, 'w', encoding='utf-8') as outf:
            print(f'Generate {capture_file}')
            keyword = {
                'cap_inc' : args.out_file,
                'cap_testcase' : capture_code_all,
                'capture_count' : args.capture_count,
                'capture_interval' : args.capture_interval,
            }
            code = gen_code_from_template('capture_main.tpl', keyword)
            outf.write(code)

        # write {out_file}_tb.cpp
        tb_file = f'{args.out_file}_tb.cpp'
        with open(tb_file, 'w', encoding='utf-8') as outf:
            print(f'Generate {tb_file}')
            
            keyword = {
                'tb_inc' : args.out_file,
                'tb_config' : tb_config,
                'tb_testcase' : tb_testcase,
                'tb_main_body' : tb_main_body
            }
            
            code = gen_code_from_template('testbench_main.tpl', keyword)
            outf.write(code)
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
    main()
