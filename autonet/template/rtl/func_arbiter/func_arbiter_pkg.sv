
package func_arbiter_pkg;

    localparam int ARG_NUM = 8;
    localparam int ARG_W = 32;
    localparam int RET_DW = 32;
    localparam int CMD_FIFO_DEPTH = 8;
    localparam int CMD_FIFO_AW = 8;
    localparam int RET_FIFO_DEPTH = 8;
    localparam int RET_FIFO_AW = $clog2(RET_FIFO_DEPTH);
    localparam int CALL_SEQ_W = 2;
    localparam int ROB_W = (1 << CALL_SEQ_W);
    localparam int L1_GROUP = 8;

    function automatic bit [0:L1_GROUP-1][7:0] get_inst_per_group(input int inst_num, input int l1_grp);
        int cur_grp = 0;
        get_inst_per_group = '{default: '0};
        for (int p=0; p<inst_num; p++) begin
            get_inst_per_group[cur_grp]++;
            if (cur_grp==l1_grp-1) begin
                cur_grp = 0;
            end
            else begin
                cur_grp++;
            end
        end
    endfunction

    function automatic bit [0:L1_GROUP-1][7:0] get_start_inst_idx(input int l1_grp, input bit [0:L1_GROUP-1][7:0] inst_per_grp);
        int cur_inst_idx = 0;
        for (int g=0; g<L1_GROUP; g++) begin
            get_start_inst_idx[g] = cur_inst_idx;
            cur_inst_idx += inst_per_grp[g];
        end
    endfunction

    function automatic int get_max_inst_per_group(input int l1_grp, input bit [0:L1_GROUP-1][7:0] inst_per_grp);
        get_max_inst_per_group = 0;
        for (int g=0; g<L1_GROUP; g++) begin
            if (inst_per_grp[g]>get_max_inst_per_group) begin
                get_max_inst_per_group = inst_per_grp[g];
            end
        end
    endfunction

endpackage
