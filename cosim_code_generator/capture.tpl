${return_type} CAPTURE_(${function_name})(${p_list_string}){
#if ${enable}${parent_func_prefix}
    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);

    enum PARENT_FUNCTION_STATUS parent_func_status = CCapture::is_parent_func(__func__);

    // define temporary variables to hold pointers
${init_code}${temp_vars_definition}

    tgOpen(${tgOpen_string});

    tgCaptureBeforeCall(${tgCapture_before_string});

    // call the function with the initial parameters
    ${function_call_string}

    tgCaptureAfterCall(${tgCapture_after_string});

    tgClose();${deinit_code}${return_string}${parent_func_postfix}
#else
    ${skip_capture_code}
#endif
}

