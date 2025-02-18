bool test_${function_name}(){
#if ${enable}
    printf("Test ${function_name}\n");
    // define input variables 
${define_inputs_string}
    // define arrays
${define_arrays_string}
    // define temp variables
${temp_vars_definition}

    HLS_COMMON_INIT_VAR();

    // start loading 
    tgLoad("${function_name}_output.bin")
    
    unsigned int total_count = 0;
    bool finish = false;
    do{
        tgPop(${tgpop_string});

        if (finish) {
            break;
        }
        // call the function
${before_call}${function_call_string}${after_call}
        tgCheck(${tgcheck_string});
        ++total_count;
    } while(true);

    printf("Passed after %d\n", total_count);
    return true;
#else
    printf("Skip ${function_name}\n");
    return true;
#endif
}

