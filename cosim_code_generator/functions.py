#!/usr/bin/env python3

""" core implementation for cosim code generator """

import re
import sys
from string import Template
from collections import OrderedDict
from config import config
import colorlog

INTEND = ' ' * 4
DYNAMIC_ARRAY_THRESHOLD = 10*1024*1024

def gen_code_from_template(template_file, keyword):
    """ generate code from template file """
    with open(template_file, 'r', encoding='utf-8') as file:
        template_string = file.read()

    template = Template(template_string)
    return template.substitute(keyword)

def extract_para_info(para_info, func_impl, func_name):
    """ extract the parameter information as dict from para_info
        override dedicated code in capture function: ov_cap_xxx
        override dedicated code in testbench function: ov_tb_xxx 
    """

    argvs = OrderedDict()

    for arg in para_info:
        var_type = arg[0]
        var_name = arg[1]
        #print(f'{var_type}, {var_name}')

        #handle special case - openhevc_cabac
        if var_type == 'HEVCContext *':
            argvs[var_name] = {
                'skip_capture'          : True,
                'category'        : 'openhevc_cabac',
                'var_type'        :  var_type,
                'ov_cap_top'      : 'HEVCCONTEXT_ARG',
                'ov_cap_init'     : f'    CABAC_LOG_START("{func_name}_decode_bin.dat")\n',
                'ov_cap_deinit'   : '\n    CABAC_LOG_END()\n',
                'ov_cap_call'     : 'HEVCCONTEXT_ARG_CALL',
                'ov_tb_call'      : 'HEVCCONTEXT_ARG_CALL'
            }
            continue

        #handle special case - kvazaar_cabac
        if var_type == 'cabac_data_t *const':
            argvs[var_name] = {
                'skip_capture'          : True,
                'category'              : 'kvazaar_cabac',
                'var_type'              : var_type,
                'ov_cap_top'      : 'CABAC_DATA_ARG',
                'ov_cap_call'     : 'CABAC_DATA_ARG_CALL',
                'ov_tb_call'      : 'CABAC_DATA_ARG_CALL'
            }
            continue

        if var_type == 'xmem_t *':
            argvs[var_name] = {
                'skip_capture' : True,
                'category'     : 'xmem',
                'var_type'     : var_type,
                'ov_cap_call'  : var_name,
                'ov_tb_call'   : f'&{var_name}',
            }
            continue

        pattern = r'child_cmd_t *'
        if match := re.search(pattern, var_type):
            #extract the array number of child_cmd_t [N]
            argvs[var_name] = {
                'skip_capture' : True,
                'category'     : 'pointer',
                'var_type'     : var_type
            }
            continue

        if var_name == 'ret' or var_name == 'ret_rdy':
            argvs[var_name] = {
                'skip_capture' : True,
                'category'     : 'pointer',
                'var_type'      : var_type
            }
            continue


        #handle special case - dcache
        if var_type == 'uintptr_t' and var_name.startswith('dc_') and var_name.endswith('_p'):
            chop_var_name = var_name[3:-2]
            pattern = r'DCACHE_ARG\((.*?)\s*,\s*(.*?)\s*,\s*(.*?)\)'
            #print(pattern)
            #print(func_impl)
            matches = re.findall(pattern, func_impl)

            found = False
            for match in matches:
                if match[1] == chop_var_name:
                    arr_type = match[0]
                    arr_num = match[2]
                    found = True
                    break
            if not found:
                print(f'cannot parse the DCACHE_ARG(...{chop_var_name}...)')
                sys.exit(-1)

            colorlog.debug(f'dcache detected: {arr_type} {chop_var_name}[{arr_num}]')
            argvs[var_name] = {
                'category'              : 'dcache_arg',
                'var_type'              : 'uintptr_t',
                'arr'                   : f'(sizeof({arr_type}) * ({arr_num}) + 3) / sizeof(uint32_t)',
                'ov_cap_top'            : f'DCACHE_ARG({arr_type},{chop_var_name},{arr_num})',
                'ov_cap_call'           : f'DCACHE_ARG_FORWARD({chop_var_name})',
                'ov_cap_tgopen'         : f'dc_{chop_var_name},{var_name}',
                'ov_cap_before_call'    : f'dc_{chop_var_name},(sizeof({arr_type}) * ({arr_num}) + 3) / sizeof(uint32_t),{var_name}',
                'ov_cap_after_call'     : f'dc_{chop_var_name},(sizeof({arr_type}) * ({arr_num}) + 3) / sizeof(uint32_t),{var_name}',
                'ov_tb_tgpop'           : f'dc_{chop_var_name},{var_name}',
                'ov_tb_call'            : f'DCACHE_ARG_FORWARD({chop_var_name})',
                'ov_tb_tgcheck'         : f'dc_{chop_var_name}'
            }
            continue

        #handle special case - dcache
        if var_name == 'dcache':
            argvs[var_name] = {
                'skip_capture'  : True,
                'category'      : 'dcache',
                'var_type'      : var_type,
                'arr'           : 'DCACHE_SIZE',
                'ov_cap_top'    : 'uint32_t dcache[DCACHE_SIZE]'
            }
            continue

        #handle special case - bNeighborFlags_t
        if var_type == 'bNeighborFlags_t':
            argvs[var_name] = {
                'category'                  : 'array',
                'var_type'                  : 'uint32_t',
                'arr'                       : '3',
                'ov_tb_before_call'         : f'{INTEND}ap_uint<65> ap_uint_{var_name};//special case\n'
                                              f'{INTEND}array_to_ap_uint({var_name}, 3, ap_uint_{var_name});\n',
                'ov_tb_call'                : f'ap_uint_{var_name}',
                'ov_tb_after_call'          : f'{INTEND*2}ap_uint_to_array(ap_uint_{var_name}, {var_name}, 3);\n'
            }
            continue

        if '[' in var_type:
            arrnum = re.findall(r'\[([^]]+)\]', var_type)
            #remove const in arrays argv[1] but keep const in argvs
            
            if len(arrnum) == 1 and int(arrnum[0]) >= DYNAMIC_ARRAY_THRESHOLD:
                category = 'dynamic_array'
            else:
                category = 'array'

            var_type_no_bracket = var_type.split('[')[0].strip()

            argvs[var_name] = {
                'category'      : category,
                'var_type'      : var_type_no_bracket,
                'arr'           : arrnum
            }

            if category == 'dynamic_array':
                argvs[var_name]['ov_tb_before_call'] = f'{INTEND*2}tgPop({var_name}_ptr, count);\n'
        elif '*' in var_type:
            argvs[var_name] = {
                'category'      : 'pointer',
                'var_type'      : var_type
            }
        else:
            argvs[var_name] = {
                'category'      : 'input',
                'var_type'      : var_type
            }

    return argvs


def override_generate_content(content):
    """ gen_capture_func(...) and gen_tb_func(...) will call this function at the end so that we can override the generated content
    Below code will eliminate the comma after HEVCCONTEXT_ARG and CABAC_DATA_ARG """

    cabac_arg = ('HEVCCONTEXT_ARG', 'CABAC_DATA_ARG')
    cabac_arg_call = ('HEVCCONTEXT_ARG_CALL', 'CABAC_DATA_ARG_CALL')
    content['function_name'] = eliminate_comma(content['function_name'], cabac_arg)

    if 'p_list_string' in content:
        content['p_list_string'] = eliminate_comma(content['p_list_string'], cabac_arg)

    if 'function_call_string' in content:
        content['function_call_string'] = eliminate_comma(content['function_call_string'], cabac_arg_call)

    if 'skip_capture_code' in content:
        content['skip_capture_code'] = eliminate_comma(content['skip_capture_code'], cabac_arg_call)

    if 'parent_func_postfix' in content:
        content['parent_func_postfix'] = eliminate_comma(content['parent_func_postfix'], cabac_arg_call)


def calc_array_size(array_element):
    """ calc array length from 1d or 2d array """

    #total_size = 1
    #for num in array_element:
    #    total_size *= int(num)
    #return total_size

    if len(array_element) == 1:
        #1d array
        return array_element[0]

    if len(array_element) == 2:
        #tgcapture - 2d array still return array_element[0]
        return array_element[0]

    print('3d array Not test')
    return array_element[0]

def array_add_bracket(array_element):
    """ add bracket in each array index """
    return "".join([f'[{num}]' for num in array_element])

def chop_argvname(argv):
    """ chop the argument (remove _i and _o suffix str in argv) """
    argv = argv.replace('const ', '')
    if argv.endswith('_o') or argv.endswith('_i'):
        return argv[:-2]
    return argv

def check_chopargv_exist(name, argv_list):
    """ check whether the chopped signame is matched in group """
    chopname = chop_argvname(name)
    for argv in argv_list:
        if chopname == chop_argvname(argv):
            return True

    return False

def eliminate_comma(string, keyword_list):
    """ reduce extra comma if keyword is matched e.g. HEVCCONTEXT_ARG_CALL, to HEVCCONTEXT_ARG_CALL """
    for keyword in keyword_list:
        if keyword in string:
            string = string.replace(f'{keyword},', f'{keyword} ')
    return string

def remove_const_and_volatile(string : str):
    return string.replace('const ', '').replace('volatile ', '')

def gen_capture_func(is_remark, return_type, function_name, argvs):
    """ generate cosim capture function """
    #append '_ptr' to the parameter if it is pointer

    top_func_argv = []
    impl_func_argv = []

    tgopen_argv = []
    tgcapture_before_argv = []
    tgcapture_after_argv = []

    temp_vars_definition = ''

    init_code = ''

    deinit_code = ''

    for var_name, var_info in argvs.items():
        category = var_info['category']
        var_type = var_info['var_type']
        arr = var_info['arr'] if 'arr' in var_info else None

        ov_cap_top = var_info['ov_cap_top'] if 'ov_cap_top' in var_info else None
        ov_cap_init = var_info['ov_cap_init'] if 'ov_cap_init' in var_info else None
        ov_cap_call = var_info['ov_cap_call'] if 'ov_cap_call' in var_info else None
        ov_cap_tgopen = var_info['ov_cap_tgopen'] if 'ov_cap_tgopen' in var_info else None
        ov_cap_before_call = var_info['ov_cap_before_call'] if 'ov_cap_before_call' in var_info else None
        ov_cap_after_call = var_info['ov_cap_after_call'] if 'ov_cap_after_call' in var_info else None
        ov_cap_deinit = var_info['ov_cap_deinit'] if 'ov_cap_deinit' in var_info else None
        skip_capture = var_info['skip_capture'] if 'skip_capture' in var_info else False

        if ov_cap_init:
            init_code += ov_cap_init
        
        if ov_cap_deinit:
            deinit_code += ov_cap_deinit 

        if ov_cap_top is not None:
            top_func_argv.append(ov_cap_top)
        elif category in ('array', 'dynamic_array'):
            top_func_argv.append(f'{var_type} {var_name}{array_add_bracket(arr)}')
        elif category == 'pointer':
            top_func_argv.append(f'{var_type} {var_name}_ptr')
        else:
            top_func_argv.append(f'{var_type} {var_name}')

        if ov_cap_call is not None:
            impl_func_argv.append(ov_cap_call)
        elif category == 'pointer':
            impl_func_argv.append(f'{var_name}_ptr')
        else:
            impl_func_argv.append(f'{var_name}')

        if skip_capture:
            pass
        elif ov_cap_tgopen is not None:
            tgopen_argv.append(ov_cap_tgopen)
        elif category in ('input', 'pointer', 'array'):
            tgopen_argv.append(f'{var_name}')
        elif category == 'dynamic_array':
            tgopen_argv.append(f'{var_name}_ptr')

        if skip_capture:
            pass
        elif ov_cap_before_call is not None:
            tgcapture_before_argv.append(ov_cap_before_call)
        elif category == 'array':
            tgcapture_before_argv.append(f'{var_name},{calc_array_size(arr)}')
        elif category == 'dynamic_array':
            tgcapture_before_argv.append(f'{var_name}_ptr,count')
        elif category in ('input', 'pointer'):
            tgcapture_before_argv.append(var_name)

        if skip_capture:
            pass
        elif ov_cap_after_call is not None:
            tgcapture_after_argv.append(ov_cap_after_call)
        elif category == 'array':
            tgcapture_after_argv.append(f'{var_name},{calc_array_size(arr)}')
        elif category == 'dynamic_array':
            tgcapture_after_argv.append(f'{var_name}_ptr,count')
        elif category == 'pointer':
            tgcapture_after_argv.append(var_name)

        if category == 'pointer':
            var_type = var_info['var_type'].replace('*', '')
            #print('{}: {}'.format(var_type, var_name))

            #eliminate volatile keyword
            if var_type.startswith('volatile '):
                chop_var_type = var_type.replace('volatile ', '', 1)
                temp_vars_definition += f"    {chop_var_type}& {var_name} = ({chop_var_type}&)ASSIGN_REF({var_name}_ptr, __FUNCTION__);\n"
            else:
                temp_vars_definition += f"    {var_type}& {var_name} = ASSIGN_REF({var_name}_ptr, __FUNCTION__);\n"
        elif category == 'dynamic_array':
            temp_vars_definition += f"    {var_type}* {var_name}_ptr = {var_name}; //dynamic array\n"

    function_call_string = f"IMPL({function_name})({', '.join(impl_func_argv)});"
    return_string = ''

    if return_type != 'void':
        skip_capture_code = f'return {function_call_string}'
    else:
        skip_capture_code = f'{function_call_string}'

    if config.parent_func is None:
        tgopen_argv.insert(0, f'"{function_name}_output.bin"')
        parent_func_prefix = f'\nstatic CCapture capture_{function_name};\n'          \
                             f'CCapture *capture = &capture_{function_name};\n'      \
                             'pthread_t __tid = pthread_self();\n'
                            

        parent_func_postfix = ''
    else:
        tgopen_argv.insert(0, f'"{config.parent_func}_output.bin"')

        if config.parent_func == function_name:
            parent_func_prefix = '\nCCapture *capture;\n'                                       \
                                'pthread_t __tid = pthread_self();\n'                           \
                                'auto iter = capture_group.items.find(__tid);\n'                          \
                                '    if (iter == capture_group.items.end()){\n'                           \
                                f'        capture = new CCapture("{function_name}", true);\n'   \
                                '        capture_group.items[__tid] = capture;\n'                         \
                                '    } else {\n'                                                \
                                '        capture = capture_group.items[__tid];\n'                         \
                                '    }\n'                                                       \
                                '    capture->set_inside_parent_func(true);\n\n'
            deinit_code += '\n    capture->set_inside_parent_func(false);\n'
            parent_func_postfix = ''
        else:
            parent_func_prefix = '\n\nif (CCapture::is_inside_parent_func()) {\n'  \
                                 '    pthread_t __tid = pthread_self();\n'         \
                                 '    CCapture *capture = capture_group.items[__tid];\n'

            parent_func_postfix = '\n} else {\n'                \
                              f'    {skip_capture_code}\n'      \
                              '}'

    # handle return type !
    if return_type != 'void':
        temp_vars_definition += f'\n    {return_type} ans;'

        if config.parent_func is None or config.parent_func == function_name:
            # Do not captrue return value if it is child function
            tgopen_argv.append('ans')
            tgcapture_after_argv.append('ans')

        function_call_string = f'ans = {function_call_string}'
        return_string = '\n    return ans;'

    if (not is_remark) or (config.parent_func is not None):
        enable = '1'
    else:
        enable = '0 //cosim_code_generator: This function is marked as skip in function_list.txt'

    if len(tgcapture_after_argv) == 0:
        init_code += '\nint __dummy__;\n'
        tgcapture_after_argv.append('__dummy__')

    keyword = {
        'enable'                  : enable,
        'parent_func_prefix'      : parent_func_prefix,
        'return_type'             : return_type,
        'function_name'           : function_name,
        'init_code'               : init_code,
        'p_list_string'           : ','.join(top_func_argv),
        'temp_vars_definition'    : temp_vars_definition,
        'tgOpen_string'           : ', '.join(tgopen_argv),
        'tgCapture_before_string' : ','.join(tgcapture_before_argv),
        'function_call_string'    : function_call_string,
        'tgCapture_after_string'  : ','.join(tgcapture_after_argv),
        'deinit_code'             : deinit_code,
        'return_string'           : return_string,
        'parent_func_postfix'     : parent_func_postfix,
        'skip_capture_code'       : skip_capture_code
    }

    override_generate_content(keyword)

    return gen_code_from_template('capture.tpl', keyword)


def gen_tb_func(is_remark, return_type, function_name, argvs):
    """ generate cosim testbench function """
    #if the array names declared as xxx_o and xxx, they are refer to the same array
    impl_func_argv = []

    define_inputs = []
    define_arrays = []
    define_pointers = []

    tgpop_argv = []
    tgcheck_argv = []

    declare_same_array = ''
    unique_arr = OrderedDict()
    dcache_arr = OrderedDict()

    determine_count_arg = None

    before_call = ''
    after_call = ''

    for var_name, var_info in argvs.items():
        chopname = chop_argvname(var_name)
        category = var_info['category']
        if category == 'dcache_arg':
            dcache_arr[var_name] = var_info
        elif category == 'array':
            if chopname in unique_arr:
                declare_same_array += f'    auto & {var_name} = {unique_arr[chopname]};\n'
            else:
                unique_arr[chopname] = var_name

    for var_name, var_info in argvs.items():
        category = var_info['category']
        var_type = var_info['var_type']
        arr = var_info['arr'] if 'arr' in var_info else None

        ov_tb_tgpop = var_info['ov_tb_tgpop'] if 'ov_tb_tgpop' in var_info else None
        ov_tb_before_call = var_info['ov_tb_before_call'] if 'ov_tb_before_call' in var_info else None
        ov_tb_call = var_info['ov_tb_call'] if 'ov_tb_call' in var_info else None
        ov_tb_after_call = var_info['ov_tb_after_call'] if 'ov_tb_after_call' in var_info else None
        ov_tb_tgcheck = var_info['ov_tb_tgcheck'] if 'ov_tb_tgcheck' in var_info else None
        skip_capture = var_info['skip_capture'] if 'skip_capture' in var_info else False

        if category == 'input':
            var_type = remove_const_and_volatile(var_type)
            define_inputs.append(f'    {var_type} {var_name};\n')

        elif category == 'pointer':
            var_type = remove_const_and_volatile(var_type)
            define_pointers.append(f'    {var_type.replace("*", "").strip()} {var_name};\n')

        elif category == 'array':
            var_type = remove_const_and_volatile(var_type)
            chopname = chop_argvname(var_name)
            if chopname in unique_arr and unique_arr[chopname] == var_name:
                define_arrays.append(f'    {var_type} {var_name} {array_add_bracket(arr)};\n')

        elif category == 'dynamic_array':
            var_type = remove_const_and_volatile(var_type)
            declare_str = f'{INTEND}std::unique_ptr<{var_type}[]> {var_name} (new {var_type}[{arr[0]}]);\n'    \
                          f'{INTEND}{var_type} *{var_name}_ptr = {var_name}.get();\n'
            define_pointers.append(declare_str)

        if skip_capture:
            pass
        elif ov_tb_tgpop is not None:
            tgpop_argv.append(ov_tb_tgpop)
        elif category in ('array', 'pointer', 'input'):
            tgpop_argv.append(var_name)

        if ov_tb_before_call is not None:
            before_call += ov_tb_before_call

        if ov_tb_call is not None:
            impl_func_argv.append(ov_tb_call)
        elif category == 'pointer':
            impl_func_argv.append(f'&{var_name}')
        elif category == 'dynamic_array':
            impl_func_argv.append(f'{var_name}_ptr')
        else:
            impl_func_argv.append(f'{var_name}')

        if ov_tb_after_call is not None:
            after_call += ov_tb_after_call

        if determine_count_arg is None and not skip_capture and category != 'dynamic_array':
            determine_count_arg = (var_name, var_info)

        if skip_capture:
            pass
        elif ov_tb_tgcheck is not None:
            tgcheck_argv.append(ov_tb_tgcheck)
        elif category in ('array', 'pointer'):
            tgcheck_argv.append(var_name)
        elif category == 'dynamic_array':
            tgcheck_argv.append(f'{var_name}_ptr,count')

    if return_type != 'void':
        return_str = 'ans = '
        define_pointers.append(f'    {return_type} ans;\n')
        tgcheck_argv.append('ans')
    else:
        return_str = ''

    #handle dcache
    dcache_arr_size = []
    for varname, varinfo in dcache_arr.items():
        varname = varname[:-2]
        varname_p = f'{varname}_p'
        varsize = varinfo['arr']
        if len(dcache_arr_size) == 0:
            before_call += '        uintptr_t dcache_offset = 0;\n'

        dcache_arr_size.append( f'{varname}_size32')

        define_inputs += f'    uintptr_t {varname_p};\n'
        define_arrays += f'    constexpr size_t {varname}_size32 = {varsize};\n'
        define_arrays += f'    uint32_t {varname} [{varname}_size32];\n'
        before_call += f'        {varname_p} = dcache_offset;\n'
        before_call += f'        memcpy(&dcache[{varname_p}/4], {varname}, sizeof({varname}));\n'
        before_call += f'        dcache_offset += {varname}_size32 * 4;\n'

        after_call += f'        memcpy({varname}, &dcache[{varname_p}/4], sizeof({varname}));\n'

    if len(dcache_arr_size) > 0:
        define_arrays += f'    std::unique_ptr<uint32_t[]> dcache_mem ( new uint32_t [ DCACHE_SIZE ] );\n'
        define_arrays += '    uint32_t *dcache = dcache_mem.get();\n'

    function_call_string = f'        {return_str}{function_name}(HLS_COMMON_ARG_CALL {",".join(impl_func_argv)});\n'

    if is_remark:
        enable = '0 //cosim_code_generator: This function is marked as skip in function_list.txt'
    else:
        enable = f'(TBCONFIG_{function_name.upper()} || TBCONFIG_ALL)'


    keyword = {
        'enable'                  : enable,
        'function_name'           : function_name,
        'define_inputs_string'    : ''.join(define_inputs),
        'define_arrays_string'    : ''.join(define_arrays) + declare_same_array,
        'temp_vars_definition'    : ''.join(define_pointers),
        'tgpop_string'            : ','.join(tgpop_argv),
        'before_call'             : before_call,
        'function_call_string'    : function_call_string,
        'after_call'              : after_call,
        'tgcheck_string'          : ','.join(tgcheck_argv),
    }

    override_generate_content(keyword)

    return gen_code_from_template('testbench.tpl', keyword)

# main
def process_function_head(func_name, func_info):
    """ core function body to extract function info, call gen_capture_func() and gen_tb_func() """

    return_type = func_info['return_type']
    func_para = func_info['para']
    impl_func = func_info['func_impl']
    visible = func_info['visible']
    is_impl_func = func_info['is_impl_func']
    is_remark = not visible

    if not is_impl_func:
        return None, None, None, None

    argvs = extract_para_info(func_para, impl_func, func_name)
    capture_code = gen_capture_func(is_remark, return_type, func_name, argvs)
    test_bench_code = gen_tb_func(is_remark, return_type, func_name, argvs)
    # print(capture_code)
    # print(test_bench_code)

    return is_remark, func_name, capture_code, test_bench_code
