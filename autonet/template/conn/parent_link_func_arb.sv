    //parent link function arbiter
    //${module} function connected to HLS_PARENT_ID and calls the add function connected to CHILD
    ${module}_call_child_full_n = parent_cmdfifo_full_n_o[HLS_PARENT_ID+${block_idx}];
    parent_cmdfifo_write_i[HLS_PARENT_ID+${block_idx}] = ${module}_call_child_write;
    parent_cmdfifo_din_i[HLS_PARENT_ID+${block_idx}][ARGS_MSB:ARGS_LSB] = ${module}_call_child_din[32+:ARG_NUM*32];
    parent_cmdfifo_din_i[HLS_PARENT_ID+${block_idx}][CHILD_PC_MSB:CHILD_PC_LSB] = ${module}_call_child_din[((ARG_NUM+1)*32)+:31];
    //used bit9 to select child id larger than HLS_NUM
    parent_cmdfifo_din_i[HLS_PARENT_ID+${block_idx}][CHILD_MOD_MSB:CHILD_MOD_LSB] = ( ${module}_call_child_din[CHILD_MAP_BIT]?
                                                                            (${module}_call_child_din[LOG_CHILD-1:0] + HLS_NUM) :
                                                                            ${module}_call_child_din[LOG_CHILD-1:0]);
    parent_cmdfifo_din_i[HLS_PARENT_ID+${block_idx}][RETREQ_BIT] = ${module}_call_child_din[((ARG_NUM+2)*32)-1];

    ${module}_ret_empty_n = parent_retFifo_empty_n_o[HLS_PARENT_ID+${block_idx}];
    parent_retFifo_pop_i[HLS_PARENT_ID+${block_idx}] = ${module}_ret_read;
    ${module}_ret_dout = parent_retFifo_dout_o[HLS_PARENT_ID+${block_idx}][31:0];

