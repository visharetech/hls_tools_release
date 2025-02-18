localparam TESTDATA_CAPTURE_BEFORE_TAG = 32'hFFFF_FFFE;
localparam TESTDATA_CAPTURE_AFTER_TAG = 32'hFFFF_FFFF;


typedef struct {
    reg [31:0] array [8];
    int count;
}apcall_arg_t;

typedef struct {
    string sigName;
    int width;
} signal_info_t;

typedef struct {
    bit is_xmem_dcache_pointer; //if is_xmem_dcache_pointer is 1'b1, dcache_pointer_loc store the xmem offset
    int dcache_pointer_loc;     //if is_xmem_dcache_pointer is 1'b0, dcache_pointer_loc store the apcall_arg index
    int base;
    int size;
} dcache_arg_t;


typedef struct {
    bit is_array;
    int offset;
    bit dir;
    int width;
    int depth;
    string remark;
} lookup_entry_t;

typedef lookup_entry_t lookup_table_t[string];
lookup_table_t lookup_table;

signal_info_t signal_info[CORE_NUM][$];

function [15:0] endian16;
    input [15:0] dat;
    begin
        endian16 = {dat[8*0+:8], dat[8*1+:8]};
    end
endfunction

function [31:0] endian32;
    input [31:0] dat;
    begin
        endian32 = {dat[8*0+:8], dat[8*1+:8], dat[8*2+:8], dat[8*3+:8]};
    end
endfunction

function [63:0] endian64;
    input [63:0] dat;
    begin
        endian64 = {	
					dat[8*0+:8], dat[8*1+:8], dat[8*2+:8], dat[8*3+:8], 
					dat[8*4+:8], dat[8*5+:8], dat[8*6+:8], dat[8*7+:8]
		};
    end
endfunction


function bit str_contains(string a, string b);
    // checks if string A contains string B
    int len_a;
    int len_b;
    len_a = a.len();
    len_b = b.len();
    //$display("a (%s) len %d -- b (%s) len %d", a, len_a, b, len_b);
    for( int i=0; i<len_a; i++) begin
        if(a.substr(i,i+len_b-1) == b)
            return 1'b1;
    end
    return 1'b0;
endfunction

function bit startswith(string a, string b);
    // checks if string A starts-with string B
    int len_b;
    len_b = b.len();
    if(a.substr(0, len_b-1) == b)
      return 1'b1;
    return 1'b0;
endfunction

function int calc_bit_mask(int input_val);
    begin
      if (input_val == 0) begin
        calc_bit_mask = 0;
      end else begin
        calc_bit_mask = (1 << input_val) - 1;
      end
    end
endfunction

task automatic assign_test_data(input integer core, inout apcall_arg_t apcall_arg, input int dcache_offset, input string func_name, input string sigName, input int index, input int sigwidth, input logic [31:0] data, output string parse_vartype, output int parse_offset);

string varname;
int offset;
string remark;
begin
    //setup dcache and xmem data
    varname = search_varname(func_name, sigName);

    if (varname != "NOT_FOUND") begin
        remark = lookup_table[varname].remark;
    end else begin
        remark = "";
    end

    if (str_contains(remark, "apcall_arg") && startswith(varname, func_name)) begin
        //HANDLE_APCALL_ARG();
        parse_vartype = "apcall_arg";
        parse_offset = apcall_arg.count;
        apcall_arg.array[parse_offset] = data;
        apcall_arg.count+=1;
        $display("apcall argument: %s %s sigwidth:%0d data:%0h", sigName, varname, sigwidth, data);
        //$stop;
    end else if (str_contains(remark, "xmem_dcache_pointer")) begin
        offset = lookup_table[varname].offset;
        
        $display("sigName (xmem_dcache pointer):%s %s xmem offset:%d index:%0d sigwidth:%0d data:%0h", sigName, varname, offset, index, sigwidth, data);
        if (index != 0) begin
            $error("error:xmem_dcache_pointer argument not expect: index:%0d", index);
            $stop;
        end
        
        parse_vartype = "xmem_dcache_pointer";
        parse_offset = offset + index * sigwidth;


        xmem_write(core, parse_offset, 32'hdeadc0de, 32);
        //$stop;
    end else if(str_contains(remark, "apcall_arg_dcache_pointer")) begin
        $display("sigName (apcall_arg_dcache pointer):%s %s apcall_loc:%0d", sigName, varname, apcall_arg.count);
        parse_vartype = "apcall_arg_dcache_pointer";
        parse_offset = apcall_arg.count;
        if (index != 0) begin
            $error("error:xmem_dcache_pointer argument not expect: index:%0d", index);
            $stop;
        end

        apcall_arg.array[parse_offset] = 32'hdeadc0de;
        apcall_arg.count+=1;
        //$stop;
    end else if (startswith(sigName, "dc_")) begin
        //handle dcache data
        parse_vartype = "dcache";
        parse_offset = dcache_offset + index * sigwidth;
        dcache_write(parse_offset, data, sigwidth * 8);
    end else if (varname != "NOT_FOUND") begin
        offset = lookup_table[varname].offset;
        $display("sigName:%s %s xmem offset:%d index:%0d sigwidth:%0d data:%0h", sigName, varname, offset, index, sigwidth, data);
        parse_vartype = "xmem";
        parse_offset = offset + index * sigwidth;
        xmem_write(core, parse_offset, data, sigwidth * 8);

    end else begin
        $display("data not handled, may be apcall argument in child function %s %s", func_name, sigName);
        parse_vartype = "unknown";
        parse_offset = 0;
        $stop;
    end
end
endtask

task automatic verify_test_data(input integer core, input string func_name, input string sigName, input int index, input int sigwidth, input logic [31:0] data, input logic [31:0] apcall_return_value, input dcache_arg_t dcache_arg[string]);
string varname;
int offset;
string remark;
logic [31:0] dout;
begin
    //setup dcache and xmem data
    varname = search_varname(func_name, sigName);

    if (varname != "NOT_FOUND") begin
        remark = lookup_table[varname].remark;
    end else begin
        remark = "";
    end

    if (sigName == "ans") begin
        //check return value
        if (apcall_return_value != data) begin
            $display("return value mismatch: %s %s sigwidth:%0d data:%0h ret:%0h", sigName, varname, sigwidth, data, apcall_return_value);
            $stop;
        end
    end else if (str_contains(remark, "dcache_pointer")) begin
        $display("ignore dcache pointer: %s %s", sigName, varname);
        
    end else if (startswith(sigName, "dc_")) begin
        //handle dcache data
        //$display("verify dcache data %s %s dcache offset:%d index:%0d sigwidth:%0d data:%0h", sigName, varname, dcache_arg[sigName].base + index * sigwidth, index, sigwidth, data);

        //foreach(dcache_arg[key]) begin
        //    $display("dcache key:%s base:%0d", key, dcache_arg[key].base);
        //end

        dcache_read(dcache_arg[sigName].base + index * sigwidth, dout, sigwidth * 8);

        if (dout != data) begin
            $display("dcache data mismatch: %s %s dcache offset:%d index:%0d sigwidth:%0d data:%0h dout:%0h", sigName, varname, offset, index, sigwidth, data, dout);
            $stop;
        end
    end else if (varname != "NOT_FOUND") begin
        offset = lookup_table[varname].offset;
        remark = lookup_table[varname].remark;

        $display("verify xmem data %s %s xmem offset:%d index:%0d sigwidth:%0d data:%0h", sigName, varname, offset, index, sigwidth, data);
        xmem_read(core, offset + index * sigwidth, dout, sigwidth * 8);

        if (str_contains(remark, "split_u32_array")) begin
            int width = lookup_table[varname].width;
            int bitmask = calc_bit_mask(width % 32);
            $display("%s split to u32 array", varname);
            
            // if bNeighborFlags, width == 65 and if encountered index == 2, bit mask will be 1.
            if (index == (width / 32) && (width % 32) > 0) begin
                $display("apply bitmask:%d", bitmask);
                data = data & bitmask;
            end
        end

        if (dout != data) begin
            $display("xmem data mismatch: %s %s xmem offset:%d index:%0d sigwidth:%0d data:%0h dout:%0h", sigName, varname, offset, index, sigwidth, data, dout);
            $stop;
        end
    end else begin
        //$display("data not handled in verify_test_data");
        //$stop;
    end
end
endtask

task automatic tg_open(input int core, input string filepath, output int file_handler);
    logic strCapturing;
    logic [7:0] char8;
    logic [31:0] dat32;
    integer headerSize;
    integer tmp;
    int signalNameLen;
    int signalNum;
    string sigName;
    int width;
    int depth;
    signal_info_t new_signal;
    begin         

        file_handler = $fopen(filepath, "rb");
        if (file_handler == 0) begin
            $error("cannot open file %s", filepath);
            $stop;
        end

        tmp = $fread (dat32, file_handler); 
        if (dat32 != {"T", "B", "0", "1"}) begin
            $display("Not a valid test file signature");
            $stop;
        end

        tmp = $fread (dat32, file_handler);
        signalNum = endian32(dat32);
        $display("signal number: %0d", signalNum);

		//edward: make sure queue is empty
        while (signal_info[core].size() > 0)
            signal_info[core].pop_front();

        for (int s=0; s<signalNum; s++) begin
            tmp = $fread (dat32, file_handler);
            signalNameLen = endian32(dat32);

            // Read the signal name as a string
            sigName = "";
            for (int c = 0; c < signalNameLen; c++) begin
                tmp = $fread(char8, file_handler);
                sigName = {sigName, char8};
            end
            $display ("sigName[%0d]: %s", s, sigName);

            tmp = $fread (dat32, file_handler);
            width = endian32(dat32);
            $display ("qwidth[%0d]: %0d", s, width);

            new_signal.sigName = sigName;
            new_signal.width = width;
            signal_info[core].push_back(new_signal);
        end
    end 
endtask

task automatic tg_close(input integer file_handler);
    $fclose(file_handler);
endtask

task automatic tg_load_test_data(input integer core, input integer file_handler, input string func_name, output apcall_arg_t apcall_arg, output dcache_arg_t dcache_arg[string], output bit finish);
    integer status;
    logic [7:0] dat8;
    logic [15:0] dat16;
    logic [31:0] dat32;
    logic [31:0] value;
    int var_id;
    int buf_size;
    int signal_width;
    string signame;
    
    int dcache_offset;
    string parse_vartype;
    int parse_offset;
    string chopsigname;
    begin
        finish = 1'b0;
        apcall_arg.count = 0;
        dcache_offset = core * DC_SIZE;
        parse_vartype = "";

        while (1) begin
            status = $fread (dat32, file_handler);
            if (status == 0) begin
                finish = 1'b1;
                return;
            end else if (status < 0) begin
                $error("error during read the file");
                return;
            end


            var_id = endian32(dat32);

            if (var_id == TESTDATA_CAPTURE_BEFORE_TAG) begin
                //$display("TESTDATA_CAPTURE_BEFORE_TAG\n");
                //$stop;
                break;
            end

            status = $fread (dat32, file_handler);
            if (status <= 0) begin
                $error("error during read the file");
                $stop;
            end

            buf_size = endian32(dat32);

            signame = signal_info[core][var_id].sigName;
            signal_width = signal_info[core][var_id].width;

            for (int i=0; i<buf_size / signal_width; i++) begin
                if (signal_width == 1) begin
                    status = $fread (dat8, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    value = dat8;
                end
                else if (signal_width == 2) begin
                    status = $fread (dat16, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    value = endian16(dat16);
                end
                else if (signal_width == 4) begin
                    status = $fread (dat32, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    value = endian32(dat32);
                end
                else if (signal_width == 8) begin
                    status = $fread (dat32, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    status = $fread (dat32, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    value = endian32(dat32);
                end
                else begin
                    $error("Unsupported signal width: %0d", signal_width);
                    $stop;
                end
                assign_test_data(core, apcall_arg, dcache_offset, func_name, signame, i, signal_width, value, parse_vartype, parse_offset);

            end

            if (parse_vartype == "dcache") begin
                dcache_arg[signame].base = dcache_offset;
                dcache_arg[signame].size = buf_size;
                $display("save dcache argument: signame:%s base:%0d size:%0d", signame, dcache_offset, buf_size);
                dcache_offset += buf_size;
                //$stop;
            end else if (parse_vartype == "xmem_dcache_pointer") begin
                $display("dcache pointer in xmem: %0d", parse_offset);
                chopsigname = signame.substr(0, signame.len()-3);
                dcache_arg[chopsigname].is_xmem_dcache_pointer = 1;
                dcache_arg[chopsigname].dcache_pointer_loc = parse_offset;
                //$stop;
            end else if (parse_vartype == "apcall_arg_dcache_pointer") begin
                $display("dcache pointer apcall location: %0d", parse_offset);
                chopsigname = signame.substr(0, signame.len()-3);
                dcache_arg[chopsigname].is_xmem_dcache_pointer = 0;
                dcache_arg[chopsigname].dcache_pointer_loc = parse_offset;
                //$stop;
            end

            $display("Width of signal[%0d]: signame:%s width:%0d bufsize:%0d", var_id, signame, signal_width, buf_size);
            //$stop;
        end

        $display("Size of dcache_arg: %0d", $size(dcache_arg));
        //$stop;

        // Write dcache argument
        foreach (dcache_arg[dcache_key]) begin
            bit is_xmem_dcache_pointer = dcache_arg[dcache_key].is_xmem_dcache_pointer;
            int dcache_pointer_loc = dcache_arg[dcache_key].dcache_pointer_loc;
            int base = dcache_arg[dcache_key].base;
            $display("varname:%s is_xmem_dcache_pointer:%b dcache_pointer_loc:%d base: %d", dcache_key, is_xmem_dcache_pointer, dcache_pointer_loc, base);
            if (is_xmem_dcache_pointer) begin
                $display("set dcache pointer in xmem offset:%0d dcache_base:%0d", dcache_pointer_loc, base);
                xmem_write(core, dcache_pointer_loc, base, 32);
            end else begin
                $display("set dcache pointer in apcall arg offset:%0d dcache_base:%0d", dcache_pointer_loc, base);
                apcall_arg.array[dcache_pointer_loc] = base;
            end

            for( int i=0; i<16; i+=4) begin
                dcache_read(base + i, dat32, 32);
                $display("first 16 data of %s dcache offset:%d data: %0h", dcache_key, i, dat32);
            end
        end
        //$stop;
    end
endtask

task automatic exec_apcall(input int core_id, input int hls_id, input apcall_arg_t apcall_arg, output logic [31:0] ret);
    begin
        $display("exec apcall_%0d", apcall_arg.count);
        case (apcall_arg.count)
            0:
                ap_call_0(core_id, hls_id, ret);
            1:
                ap_call_1(core_id, hls_id, apcall_arg.array[0], ret);
            2:
                ap_call_2(core_id, hls_id, apcall_arg.array[0], apcall_arg.array[1], ret);
            3:
                ap_call_3(core_id, hls_id, apcall_arg.array[0], apcall_arg.array[1], apcall_arg.array[2], ret);
            4:
                ap_call_4(core_id, hls_id, apcall_arg.array[0], apcall_arg.array[1], apcall_arg.array[2], apcall_arg.array[3], ret);
            5:
                ap_call_5(core_id, hls_id, apcall_arg.array[0], apcall_arg.array[1], apcall_arg.array[2], apcall_arg.array[3], apcall_arg.array[4], ret);
            6:
                ap_call_6(core_id, hls_id, apcall_arg.array[0], apcall_arg.array[1], apcall_arg.array[2], apcall_arg.array[3], apcall_arg.array[4], apcall_arg.array[5], ret);
            7:
                ap_call_7(core_id, hls_id, apcall_arg.array[0], apcall_arg.array[1], apcall_arg.array[2], apcall_arg.array[3], apcall_arg.array[4], apcall_arg.array[5], apcall_arg.array[6], ret);
            8:
                ap_call_8(core_id, hls_id, apcall_arg.array[0], apcall_arg.array[1], apcall_arg.array[2], apcall_arg.array[3], apcall_arg.array[4], apcall_arg.array[5], apcall_arg.array[6], apcall_arg.array[7], ret);
            default: begin
                $display("Unsupported apcall argument count: %0d", apcall_arg.count);
                $stop;
            end
        endcase

        //$stop;
    end
endtask

task automatic tg_verify_test_data(input integer core, input integer file_handler, input string func_name, input logic [31:0] apcall_return_value, input dcache_arg_t dcache_arg[string]);
    integer status;
    logic [7:0] dat8;
    logic [15:0] dat16;
    logic [31:0] dat32;
    logic [31:0] value;
    int var_id;
    int buf_size;
    int signal_width;
    string signame;

    begin
        while (1) begin
            status = $fread (dat32, file_handler);
            if (status <= 0) begin
                $error("error during read the file");
                return;
            end
            var_id = endian32(dat32);

            if (var_id == TESTDATA_CAPTURE_AFTER_TAG) begin
                //$stop;
                break;
            end

            status = $fread (dat32, file_handler);
            if (status <= 0) begin
                $error("error during read the file");
                $stop;
            end

            buf_size = endian32(dat32);

            signame = signal_info[core][var_id].sigName;
            signal_width = signal_info[core][var_id].width;

            for (int i=0; i<buf_size / signal_width; i++) begin
                if (signal_width == 1) begin
                    status = $fread (dat8, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    value = dat8;
                end
                else if (signal_width == 2) begin
                    status = $fread (dat16, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    value = endian16(dat16);
                end
                else if (signal_width == 4) begin
                    status = $fread (dat32, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    value = endian32(dat32);
                end
                else if (signal_width == 8) begin
                    status = $fread (dat32, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    status = $fread (dat32, file_handler);
                    if (status <= 0) begin
                        $error("error during read the file");
                        $stop;
                    end
                    $display("TODO: read and verify 8byte data not test");
                    //$stop;
                    value = endian32(dat32);
                end
                else begin
                    $display("Unsupported signal width: %0d", signal_width);
                    $stop;
                end

                verify_test_data(core, func_name, signame, i, signal_width, value, apcall_return_value, dcache_arg);
            end

            $display("Width of signal[%0d]: signame:%s width:%0d bufsize:%0d", var_id, signame, signal_width, buf_size);
            //$stop;
        end
    end
endtask


// Function to load CSV file and populate lookup table
function parse_csv_file(string csv_file_name);
    automatic csv_record record_row;
    automatic csv_parser parser = new();
    automatic lookup_entry_t entry;
    automatic string varname;
    automatic string func_name;
    automatic int varname_len;
    automatic string postfix_str;
    automatic string prefix_str;
    automatic bit comment;
    automatic string full_varname;

    // Quit if load fails
    if (parser.load_csv_file(csv_file_name)) begin
        $error("cannot open csv file");
        $stop;
    end

    // Quit if parsing fails
    assert(parser.parse() == CSV_SUCCESS) else $stop;

    // Iterate each field of the table
    for(int i=0;i < parser.size();i ++) begin
        comment = 1'b0;
        record_row = parser.get_record(.row_index(i));

        func_name = record_row.get_field(.field_index(0)); // Column 0
        if (func_name.substr(0, 15) == "#Apply the patch") begin
            $display("Skip the row - #Apply the patch");
            // Skip this row
            continue;
        end else if (func_name.substr(0, 0) == "#") begin
            // Skip this row
            comment = 1'b1;
            func_name = func_name.substr(1, func_name.len()-1);
        end else if (func_name == "func_name") begin
            // Skip this row
            continue;
        end

        entry.is_array = record_row.get_field(.field_index(1)) == "1";      // Column 1: is_array
        $sscanf(record_row.get_field(.field_index(2)), "%d", entry.offset); // Column 2: offset
        varname = record_row.get_field(.field_index(3));                    // Column 3: varname
        entry.dir = record_row.get_field(.field_index(4)) == "1";           // Column 4: dir
        $sscanf(record_row.get_field(.field_index(5)), "%d", entry.width);  // Column 5: width
        $sscanf(record_row.get_field(.field_index(6)), "%d", entry.depth);  // Column 6: depth
        entry.remark = record_row.get_field(.field_index(7));               // Column 7: remark

        full_varname = {func_name, ".", varname};
        lookup_table[varname] = entry;
        lookup_table[full_varname] = entry;
        $display("Varname: %s, Is Array: %b, Offset: %d, Dir: %b, Width: %d, Depth: %d, Remark: %s", varname, entry.is_array, entry.offset, entry.dir, entry.width, entry.depth, entry.remark);

        // Check if varname ends with _i or _o and remove the postfix
        //$display("%d", varname.len());
        varname_len = varname.len();
        if (varname_len > 2) begin
            prefix_str = varname.substr(0, 2);
            postfix_str = varname.substr(varname_len-2, varname_len-1);
            if (postfix_str == "_i" || postfix_str == "_o") begin
                varname = varname.substr(0, varname_len-3);
                full_varname = {func_name, ".", varname};
                lookup_table[varname] = entry;
                lookup_table[full_varname] = entry;
                $display("Additional varname: %s, Is Array: %b, Offset: %d, Dir: %b, Width: %d, Depth: %d, Remark: %s", varname, entry.is_array, entry.offset, entry.dir, entry.width, entry.depth, entry.remark);
            end

            if (prefix_str == "dc_" && postfix_str == "_p") begin
                full_varname = {func_name, ".", varname};
                lookup_table[varname] = entry;
                lookup_table[full_varname] = entry;
                $display("Additional varname: %s, Is Array: %b, Offset: %d, Dir: %b, Width: %d, Depth: %d, Remark: %s", varname, entry.is_array, entry.offset, entry.dir, entry.width, entry.depth, entry.remark);
            end
        end
    end
    //$stop;

endfunction

// Function to get the varname from lookup_table
// If the variable name is not found, it will return "NOT_FOUND"
function string search_varname(string func_name, string varname);
    automatic string fullname_with_suffix;
    automatic string varname_with_suffix;
    automatic string full_varname = {func_name, ".", varname};
    if (lookup_table.exists(full_varname)) begin
        return full_varname;
    end else if (lookup_table.exists(varname)) begin
        return varname;
    end else begin
        fullname_with_suffix = {full_varname, "_0"};
        varname_with_suffix = {varname, "_0"};
        if (lookup_table.exists(fullname_with_suffix)) begin
            return fullname_with_suffix;
        end else if (lookup_table.exists(varname_with_suffix)) begin
            return varname_with_suffix;
        end else begin
            //$display("varname %s not found", full_varname);
            //$stop;
            return "NOT_FOUND";
        end
    end
endfunction

task automatic tg_dma_open(input string filepath, output int file_handler);
        file_handler = $fopen(filepath, "rb");
        if (file_handler == 0) begin
            $error("cannot open file %s", filepath);
            $stop;
        end
endtask

task tg_dma_queue8(input int file_handler, inout logic[7:0] dma_queue[$]);
    int tmp;
    int byteNum;
    logic [31:0] dat32;
    logic [7:0] dat8;

    tmp = $fread (dat32, file_handler);
    byteNum = endian32(dat32);
    $display("byte number: %0d", byteNum);

    for (int s=0; s<byteNum; s++) begin
        tmp = $fread (dat8, file_handler);
        dma_queue.push_back(dat8);
    end
endtask

task automatic tg_dma_close(input integer file_handler);
    $fclose(file_handler);
endtask