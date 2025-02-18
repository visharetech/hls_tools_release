`ifndef XNET_DRV_TEST_VH
`define XNET_DRV_TEST_VH

logic [31:0] data=0;

task automatic xnet_drv_test;
    input [$$clog2(HLS_NUM)-1:0]    func;
    input [LOG2_MAX_PARTITION-1:0]  pidx;
    logic [31:0]                    width;
    logic [31:0]                    adr;
    logic                           isRead;
    logic [31:0]                    depth;
    logic [31:0]                    inc;
    logic [31:0]                    rd_adr;
    logic [31:0]                    rd_cnt = 0;
    begin 

        ap_part [func] = pidx;
        case (func)
${run_statement}
        endcase
        ap_part [func] = 0;
    end 
endtask

task automatic xnet_sig_init; 
    begin
${init_statement}
    end
endtask

`endif
