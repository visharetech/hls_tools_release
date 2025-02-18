import re
import os
import subprocess
import argparse
import datetime
import sys
import colorlog

class CPatch:
    PATCH_BEGIN_LINE = '{comment_prefix}Apply the patch from {file}\n'

    def __init__(self):
        """CPatch constructor"""
        self.search_path = ''
        self.patch_filepath = ''
        self.txt_filepath = ''
        self.txtf = None  #file handler
        self.content = []
        self.comment_prefix = '//'

    def exec_cmd(self, cmd):
        """ execute external command """
        cmd = cmd.replace('${path}', self.search_path)
        #cmd_argv = cmd.split()

        # Run a command and capture the output
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

        # Check the return code
        if result.returncode == 0:
            colorlog.info("Command executed successfully!")
            # Print the output
            colorlog.info(result.stdout)
        else:
            colorlog.error("Command failed with error code:", result.returncode)
            # Print the error message
            colorlog.error(result.stderr)
            sys.exit(-1)

    def flush_and_close(self):
        """ flush file content, write back to the file and close"""
        if self.txtf:
            while ( txt_line := self.txtf.readline() ) != '':
                self.content.append(txt_line)

            self.txtf.close()

            with open(self.txt_filepath, 'w') as wfile:
                #get patch file basename
                patch_basename = os.path.basename(self.patch_filepath)
                wfile.write(self.PATCH_BEGIN_LINE.format(comment_prefix=self.comment_prefix, file=patch_basename))
                wfile.writelines(self.content)
            self.txtf = None

    def run(self, patch_filepath, search_path, comment_prefix):
        """ run the patch """
        
        self.comment_prefix = comment_prefix
        
        STATE_NULL      = ''
        STATE_OPEN      = 'open'
        STATE_SEARCH    = 'search'
        STATE_INSERT    = 'insert'
        STATE_REMOVE    = 'remove'
        STATE_NEXT_FILE = 'next_file'
        STATE_CMD       = 'cmd'
        STATE_SKIP      = 'skip'
        
        skip_when_failure = False
        
        if not search_path.endswith('/'):
            search_path += '/'

        self.search_path = search_path
        self.patch_filepath = patch_filepath

        with open(self.patch_filepath, 'r') as file:
            state = ''
            while (line := file.readline()) != '' :
                #colorlog.info(f'line:{line}')
                line = line.strip()

                if len(line) == 0:
                    continue

                if line.startswith('#'):
                    continue

                if state == STATE_SKIP:
                    if line[0:3] != '@fi':
                        continue
                elif state == STATE_NEXT_FILE:
                    #Parse line until reach next file
                    if line[0] == '[' and line[-1] == ']':
                        state = STATE_NULL
                    elif line[0:3] == 'cmd':
                        state = STATE_NULL
                    else:
                        continue

                if line[0] == '[' and line[-1] == ']':
                    state = STATE_OPEN
                elif line[0:3] == '@@@':
                    state = STATE_SEARCH
                elif line[0:3] == '+++':
                    state = STATE_INSERT
                elif line[0:3] == '---':
                    state = STATE_REMOVE
                elif line[0:3] == 'cmd':
                    state = STATE_CMD
                elif line[0:3] == '@if':
                    skip_when_failure = True
                elif line[0:3] == '@fi':
                    skip_when_failure = False

                if state == STATE_OPEN:
                    self.flush_and_close()
                    
                    self.txt_filepath = line[1:-1].strip()
                    self.txt_filepath = self.txt_filepath.replace('${path}', self.search_path)
                    
                    colorlog.info(f'Open file {self.txt_filepath}')

                    self.txtf = open(self.txt_filepath, 'r')

                    patch_basename = os.path.basename(self.patch_filepath)
                    apply_patch_str = self.PATCH_BEGIN_LINE.format(comment_prefix=self.comment_prefix, file=patch_basename)
                    
                    txt_line = self.txtf.readline()

                    #check whether the patch was already applied before
                    if apply_patch_str in txt_line:
                        colorlog.warning(f'{self.txt_filepath} was already overriden')
                        state = STATE_NEXT_FILE
                        self.txtf.close()
                        self.txtf = None
                    else:
                        self.txtf.seek(0)
                    self.content.clear()
                elif state == STATE_CMD:
                    self.flush_and_close()
                    token = line[4:].strip()
                    colorlog.info(f'cmd {token}')
                    self.exec_cmd(token)
                elif state == STATE_INSERT:
                    token = line[4:]
                    colorlog.info(f'insert string {token}')
                    self.content.append(f'{token}\n')
                elif state == STATE_REMOVE or state == STATE_SEARCH:
                    match = False

                    search_pattern = line[4:].strip()
                    operation = state.lower()
                    
                    if ( search_pattern.startswith("r'") and search_pattern[-1] == "'" ) or ( search_pattern.startswith('r"') and search_pattern[-1] == '"'):
                        reg_expr = True
                        search_pattern = search_pattern[2:-1]
                        colorlog.info(f'{operation} regexpr: {search_pattern}')
                    else:
                        reg_expr = False
                        colorlog.info(f'{operation} string: {search_pattern}')

                    txt_pos = self.txtf.tell()
                    tmp_content = []
                    while (txt_line := self.txtf.readline()) != '':
                        strip_txt_line = txt_line.strip()

                        if (reg_expr and re.search(search_pattern, strip_txt_line)) or (not reg_expr and strip_txt_line == search_pattern):
                            if state == STATE_REMOVE:
                                colorlog.info(f'removed {strip_txt_line}')
                                match = True
                                break
                            else:
                                colorlog.info(f'found {strip_txt_line}')
                                tmp_content.append(txt_line)
                                match = True
                                break
                        else:
                            tmp_content.append(txt_line)

                    if not match:
                        if skip_when_failure:
                            print(f'{operation} operation is skip - goto next @fi')
                            
                            self.txtf.seek(txt_pos)
                            
                            state = STATE_SKIP
                            continue
                        else:
                            colorlog.error(f'Cannot find the string {search_pattern}')
                            sys.exit(-1)
                    self.content += tmp_content
                if state != STATE_NEXT_FILE:
                    state = STATE_NULL

            self.flush_and_close()

def autonet_patch():
    """ main program """
    parser = argparse.ArgumentParser(description='modify the text file content by dedicated pattern')
    parser.add_argument('--patch', metavar='patch_file', required=True, type=str, help='patch file')
    parser.add_argument('--path', metavar='path', required=True, type=str, help='search path')
    parser.add_argument('--comment-prefix', metavar='prefix', default='//', type=str, help='comment prefix')

    args = parser.parse_args()

    colorlog.init(file_log=False, console_log=True)

    try:
        patch = CPatch()
        patch.run(args.patch, args.path, args.comment_prefix)
    except FileNotFoundError:
        while True:
            user_input = input('File not found. Do you want to ignore the patch? (y/n):')
            if user_input.lower() == 'n':
                print('failed to apply to patch. system abort')
                sys.exit(-1)
            elif user_input.lower() == 'y':
                sys.exit(0)

if __name__ == "__main__":
    autonet_patch()