//-----------
// Debug Log
//-----------
localparam ENABLE_LOG = 0;

`define NEW_AP_CTRL_CMD
`define FUNCTION_ARBITER

//---------------
// RISCV command
//---------------
`ifdef FUNCTION_ARBITER
localparam XMEM_ACCESS     	= 0;    //HLS xmem (v1) access
localparam XMEM1_ACCESS    	= 0;    //HLS xmem (v2) access
localparam DMA_ACCESS	 	= 2;    //DMA access
`else
localparam XMEM_ACCESS     	= 0;    //HLS xmem access
localparam SET_AP_START    	= 1;    //Set HLS ap start and argument[0].
localparam SET_AP_ARGUMENT 	= 2;   //Set HLS ap argument with selected vector index.
localparam WAIT_AP_DONE    	= 3;    //Wait HLS ap done (blocking) and get return[0].
localparam CHECK_AP_DONE   	= 4;    //Check value of HLS ap done (non-blocking).
localparam GET_AP_RETRUN   	= 5;    //Get HLS return with selected vector index.
localparam DMA_ACCESS	 	= 6;    //DMA access
localparam SET_AP_START_NB  = 7;    //Set HLS ap start and argument[0] without return.
localparam SET_AP_CTRL      = 8;    //Signle command for SET_AP_START, SET_AP_START_NB, SET_AP_ARGUMENT and WAIT_AP_DONE
`endif


//AP control command (SET_AP_CTRL)
localparam AP_CTRL_START     = 0;    //Same as SET_AP_START.
localparam AP_CTRL_START_NB  = 1;    //Same as SET_AP_START_NB.
localparam AP_CTRL_ARGUMENT  = 2;    //Same as SET_AP_ARGUMENT.
localparam AP_CTRL_DONE      = 3;    //Same as WAIT_AP_DONE.

//----------------------------
// Function arbiter interface
//----------------------------
task automatic call_child(input int core, input int child, input [255:0] args, output [31:0] ret);
    logic [31:0] timeout;
    //Function call
    rv_prnt_reqVld_i   [core] = 1;
    rv_prnt_reqChild_i [core] = child;
    rv_prnt_reqPc_i    [core] = {core[7:0], core[7:0]};
    rv_prnt_reqArgs_i  [core] = args;
    rv_prnt_reqReturn_i[core] = 1;
    while(1) begin
        @(negedge clk);
        if (rv_prnt_reqRdy_o[core]) begin
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: call_child() call timeout, core=%0d child=%0d\n", core, child);
        end
    end
    @(posedge clk);
    rv_prnt_reqVld_i   [core] = 0;
    rv_prnt_reqChild_i [core] = 0;
    rv_prnt_reqPc_i    [core] = 0;
    rv_prnt_reqArgs_i  [core] = 0;
    rv_prnt_reqReturn_i[core] = 0;
    //Wait return
    rv_prnt_retRdy_i   [core] = 1;
    while(1) begin
        @(negedge clk);
        if (rv_prnt_retVld_o[core]) begin
            ret = rv_prnt_retDat_o[core];
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: call_child() return timeout, core=%0d child=%0d\n", core, child);
        end
    end
    @(posedge clk);
    rv_prnt_retRdy_i[core] = 0;
    @(posedge clk);     
endtask


//-----------------
// RISCV bus write
//-----------------
task automatic riscv_wr(int core, input [3:0] cmd, input [31:0] addr, input [31:0] din, input [3:0] strb);
    logic [31:0] timeout;
    rv_we   [core] = strb;
    rv_addr [core] = (cmd << 20) + addr;
    rv_wdata[core] = din;
    timeout = 0;
    while(1) begin
        @(negedge clk);
        if (rv_ready[core]) begin
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_wr() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
    rv_we   [core] = 0;
    rv_addr [core] = 0;
    rv_wdata[core] = 0;
endtask
`ifndef FUNCTION_ARBITER
task automatic riscv_wr2(int core, input [3:0] cmd, input [31:0] addr, input [31:0] din, input [3:0] strb);
    logic [31:0] timeout;
    rv_we   [core] = strb;
    rv_addr [core] = (SET_AP_CTRL << 20) + (cmd << 2) + addr;
    rv_wdata[core] = din;
    timeout = 0;
    while(1) begin
        @(negedge clk);
        if (rv_ready[core]) begin
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_wr() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
    rv_we   [core] = 0;
    rv_addr [core] = 0;
    rv_wdata[core] = 0;
endtask
`endif


//----------------
// RISCV bus read
//----------------
task automatic riscv_rd(input int core, input [3:0] cmd, input [31:0] addr, output [31:0] dout);
    logic [31:0] timeout;

    rv_re   [core] = 1;
    rv_addr [core] = (cmd << 20) + addr;
    timeout = 0;
    while(1) begin
        @(negedge clk);
        if (rv_ready[core]) begin
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_rd() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
    rv_re   [core] = 0;
    rv_addr [core] = 0;
    timeout = 0;
    while (1) begin
        @(negedge clk);
        if (rv_valid[core]) begin
            dout = rv_rdata[core];
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_rd() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
endtask
`ifndef FUNCTION_ARBITER
task automatic riscv_rd2(input int core, input [3:0] cmd, input [31:0] addr, output [31:0] dout);
    logic [31:0] timeout;
    rv_re   [core] = 1;
    rv_addr [core] = (SET_AP_CTRL << 20) + (cmd << 2) + addr;
    timeout = 0;
    while(1) begin
        @(negedge clk);
        if (rv_ready[core]) begin
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_rd() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
    rv_re   [core]  = 0;
    rv_addr [core] = 0;
    timeout = 0;
    while (1) begin
        @(negedge clk);
        if (rv_valid[core]) begin
            dout = rv_rdata[core];
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_rd() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
endtask
`endif


//---------------------
// RISCV xcache write
//---------------------
task automatic riscv_xcache_wr(int core, input [31:0] addr, input [31:0] din, input [3:0] strb);
    logic [31:0] timeout;
    rv_xcache_part [core] = core;
    rv_xcache_we   [core] = strb;
    rv_xcache_addr [core] = addr;
    rv_xcache_wdata[core] = din;
    timeout = 0;
    while(1) begin
        @(negedge clk);
        if (rv_xcache_ready[core]) begin
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_xcache_wr() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
    rv_xcache_part [core] = 0;
    rv_xcache_we   [core] = 0;
    rv_xcache_addr [core] = 0;
    rv_xcache_wdata[core] = 0;
endtask


//---------------------
// RISCV xcache read
//---------------------
task automatic riscv_xcache_rd(input int core, input [31:0] addr, output [31:0] dout);
    logic [31:0] timeout;

    rv_xcache_part [core] = core;
    rv_xcache_re   [core] = 1;
    rv_xcache_addr [core] = addr;
    timeout = 0;
    while(1) begin
        @(negedge clk);
        if (rv_xcache_ready[core]) begin
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_xcache_rd() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
    rv_xcache_part [core] = 0;
    rv_xcache_re   [core] = 0;
    rv_xcache_addr [core] = 0;
    timeout = 0;
    while (1) begin
        @(negedge clk);
        if (rv_xcache_valid[core]) begin
            dout = rv_xcache_rdata[core];
            break;
        end
        timeout++;
        if (timeout == 100000) begin
            $display("ERROR: riscv_xcache_rd() timeout, core=%0d\n", core);
            $stop;
        end
    end
    @(posedge clk);
endtask


//-------------
// XMME Access
//-------------
//Initialize XMEM by RISCV 0
task automatic xmem_init(input int core, input [31:0] offset, input [31:0] din, input [31:0] width);
    if (width == 8)       riscv_xcache_wr(core, offset, din, 4'b0001);    
    else if (width == 16) riscv_xcache_wr(core, offset, din, 4'b0011);    
    else                  riscv_xcache_wr(core, offset, din, 4'b1111);    
    if (ENABLE_LOG) $display("xmem init: offset=%0d din=%0d", offset, din);
endtask
//Write XMEM by RISCV 1
task automatic xmem_write(input int core, input [31:0] offset, input [31:0] din, input [31:0] width);
    if (width == 8)       riscv_xcache_wr(core, offset, din, 4'b0001);
    else if (width == 16) riscv_xcache_wr(core, offset, din, 4'b0011);
    else                  riscv_xcache_wr(core, offset, din, 4'b1111);
    if (ENABLE_LOG) $display("xmem write: offset=%0d din=%0d", offset, din);
endtask
//Read XMEM by RISCV 1
task automatic xmem_read(input int core, input [31:0] offset, output [31:0] dout, input [31:0] width);
    riscv_xcache_rd(core, offset, dout);
    if (width == 8)      dout &= 8'hff;
    else if (width == 16) dout &= 16'hffff;
    else                 dout &= 32'hffffffff;
    if (ENABLE_LOG) $display("xmem read: offset=%0d dout=%0d", offset, dout);
endtask
//Write XMEM by RISCV 1 (64 bits)
task automatic xmem_write64(input int core, input [31:0] offset, input [63:0] din);
    riscv_xcache_wr(core, offset + 0, din[31: 0], 4'b1111);
    riscv_xcache_wr(core, offset + 4, din[63:32], 4'b1111);
    if (ENABLE_LOG) $display("xmem write: offset=%0d din=%0d", offset, din);
endtask
//Read XMEM by RISCV 1 (64 bits)
task automatic xmem_read64(input int core, input [31:0] offset, output [63:0] dout);
    riscv_xcache_rd(core, offset + 0, dout[31: 0]);
    riscv_xcache_rd(core, offset + 4, dout[63:32]);
    if (ENABLE_LOG) $display("xmem read: offset=%0d dout=%0d", offset, dout);
endtask

task automatic dcache_write(input [31:0] offset, input [31:0] din, input [31:0] width);

    if (width == 64) begin
        $display("Warning: dcache_write 64bit, chop to 32bit. offset=%d", offset);
    end else if (width != 32) begin
        $error("Unhandled dcache width, width = %d", width);
        $stop;
    end

    tb_top.cache.mem[offset] = din[7:0];
    tb_top.cache.mem[offset+1] = din[15:8];
    tb_top.cache.mem[offset+2] = din[23:16];
    tb_top.cache.mem[offset+3] = din[31:24];

    if (ENABLE_LOG) $display("dcache write: offset=%0d din=%0d", offset, din);
endtask

task automatic dcache_read(input [31:0] offset, output [31:0] dout, input [31:0] width);

    if (width == 64) begin
        $display("Warning: dcache_read 64bit, chop to 32bit. offset=%d", offset);
    end else if (width != 32) begin
        $error("Unhandled dcache width, width = %d", width);
        $stop;
    end

    dout[7:0] = tb_top.cache.mem[offset];
    dout[15:8] = tb_top.cache.mem[offset+1];
    dout[23:16] = tb_top.cache.mem[offset+2];
    dout[31:24] = tb_top.cache.mem[offset+3];

    if (ENABLE_LOG) $display("dcache read: offset=%0d dout=%0d", offset, dout);
endtask

//-------------
// ap control
//-------------
task automatic ap_call_0(input int core, input int hls_id, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, 256'd0, ret);
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_START, (0 << 4) + (hls_id << 7), 0, 4'b1111);
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 	
		riscv_wr(0, SET_AP_START, hls_id << 2, 0, 4'b1111);
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask



//1 argument
task automatic ap_call_1(input int core, input int hls_id, input [31:0] arg0, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, arg0, ret);
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_START, (0 << 4) + (hls_id << 7), arg0, 4'b1111);  
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 
		riscv_wr(0, SET_AP_START, hls_id << 2, arg0, 4'b1111);    
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif 
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask






//2 arguments
task automatic ap_call_2(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, {arg1,arg0}, ret);
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_ARGUMENT, (1 << 4) + (hls_id << 7), arg1, 4'b1111);
		riscv_wr2(0, AP_CTRL_START, 	 (0 << 4) + (hls_id << 7), arg0, 4'b1111);
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 
		riscv_wr(0, SET_AP_ARGUMENT, 1 << 2, arg1, 4'b1111);
		riscv_wr(0, SET_AP_START, hls_id << 2, arg0, 4'b1111);    
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif 
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask



//3 arguments
task automatic ap_call_3(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, {arg2,arg1,arg0}, ret);
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_ARGUMENT, (1 << 4) + (hls_id << 7), arg1, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (2 << 4) + (hls_id << 7), arg2, 4'b1111);
		riscv_wr2(0, AP_CTRL_START, 	 (0 << 4) + (hls_id << 7), arg0, 4'b1111);    
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 
		riscv_wr(0, SET_AP_ARGUMENT, 1 << 2, arg1, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 2 << 2, arg2, 4'b1111);
		riscv_wr(0, SET_AP_START, hls_id << 2, arg0, 4'b1111);    
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif 
	
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask
//4 arguments
task automatic ap_call_4(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, {arg3,arg2,arg1,arg0}, ret);
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_ARGUMENT, (1 << 4) + (hls_id << 7), arg1, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (2 << 4) + (hls_id << 7), arg2, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (3 << 4) + (hls_id << 7), arg3, 4'b1111);
		riscv_wr2(0, AP_CTRL_START, 	 (0 << 4) + (hls_id << 7), arg0, 4'b1111);
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 
		riscv_wr(0, SET_AP_ARGUMENT, 1 << 2, arg1, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 2 << 2, arg2, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 3 << 2, arg3, 4'b1111);
		riscv_wr(0, SET_AP_START, hls_id << 2, arg0, 4'b1111);
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif 
	
	
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask






//5 arguments
task automatic ap_call_5(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, 
                         input [31:0] arg4, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, {arg4,arg3,arg2,arg1,arg0}, ret);		 
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_ARGUMENT, (1 << 4) + (hls_id << 7), arg1, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (2 << 4) + (hls_id << 7), arg2, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (3 << 4) + (hls_id << 7), arg3, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (4 << 4) + (hls_id << 7), arg4, 4'b1111);
		riscv_wr2(0, AP_CTRL_START,    (0 << 4) + (hls_id << 7), arg0, 4'b1111);    
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 
		riscv_wr(0, SET_AP_ARGUMENT, 1 << 2, arg1, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 2 << 2, arg2, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 3 << 2, arg3, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 4 << 2, arg4, 4'b1111);
		riscv_wr(0, SET_AP_START, hls_id << 2, arg0, 4'b1111);    
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif 
	
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask




//6 arguments
task automatic ap_call_6(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, 
                        input [31:0] arg4, input [31:0] arg5, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, {arg5,arg4,arg3,arg2,arg1,arg0}, ret);		 
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_ARGUMENT, (1 << 4) + (hls_id << 7), arg1, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (2 << 4) + (hls_id << 7), arg2, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (3 << 4) + (hls_id << 7), arg3, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (4 << 4) + (hls_id << 7), arg4, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (5 << 4) + (hls_id << 7), arg5, 4'b1111);
		riscv_wr2(0, AP_CTRL_START,    (0 << 4) + (hls_id << 7), arg0, 4'b1111);
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 	
		riscv_wr(0, SET_AP_ARGUMENT, 1 << 2, arg1, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 2 << 2, arg2, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 3 << 2, arg3, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 4 << 2, arg4, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 5 << 2, arg5, 4'b1111);
		riscv_wr(0, SET_AP_START, hls_id << 2, arg0, 4'b1111);    
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif
	
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask





//7 arguments
task automatic ap_call_7(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, 
                        input [31:0] arg4, input [31:0] arg5, input [31:0] arg6, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, {arg6,arg5,arg4,arg3,arg2,arg1,arg0}, ret);		 	
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_ARGUMENT, (1 << 4) + (hls_id << 7), arg1, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (2 << 4) + (hls_id << 7), arg2, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (3 << 4) + (hls_id << 7), arg3, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (4 << 4) + (hls_id << 7), arg4, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (5 << 4) + (hls_id << 7), arg5, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (6 << 4) + (hls_id << 7), arg6, 4'b1111);
		riscv_wr2(0, AP_CTRL_START, 	 (0 << 4) + (hls_id << 7), arg0, 4'b1111);
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 	
		riscv_wr(0, SET_AP_ARGUMENT, 1 << 2, arg1, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 2 << 2, arg2, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 3 << 2, arg3, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 4 << 2, arg4, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 5 << 2, arg5, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 6 << 2, arg6, 4'b1111);
		riscv_wr(0, SET_AP_START, hls_id << 2, arg0, 4'b1111);    
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif
	
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask
//8 arguments





task automatic ap_call_8(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, 
                        input [31:0] arg4, input [31:0] arg5, input [31:0] arg6, input [31:0] arg7, output [31:0] ret);    
    `ifdef FUNCTION_ARBITER
        call_child(core, hls_id, {arg7,arg6,arg5,arg4,arg3,arg2,arg1,arg0}, ret);		 	
	`else `ifdef NEW_AP_CTRL_CMD
		riscv_wr2(0, AP_CTRL_ARGUMENT, (1 << 4) + (hls_id << 7), arg1, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (2 << 4) + (hls_id << 7), arg2, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (3 << 4) + (hls_id << 7), arg3, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (4 << 4) + (hls_id << 7), arg4, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (5 << 4) + (hls_id << 7), arg5, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (6 << 4) + (hls_id << 7), arg6, 4'b1111);
		riscv_wr2(0, AP_CTRL_ARGUMENT, (7 << 4) + (hls_id << 7), arg7, 4'b1111);
		riscv_wr2(0, AP_CTRL_START,    (0 << 4) + (hls_id << 7), arg0, 4'b1111);
		riscv_rd2(0, AP_CTRL_DONE, (hls_id << 7), ret);
	`else 
		riscv_wr(0, SET_AP_ARGUMENT, 1 << 2, arg1, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 2 << 2, arg2, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 3 << 2, arg3, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 4 << 2, arg4, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 5 << 2, arg5, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 6 << 2, arg6, 4'b1111);
		riscv_wr(0, SET_AP_ARGUMENT, 7 << 2, arg7, 4'b1111);
		riscv_wr(0, SET_AP_START, hls_id << 2, arg0, 4'b1111);
		riscv_rd(0, WAIT_AP_DONE, 0, ret);
	`endif `endif
    if (ENABLE_LOG) $display("ap control: hls=%0d ret=%0d", hls_id, ret);
endtask


task automatic ap_call_9(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, 
                        input [31:0] arg4, input [31:0] arg5, input [31:0] arg6, input [31:0] arg7, input [31:0] arg8, output [31:0] ret);    
    $display("ap_call_9() is not supported: hls=%0d", hls_id);
    $stop;
endtask


task automatic ap_call_10(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, 
                        input [31:0] arg4, input [31:0] arg5, input [31:0] arg6, input [31:0] arg7, input [31:0] arg8, 
                        input [31:0] arg9, output [31:0] ret);    
    $display("ap_call_10() is not supported: hls=%0d", hls_id);
    $stop;
endtask


task automatic ap_call_11(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, 
                        input [31:0] arg4, input [31:0] arg5, input [31:0] arg6, input [31:0] arg7, input [31:0] arg8, 
                        input [31:0] arg9, input [31:0] arg10, output [31:0] ret);    
    $display("ap_call_11() is not supported: hls=%0d", hls_id);
    $stop;
endtask


task automatic ap_call_12(input int core, input int hls_id, input [31:0] arg0, input [31:0] arg1, input [31:0] arg2, input [31:0] arg3, 
                        input [31:0] arg4, input [31:0] arg5, input [31:0] arg6, input [31:0] arg7, input [31:0] arg8, 
                        input [31:0] arg9, input [31:0] arg10, input [31:0] arg12, output [31:0] ret);    
    $display("ap_call_12() is not supported: hls=%0d", hls_id);
    $stop;
endtask