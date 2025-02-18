#!/usr/bin/env python3

""" Search the HLS report from the directory, extract the information and save to CSV file """

import re
import sys
import os
import argparse
import csv
import logging

from collections import OrderedDict

import colorlog

try:
    from tabulate import tabulate
except ImportError:
    logging.critical('Please use pip to install tabulate library (pip3 install tabulate)')
    exit(-1)

def remove_percentage_pattern(string):
    """ remove the percentage pattern in the string"""
    pattern = r'\(~\d+%\)'
    result = re.sub(pattern, '', string)
    return result

def parse_report(file_path):
    """ parse HLS report to extract the slack time, interval, resource...etc"""
    with open(file_path, 'r', encoding='utf-8') as file:
        colorlog.info(f'open report: {file_path}')
        module_name = None
        field_match = 0
        for line in file:
            line = line.strip()
            if field_match == 0:
                match = re.search(r"Synthesis Summary Report of\s+'([^']*)'", line)
                if not match:
                    continue
                module_name = match.group(1)
                field_match = 1

            elif field_match == 1:
                if 'Slack' in line and 'Interval' in line:
                    field_match = 2

            elif field_match == 2:
                if '-+-' in line:
                    continue
                row = line.split('|')
                #colorlog.debug(item)

                info = [remove_percentage_pattern(item).strip() for item in row[2:15]]
                #info[0] =  info[0].replace('+', '', 1).strip()
                #colorlog.debug(info)
                return module_name, info
    return None, None

def search_hls_report():
    """ main program """
    parser = argparse.ArgumentParser(description='module connection preprocessor: automatic generating verilog code connecting modules')
    parser.add_argument('--dir', metavar='SEARCH_DIR', required=True, type=str, help='search folder')
    parser.add_argument('--csv', metavar='CSV_FILE', required=True, type=str, help='csv_file')
    parser.add_argument('--func', metavar='FUNC_FILTER', default=None, nargs='*', help='matched function')

    args = parser.parse_args()

    #replace \\ to /, then replace duplicate // to /
    search_dir = f'{args.dir}/'.replace('\\', '/').replace('//', '/')

    colorlog.init(console_log = True, file_log = False)

    rpt_summary = OrderedDict()

    if not os.path.isdir(search_dir):
        colorlog.error(f'{search_dir} does not exist')
        sys.exit(-1)

    for root, dirs, files in os.walk(search_dir):
        # Exclude directories that start with a dot
        dirs[:] = [d for d in dirs if not d.startswith('.')]

        for filename in files:
            fullfilepath = os.path.join(root, filename)

            fext = os.path.splitext(filename)[1]

            if fext.endswith('rpt'):
                module_name, module_info = parse_report(fullfilepath)
                if module_name is None:
                    continue

                if args.func is not None and len(args.func) > 0:
                    #if the function name not matched in function filter, skip
                    if not module_name in args.func:
                        continue

                if module_name in rpt_summary:
                    colorlog.error(f'Unexpected error. Duplicate module found {module_name}')
                    sys.exit(-1)
                rpt_summary[module_name] = module_info

    header = ['Modules', 'Issue Type', 'Slack', 'Latency(cycles)', 'Latency(ns)', 'Iteration Latency', 'Interval', 'Trip Count', 'Pipelined', 'BRAM', 'DSP', 'FF', 'LUT', 'URAM']

    rpt_summary_list = [[key] + values for key, values in rpt_summary.items()]
    issue_list = [row for row in rpt_summary_list if row[1] != '-']

    if len(issue_list) > 0:
        print(tabulate(rpt_summary_list, header, tablefmt='grid'))

        colorlog.error(f'{len(issue_list)} items contain issue')
        colorlog.error(tabulate(issue_list, header, tablefmt='grid'))
    else:
        print(tabulate(rpt_summary_list, header, tablefmt='grid'))

    rpt_summary_list.insert(0, header)

    with open(args.csv, 'w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file, quoting=csv.QUOTE_ALL)
        writer.writerows(rpt_summary_list)
        colorlog.info(f'write to csv file {args.csv} successfully')

    if len(issue_list) > 0:
        sys.exit(-1)

if __name__ == "__main__":
    search_hls_report()
