#!/usr/bin/env python3
""" Extract function name and its parameter which contains IMPL(xxx) to file """

import argparse
import json

import colorlog

from collections import OrderedDict
from cparser import cparser

INTEND = ' ' * 4

def save_to_json(filepath, func_list):
    """ save the func_list to json file format """
    with open(filepath, 'w', encoding='utf-8') as fout:
        print(f'write function list to {filepath}')
        json.dump(func_list, fout, indent=4)

def match_keyword_mask(func_impl, keyword_list):
    """ check if a keyword matches a substring """
    idx_list = []
    for keyword in keyword_list:
        match = '1' if keyword in func_impl else '0'
        idx_list.append(match)
    return idx_list

#Generate short function list
def gen_short_func_file_list(filepath, special_arg_keyword, func_list, batch_format=False, ap_ce=False):
    """ generate short function list for hls tcl script """

    col_desc = ['FUNC', 'COPY_RTL', 'AP_CE']
    if special_arg_keyword:
        col_desc.extend(special_arg_keyword)
    
    ap_ce_str = '1' if ap_ce else '0'

    with open(filepath, 'w', encoding='utf-8') as fout:
        print(f'write short function list to {filepath}')

        if special_arg_keyword is not None:
            print(f'special_arg_keyword: {",".join(special_arg_keyword)}')

        if batch_format:
            #write {short_func_name} append with ' 0 1' to file
            content = f'#{",".join(col_desc)}\n'
            content += "#------------------------------------------------------\n"
            for func_name, func_info in func_list.items():
                func_impl = func_info['func_impl']
                visible = func_info['visible']
                is_impl_func = func_info['is_impl_func']

                copy_rtl_str = '1'

                if not is_impl_func and not visible:
                    continue
                if not is_impl_func and visible:
                    #if it is not IMPL function, do not copy_rtl
                    copy_rtl_str = '0'

                match_list = match_keyword_mask(func_impl, special_arg_keyword)
                match_str = ' '.join(match_list)
                if any(m == '1' for m in match_list):
                    print(f'match_keyword: {func_name} - {match_str}')

                if visible:
                    content += f'{func_name:<50} {copy_rtl_str} {ap_ce_str} {match_str}\n'
                else:
                    content += f'#{func_name:<49} {copy_rtl_str} {ap_ce_str} {match_str}\n'
        else:
            #write {short_func_name} to file
            content = ''
            for func_name, func_info in func_list.items():
                visible = func_info[3]
                comment = '' if visible else '//'
                content += f'{comment}{func_name}\n'

        fout.write(content)


def gen_autonet_pragma(filepath, func_list):
    """ generate pragma file for autonet """
    with open(filepath, 'w', encoding='utf-8') as fout:
        print(f'write autonet pragma to {filepath}')

        content = '#pragma AUTONET LOCALPARAM  hls_long_tail_pkg.sv\n\n'

        for func_name, func_info in func_list.items():
            if not func_info['is_impl_func']:
                continue
            visible = func_info['visible']
            comment = '' if visible else '//'
            content += f'{comment}#pragma AUTONET LOADRTL     hls/{func_name}.v\n'

        content += '\n'

        for func_name, func_info in func_list.items():
            if not func_info['is_impl_func']:
                continue
            visible = func_info['visible']
            comment = '' if visible else '//'
            content += f'{comment}#pragma AUTONET INST        {func_name:<50} inst_{func_name}\n'

        content += '''
//no endmodule in this file. Hence, use GEN_VERILOG to generate verilog code
#pragma AUTONET GEN_VERILOG
#pragma AUTONET GEN_TB      gen_hls_long_tail_tb

#pragma AUTONET LOAD_C      load_hls_intf      c/hls.h
#pragma AUTONET GEN_C       gen_hls_ap_call    c/hls_apcall.h
'''

        fout.write(content)

def gen_autonet_enum(filepath, func_list):
    """ generate enum function for autonet """

    content = ''
    with open(filepath, 'w', encoding='utf-8') as fout:
        print(f'write autonet enum function to {filepath}')

        content += f'{INTEND}enum {{\n'

        format_func_list = []
        last_valid_func_name = ''
        for func_name, func_info in func_list.items():
            if not func_info['is_impl_func']:
                continue

            visible = func_info['visible']

            if visible:
                comment = ''
                last_valid_func_name = func_name
            else:
                comment = '//'

            format_func_list.append(f'{INTEND*2}{comment}{func_name},')

        content += '\n'.join(format_func_list)
        content = content.replace(f'{INTEND*2}{last_valid_func_name},', f'{INTEND*2}{last_valid_func_name}')
        content += f'\n{INTEND}}} hls_enum_t;\n'

        content += f'{INTEND}localparam HLS_NUM = {valid_func_num(func_list)};\n'
        
        #extract dcache function
        dcache_func = extract_dcache_func(func_list)
        for idx, func_name in enumerate(dcache_func):
            if idx == 0:
                content += '\n'
            content += f'{INTEND}//Found DCACHE function: {func_name}\n'
            colorlog.info(f'Found DCACHE function: {func_name}')
        content += f'{INTEND}localparam HLS_CACHE = {len(dcache_func)};\n'

        #extract parent function
        parent_func = extract_parent_func(func_list)
        
        for idx, func_name in enumerate(parent_func):
            if idx == 0:
                content += '\n'
            content += f'{INTEND}//Found parent function: {func_name}\n'
            colorlog.info(f'Found parent function: {func_name}')

        content += f'{INTEND}localparam HLS_PARENT = {len(parent_func)};\n'

        #add parent function into localparam HLS_PARENT_IDX
        parent_func_str = ',\n'.join(  [ f'{INTEND*2}{f}' for f in parent_func] )
        content += f'{INTEND}localparam [$clog2(HLS_NUM)-1:0] HLS_PARENT_IDX[HLS_PARENT] = {{\n{parent_func_str}\n{INTEND}}};\n'

        fout.write(content)

def gen_autonet_c_header(filepath, func_list):
    """ generate C header file"""
    with open(filepath, 'w', encoding='utf-8') as fout:
        print(f'write function list to {filepath}')
        impl_list = []
        for func_name, func_info in func_list.items():
            if not func_info['is_impl_func']:
                continue
            visible = func_info['visible']
            func_impl = func_info['func_impl']
            comment = '' if visible else '//'
            impl_list.append(f'{comment}{func_impl};')
        fout.write('\n'.join(impl_list))

def filter_func_info(func_list, func_filter):
    """ mark the function as disable if the function is not exist in func_filter """
    if func_filter is None:
        for func_name, func_info in func_list.items():
            if not func_info['is_impl_func']:
                func_list[func_name]['visible'] = False #mark the function as disable if not a IMPL() function
        return

    for func_name in func_list:
        if func_name not in func_filter:
            func_list[func_name]['visible'] = False #mark it as disable

def valid_func_num(func_list):
    """ Count the number of function where the ['visble'] key is True"""
    return sum(1 for value in func_list.values() if value['visible'] is True)

def extract_dcache_func(func_list):
    """ Extract dcache function where DCACHE_ARG exist in function arguments """
    
    dcache_func = OrderedDict()
    
    for func_name, func_info in func_list.items():
        if not func_info['visible']:
            continue
        func_impl = func_info['func_impl']
        if 'DCACHE_ARG(' in func_impl:
            dcache_func[func_name] = func_info
    return dcache_func

def extract_parent_func(func_list):
    """ Extract parent function where child_cmd_t exist in function arguments """
    
    parent_func = OrderedDict()
    
    for func_name, func_info in func_list.items():
        if not func_info['visible']:
            continue
        para = func_info['para']
        for item in para:
            #child_cmd_t is deprecated, it is replaced by hls::stream<> and dummy_hls_stream
            if item[0].startswith('child_cmd_t') or item[0].startswith('dummy_hls_stream'):
                parent_func[func_name] = func_info
        
    return parent_func

def export_func_name():
    """ main program """
    parser = argparse.ArgumentParser(description='Extract function and its parameters contains IMPL(xxx) macro')
    parser.add_argument('--src', dest='source_file', metavar='[HLS_FILE]', type=str, help='source_file', required=True)
    parser.add_argument('--func-filter', dest='func_filter', metavar='[FUNC_FILTER]', type=str, nargs='*', help='func_filter')
    parser.add_argument('--cflags', dest='cflags', metavar='[CFLAGS]', nargs='*', default = [], help='cflags')
    parser.add_argument('-l', '--clang-path', dest='clang_path', metavar='[CLANG_PATH]', type=str, default=None, help='clang library path')
    parser.add_argument('--json', dest='json_file', metavar='[JSON_FILE]', type=str, help='json_file')
    parser.add_argument('--short-func-list', dest='short_func_list_file', metavar='[SHORT_FUNC_LIST_FILE]', type=str, help='short_func_list_file')
    parser.add_argument('--autonet-pragma', dest='autonet_pragma_file', metavar='[AUTONET_PRAGMA_FILE]', type=str, help='autonet_pragma_file')
    parser.add_argument('--autonet-enum', dest='autonet_enum_func_file', metavar='[AUTONET_ENUM_FUNC_FILE]', type=str, help='autonet_enum_func_file')
    parser.add_argument('--autonet-cheader', dest='autonet_cheader_file', metavar='[AUTONET_C_HEADER_FILE]', type=str, help='autonet_c_header_file')
    parser.add_argument('--arg-keyword', dest='special_arg_keyword', metavar='[SPECIAL_ARG_KEYWORD]', type=str, nargs='*', help='special arg keyword')
    parser.add_argument('--ap-ce', action="store_true", help='enable hls ap_ce signal')

    args = parser.parse_args()

    batch_format = True

    colorlog.init()

    parser = cparser()

    if args.clang_path:
        colorlog.info(f'clang path: {args.clang_path}')
        parser.config(args.clang_path)

    for item in args.cflags:
        colorlog.info(f'cflags: {item}')

    func_list = parser.extract_func(args.source_file, args.cflags)

    filter_func_info(func_list, args.func_filter)

    impl_func = [ func_name for func_name, func_info in func_list.items() if func_info['is_impl_func'] ]
    print(f'Total function num: {len(func_list)},  IMPL() function num: {len(impl_func)}')

    if args.func_filter is not None:
        print(f'valid function num: {valid_func_num(func_list)}')

    print(f"all HLS function with ap_ce: {args.ap_ce:}")

    if args.json_file is not None:
        save_to_json(args.json_file, func_list)

    if args.short_func_list_file is not None:
        gen_short_func_file_list(args.short_func_list_file, args.special_arg_keyword, func_list, batch_format, args.ap_ce)

    if args.autonet_pragma_file is not None:
        gen_autonet_pragma(args.autonet_pragma_file, func_list)

    if args.autonet_enum_func_file is not None:
        gen_autonet_enum(args.autonet_enum_func_file, func_list)

    if args.autonet_cheader_file is not None:
        gen_autonet_c_header(args.autonet_cheader_file, func_list)


if __name__ == "__main__":
    export_func_name()
