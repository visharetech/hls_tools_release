localparam CALL_PORT     = 4;
localparam RET_PORT      = 4;

localparam LOG_PARENT    = (PARENT == 1)? 1: $clog2(PARENT);
localparam LOG_CHILD     = (CHILD == 1)? 1: $clog2(CHILD);

localparam TOTAL_ARGS_W  = ARG_W * ARG_NUM;
localparam CMD_FIFO_DW   = TOTAL_ARGS_W + LOG_CHILD + 1 + 32;
localparam FULL_RET_DW   = RET_DW + LOG_CHILD;

localparam ARGS_LSB      = 0;
localparam ARGS_MSB      = ARGS_LSB + TOTAL_ARGS_W - 1;
localparam CHILD_PC_LSB  = ARGS_MSB + 1;
localparam CHILD_PC_MSB  = CHILD_PC_LSB + 31;
localparam CHILD_MOD_LSB = CHILD_PC_MSB + 1;
localparam CHILD_MOD_MSB = CHILD_MOD_LSB + LOG_CHILD - 1;
localparam RETREQ_BIT    = CHILD_MOD_MSB + 1;

localparam bit [CALL_PORT-1:0] [7:0] CALL_MUX_IN = getCallPortDistribution(PARENT);
localparam bit [CALL_PORT-1:0] [7:0] CALL_MUX_OUT = getCallPortDistribution(CHILD);
localparam bit [CALL_PORT:0] [7:0] CALL_MUX_IN_IDX = getCallMuxIdx(CALL_MUX_IN);
localparam bit [CALL_PORT:0] [7:0] CALL_MUX_OUT_IDX = getCallMuxIdx(CALL_MUX_OUT);

localparam bit [RET_PORT-1:0] [7:0] RET_MUX_OUT = getRetPortDistribution(PARENT);
localparam bit [RET_PORT-1:0] [7:0] RET_MUX_IN = getRetPortDistribution(CHILD);
localparam bit [RET_PORT:0] [7:0] RET_MUX_IN_IDX = getRetMuxIdx(RET_MUX_IN);
localparam bit [RET_PORT:0] [7:0] RET_MUX_OUT_IDX = getRetMuxIdx(RET_MUX_OUT);

localparam int MAX_RET_MUX_OUT  = getMaxRetMuxOut();

function bit [CALL_PORT-1:0] [7:0] getCallPortDistribution(int port_num);
    int port_idx;
    getCallPortDistribution = '{default: '0};
    for (int i=0; i<port_num; i++) begin
        port_idx = i % CALL_PORT;
        getCallPortDistribution[port_idx]++;
    end
endfunction

function bit [RET_PORT-1:0] [7:0] getRetPortDistribution(int port_num);
    int port_idx;
    getRetPortDistribution = '{default: '0};
    for (int i=0; i<port_num; i++) begin
        port_idx = i % RET_PORT;
        getRetPortDistribution[port_idx]++;
    end
endfunction

function int getMaxRetMuxOut();
    getMaxRetMuxOut = 0;
    for (int i=0; i<RET_PORT; i++) begin
        if (RET_MUX_OUT[i]>getMaxRetMuxOut) getMaxRetMuxOut = RET_MUX_OUT[i];
    end
endfunction

function bit [CALL_PORT:0] [7:0] getCallMuxIdx(bit [CALL_PORT-1:0] [7:0] mux);
    getCallMuxIdx[0] = 0;
    for (int i=1; i<CALL_PORT+1; i++) begin
        getCallMuxIdx[i] = getCallMuxIdx[i-1] + mux[i-1];
    end
endfunction

function bit [RET_PORT:0] [7:0] getRetMuxIdx(bit [RET_PORT-1:0] [7:0] mux);
    getRetMuxIdx[0] = 0;
    for (int i=1; i<RET_PORT+1; i++) begin
        getRetMuxIdx[i] = getRetMuxIdx[i-1] + mux[i-1];
    end
endfunction

function [$clog2(CALL_PORT)-1:0] getCallPort(int idx);
    for (int p=0; p<CALL_PORT; p++) begin
        if (idx>=CALL_MUX_OUT_IDX[p] && (idx<CALL_MUX_OUT_IDX[p+1])) begin
            return p;
        end
    end
    return 0;
endfunction

function [$clog2(RET_PORT)-1:0] getRetPort(int idx);
    for (int p=0; p<RET_PORT; p++) begin
        if (idx>=RET_MUX_OUT_IDX[p] && (idx<RET_MUX_OUT_IDX[p+1])) begin
            return p;
        end
    end
    return 0;
endfunction

//--------------------------------------------------
// Print function arbiter port parameters
//--------------------------------------------------
// synthesis translate_off
// synopsys translate_off
initial begin
    $display("----- Function arbiter -----");
    $display("   PARENT           = %0d", PARENT);
    $display("   CHILD            = %0d", CHILD);
    $display("   CALL_PORT        = %0d", CALL_PORT);
    $display("   RET_PORT         = %0d", RET_PORT);
    $display("   MAX_RET_MUX_OUT  = %0d", MAX_RET_MUX_OUT);
    $write("   CALL_MUX_IN      = {"); for (int i = CALL_PORT-1; i > 0; i--) $write("%0d, ", CALL_MUX_IN     [i]); $display("%0d}", CALL_MUX_IN     [0]);
    $write("   CALL_MUX_IN_IDX  = {"); for (int i = CALL_PORT;   i > 0; i--) $write("%0d, ", CALL_MUX_IN_IDX [i]); $display("%0d}", CALL_MUX_IN_IDX [0]);
    $write("   CALL_MUX_OUT     = {"); for (int i = CALL_PORT-1; i > 0; i--) $write("%0d, ", CALL_MUX_OUT    [i]); $display("%0d}", CALL_MUX_OUT    [0]);
    $write("   CALL_MUX_OUT_IDX = {"); for (int i = CALL_PORT;   i > 0; i--) $write("%0d, ", CALL_MUX_OUT_IDX[i]); $display("%0d}", CALL_MUX_OUT_IDX[0]);
    $write("   RET_MUX_IN       = {"); for (int i = RET_PORT-1;  i > 0; i--) $write("%0d, ", RET_MUX_IN      [i]); $display("%0d}", RET_MUX_IN      [0]);
    $write("   RET_MUX_IN_IDX   = {"); for (int i = RET_PORT;    i > 0; i--) $write("%0d, ", RET_MUX_IN_IDX  [i]); $display("%0d}", RET_MUX_IN_IDX  [0]);
    $write("   RET_MUX_OUT      = {"); for (int i = RET_PORT-1;  i > 0; i--) $write("%0d, ", RET_MUX_OUT     [i]); $display("%0d}", RET_MUX_OUT     [0]);
    $write("   RET_MUX_OUT_IDX  = {"); for (int i = RET_PORT;    i > 0; i--) $write("%0d, ", RET_MUX_OUT_IDX [i]); $display("%0d}", RET_MUX_OUT_IDX [0]);
end
// synopsys translate_on
// synthesis translate_on