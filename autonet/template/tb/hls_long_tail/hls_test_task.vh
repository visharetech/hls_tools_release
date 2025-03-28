task automatic ${task_name}(int core, int thread);
    int tgf;

    int file_id = 0;
    int test_cnt = 0;
    bit is_finish = 1'b0;

    dcache_arg_t dcache_arg[string];
    apcall_arg_t apcall_arg;
    logic [31:0] ret;
    string test_data_file;


    //tgcapture variables
${declare_logic}

    if (core == 0) begin
        test_data_file = "${module_name}_output.bin";
    end else begin
        test_data_file = $$sformatf("${module_name}_output_tid%0d.bin", core);
    end

    tg_open(core, thread, test_data_file, file_id, tgf);

${start}

    while (1) begin
        //Get tgcapture data
${load_data}
        if (is_finish) begin
            tg_close(tgf);

            //try to check if other .partX test file exist
            file_id += 1;
            tg_open(core, thread, test_data_file, file_id, tgf);
            if (tgf == 0) begin
                $$display("================ %m: done ================");
                break;
            end else begin
                continue;
            end
        end

        //Call HLS function
${call_func}
        //Verification
${verify}
        test_cnt++;
        $$display("================ test_cnt: %0d ================", test_cnt);
    end
    
${end}

endtask

