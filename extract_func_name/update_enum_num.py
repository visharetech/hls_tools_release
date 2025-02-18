#!/usr/bin/env python3

'''
Update enum number in the file hls_long_tail_pkg.sv
'''

import sys
import argparse
import re

def is_valid_enum_func(line):
    line = line.strip()
    if len(line) == 0:
        return False
    if line.startswith('//'):
        return False
    return True

def update_enum_number():
    """ main program """
    parser = argparse.ArgumentParser(description='module connection preprocessor: automatic generating verilog code connecting modules')
    parser.add_argument('file', metavar='file', type=str, help='search folder')

    args = parser.parse_args()

    STATE_INIT = 0
    STATE_FOUND_PKG = 1
    STATE_REPLACE_ENUM = 2

    state = STATE_INIT
    enum_count = 0
    file_content = []

    try:
        with open(args.file, 'r', encoding='utf-8') as file:
            for line in file:
                if state == STATE_INIT:
                    if 'enum {' in line:
                        state = STATE_FOUND_PKG
                elif state == STATE_FOUND_PKG:
                    if '} hls_enum_t;' in line:
                        state = STATE_REPLACE_ENUM
                    elif is_valid_enum_func(line):
                        enum_count += 1
                elif state == STATE_REPLACE_ENUM:
                    if 'localparam HLS_NUM = ' in line:
                        line = re.sub(r'localparam HLS_NUM\s*=\s*(\d+)', f'localparam HLS_NUM = {enum_count}', line)

                file_content.append(line)

        print(f'enum hls_enum_t count: {enum_count}')

        with open(args.file, 'w', encoding='utf-8') as file:
            print(f'Update enum count in {args.file}')
            for line in file_content:
                file.write(f'{line}')

    except FileNotFoundError:
        print("File not found.")
        sys.exit(-1)
    except IOError:
        print("Error while reading the file.")
        sys.exit(-1)


if __name__ == "__main__":
    update_enum_number()
