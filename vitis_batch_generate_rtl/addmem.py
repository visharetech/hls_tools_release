import sys
funcName=str(sys.argv[2])
memports = '''    get_inline_mem_addr_o,
    get_inline_mem_addr_o_ap_vld,
    get_inline_mem_addr_o_ap_rdy,
    get_inline_mem_data_i,
    get_inline_mem_data_i_ap_vld,
'''
memDeclare = '''
output [8:0] get_inline_mem_addr_o;
output get_inline_mem_addr_o_ap_vld;
input get_inline_mem_addr_o_ap_rdy;
input get_inline_mem_data_i;
input get_inline_mem_data_i_ap_vld;
'''

inst_memports='''    .get_inline_mem_addr_o(get_inline_mem_addr_o),
    .get_inline_mem_addr_o_ap_vld(get_inline_mem_addr_o_ap_vld),
    .get_inline_mem_addr_o_ap_rdy(get_inline_mem_addr_o_ap_rdy),
    .get_inline_mem_data_i(get_inline_mem_data_i),
    .get_inline_mem_data_i_ap_vld(get_inline_mem_data_i_ap_vld),
'''        

inst_ctx='''    ,
    .ctx(9'h100)
'''        

with open(str(sys.argv[1]), 'r') as file:
    lines = file.readlines()
    moduleStart = 'module ' + funcName +' (\n'
    i=0
    has_ctx=0
    pipeline=0
    decBin=0
    while i < len(lines):  
        if lines[i].startswith("decBin_itf ") and pipeline==0:
            print(lines[i][0:10], '#(.PIPELINE(0)) ', lines[i][11:], end='')
        else:
            print(lines[i], end='')
        if lines[i]== moduleStart: 
            print(memports, end='') 
            i=i+1
            for j in range(1000): 
                print(lines[i+j], end='')
                if lines[i+j]==');\n': 
                    i+=j
                    print(memDeclare, end='') 
                    break
        elif lines[i].startswith("decBin_itf"):
            print(inst_memports, end='')
            decBin=1
        elif lines[i].strip().startswith(".ctx") and decBin==1:
            has_ctx=1
        elif lines[i].strip().startswith(".ap_return") and has_ctx==0 and decBin==1:
            print(inst_ctx, end='')
            decBin=0
        elif 'HLS_INPUT_ARCH=pipeline' in lines[i]:
            pipeline=1
        i+=1
            
        
            
            