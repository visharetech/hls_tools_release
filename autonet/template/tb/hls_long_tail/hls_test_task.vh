task automatic ${task_name}(int core);
    int tgf;

    int test_cnt = 0;
    bit is_finish = 1'b0;

    dcache_arg_t dcache_arg[string];
    apcall_arg_t apcall_arg;
    logic [31:0] ret;

    //tgcapture variables
${declare_logic}

    tg_open(core, "${test_data}", tgf);

${start}

    while (1) begin
        //Get tgcapture data
${load_data}
        if (is_finish) begin
            $$display("%m: done");
            break;
        end

        //Call HLS function
${call_func}
        //Verification
${verify}
        test_cnt++;
        $$display("test_cnt: %0d", test_cnt);
    end
    
${end}
    tg_close(tgf);

endtask

