
`include "common.vh"

//#system connections
//#     hls_module[1:n] --> reqMux[m] --> xmem.mruCache[m]
//#     risc_core       -->

module reqMux_v4 import xcache_param_pkg::*; #(
    parameter string RANGE_TYPE = "SCALAR",
    parameter MUX_NUM       = 16,
    parameter LOG_MUX_NUM   = (MUX_NUM == 1) ? 1 : $clog2(MUX_NUM),
    parameter AW            = 32,
    parameter DW            = 32,
    parameter PORT_IDX      = 0
)
(
    input                                       rstn,
    input                                       clk,

    //connected to config registers
    input [XMEM_AW-1:0]                         rangeStart  [MAX_PARTITION],    //#start address of each memory ranges, namely scalar, array and cyclic
    //# different properties of function argument ports
    //input [XMEM_AW-1:0]                         base        [MUX_NUM],          //# xmem address if scalar or the first address if scalar or cyclic
    input [1:0]                                 in2Type     [MUX_NUM],          //# either read or write
    //input [7:0]                                 in2Width    [MUX_NUM],          //# data width

    input [XMEM_AW-1:0]                         base_mem_wdat,
    input [LOG_MUX_NUM-1:0]                     base_mem_wadr,
    input                                       base_mem_we,

    /*input [1:0]                                 in2Type_mem_wdat,
    input [LOG_MUX_NUM-1:0]                     in2Type_mem_wadr,
    input                                       in2Type_mem_we,*/

    input [7:0]                                 in2Width_mem_wdat,
    input [LOG_MUX_NUM-1:0]                     in2Width_mem_wadr,
    input                                       in2Width_mem_we,

    //connected to hls functions
    //# different types of xmem request signals sent from each HLS argument port to req_mux
    input                                       f_ap_ce     [MUX_NUM],          //# HLS function ap_ce indicating HLS pipeline is stall or not
    input                                       f_argVld    [MUX_NUM],          //# requested valid
    input [AW-1:0]                              f_adr       [MUX_NUM],          //# requested xmem address
    input [DW-1:0]                              f_wdat      [MUX_NUM],          //# requested write data
    //# different types of req_mux feedback signals sent from req_mux to each HLS argument port
    output logic                                f_argRdy    [MUX_NUM],          //# request ready for each argument
    output logic                                f_argAck    [MUX_NUM],          //# acknowledgement to each argument access
    output logic [DW-1:0]                       f_rdat      [MUX_NUM],          //# read data for each argument
    output logic                                f_rdat_vld  [MUX_NUM],          //# read valid for each argument

    //connect to riscv
    input                                       matched,                        //# set if RISC address match the memory range associated with this reqMux
    output logic                                risc_argRunning_r,
    output logic                                risc_argRdy,
    input [3:0]                                 risc_argWe,
    input [LOG2_MAX_PARTITION-1:0]              risc_argPartIdx,
    input                                       risc_argRe,
    output logic                                risc_argAck,
    input [XMEM_AW-1:0]                         risc_argAdr,
    input [DW-1:0]                              risc_argWdat,
    output logic [DW-1:0]                       risc_argRdat,
    output logic                                risc_argRdat_vld,

    //# signals from req_mux to the attached xmem.mru_cache
    input                                       mux_ready,    //pls rename mux_ready as mru_ready
    output logic                                mux_re,
    output logic                                mux_we,
    output logic [1:0]                          mux_len,
    output logic [LOG2_MAX_PARTITION-1:0]       mux_part_idx,
    output logic [XMEM_AW-1:0]                  mux_adr,
    output logic [DW-1:0]                       mux_din,
    input [DW-1:0]                              mux_dout,
    input                                       mux_dout_vld
);

//localparam int LOG_MUX_NUM = (MUX_NUM == 1)? 1 : $clog2(MUX_NUM);
localparam int RFIFO_DEPTH = 16;
localparam int RFIFO_AW = $clog2(RFIFO_DEPTH);

//-----------------------------------------
//Stage 0 signals
//-----------------------------------------
logic [MUX_NUM-1:0]               s0_f_argAck;
logic [MUX_NUM-1:0]               s0_f_argVld, s0_f_argVld_r;                    //# requested valid
logic [AW-1:0]                    s0_f_adr[MUX_NUM], s0_f_adr_r[MUX_NUM];
logic [DW-1:0]                    s0_f_wdat[MUX_NUM], s0_f_wdat_r[MUX_NUM];
logic [MUX_NUM-1:0]               s0_set_fargVld;
//-----------------------------------------
//Stage 1 signals
//-----------------------------------------
logic [LOG_MUX_NUM-1:0]           s1_selArg, s1_selArg_r;                         //# argument select
logic [MUX_NUM-1:0]               s1_clr_fargVld;                                 //# f_argVld_r is set or clear by s0_set_fargVld and s1_clr_fargVld respectively
logic                             s1_re, s1_re_r;
logic                             s1_we;
logic [XMEM_AW-1:0]               s1_adr;
logic [DW-1:0]                    s1_din;
logic [1:0]                       s1_len;
logic [LOG2_MAX_PARTITION-1:0]    s1_part_idx;
logic [MUX_NUM-1:0]               s1_f_vld;
logic [XMEM_AW-1:0]               base_mem_rdat;
//logic [1:0]                       in2Type_mem_rdat;
logic [7:0]                       in2Width_mem_rdat;
//-----------------------------------------
//Stage 2 signals
//-----------------------------------------
logic                             s2_mux_sel_risc;
logic [LOG_MUX_NUM-1:0]           s2_selArg;
logic                             s2_rfifo_push[MUX_NUM];
logic [DW-1:0]                    s2_rfifo_din;
logic                             s2_rfifo_pop[MUX_NUM];
logic [DW-1:0]                    s2_rfifo_dout[MUX_NUM];
logic                             s2_rfifo_full[MUX_NUM];
logic                             s2_rfifo_empty[MUX_NUM];
logic                             s2_bypass_rdat[MUX_NUM];
logic                             s2_outreg_ready[MUX_NUM];
logic [DW-1:0]                    s2_f_rdat[MUX_NUM], s2_f_rdat_r[MUX_NUM];
logic                             s2_f_rdat_vld[MUX_NUM], s2_f_rdat_vld_r[MUX_NUM];
//-----------------------------------------
//RISCV signals
//-----------------------------------------
logic                             risc_mux_re;
logic                             risc_mux_re_r;
logic                             risc_mux_we;
logic [1:0]                       risc_mux_len;
logic [LOG2_MAX_PARTITION-1:0]    risc_mux_part_idx;
logic [XMEM_AW-1:0]               risc_mux_adr;
logic [DW-1:0]                    risc_mux_din;
logic                             risc_request;
//-----------------------------------------
//Others
//-----------------------------------------
logic                             mux_ready_r;
logic                             mux_re_r;
logic                             mux_we_r;
logic [1:0]                       mux_len_r;
logic [LOG2_MAX_PARTITION-1:0]    mux_part_idx_r;
logic [XMEM_AW-1:0]               mux_adr_r;
logic [DW-1:0]                    mux_din_r;
logic                             mux_sel_risc;
logic                             mux_sel_risc_r;
logic                             f_re[MUX_NUM];                               //# sync 3-cycle latency of HLS
logic                             f_re_r[MUX_NUM];                             //# sync 3-cycle latency of HLS
logic                             f_re_r2[MUX_NUM];                            //# sync 3-cycle latency of HLS
logic                             f_re_r3[MUX_NUM];                            //# sync 3-cycle latency of HLS
logic                             selArg_fifo_full;
logic                             selArg_fifo_empty;


//State machine of RISCV read data
enum logic [0:0]
{
    CHK_ENABLE    = 1'b0,
    WAIT_RDAT_VLD = 1'b1
} risc_argRun_state;


//Calucate mux_len used by SCALAR & ARRAY
function [1:0] get_risc_mux_len(input [3:0] we);
    if (RANGE_TYPE == "CYCLIC") begin
        get_risc_mux_len = 0;
    end
    else begin
        case (we)
            4'h1, 4'h2, 4'h4, 4'h8: get_risc_mux_len = 0;
            4'h3, 4'hC:             get_risc_mux_len = 1;
            4'hF:                   get_risc_mux_len = 3;
            default:                get_risc_mux_len = 2;    //not used
        endcase
    end
endfunction

//Calculate mux_len of HLS request
function [1:0] get_hls_mux_len(input [7:0] width);
    if (RANGE_TYPE == "CYCLIC") begin
        case (width)
            8'd32:   get_hls_mux_len = 0;
            8'd64:   get_hls_mux_len = 1;
            8'd96:   get_hls_mux_len = 2;
            8'd128:  get_hls_mux_len = 3;
        endcase
    end
    else begin
        case (width)
            8'd8:    get_hls_mux_len = 0;
            8'd16:   get_hls_mux_len = 1;
            8'd32:   get_hls_mux_len = 3;
            default: get_hls_mux_len = 2;    //not used
        endcase
    end
endfunction

rfifo_dpram #(
    .usr_ram_style  ( "distributed" ),
    .aw             ( LOG_MUX_NUM   ),
    .dw             ( XMEM_AW       ),
    .max_size       ( MUX_NUM       )
) base_mem (
    .rd_clk         (clk),
    .raddr          (s1_selArg),
    .dout           (base_mem_rdat),
    .wr_clk         (clk),
    .we             (base_mem_we),
    .din            (base_mem_wdat),
    .waddr          (base_mem_wadr)
);

/*rfifo_dpram #(
    .usr_ram_style  ( "distributed" ),
    .aw             ( LOG_MUX_NUM   ),
    .dw             ( 2             ),
    .max_size       ( MUX_NUM       )
) in2Type_mem (
    .rd_clk         (clk),
    .raddr          (s1_selArg),
    .dout           (in2Type_mem_rdat),
    .wr_clk         (clk),
    .we             (in2Type_mem_we),
    .din            (in2Type_mem_wdat),
    .waddr          (in2Type_mem_wadr)
);*/

rfifo_dpram #(
    .usr_ram_style  ( "distributed" ),
    .aw             ( LOG_MUX_NUM   ),
    .dw             ( 8             ),
    .max_size       ( MUX_NUM       )
) in2Width_mem (
    .rd_clk         (clk),
    .raddr          (s1_selArg),
    .dout           (in2Width_mem_rdat),
    .wr_clk         (clk),
    .we             (in2Width_mem_we),
    .din            (in2Width_mem_wdat),
    .waddr          (in2Width_mem_wadr)
);

//=======================================================================================================
//RISC ACCESS
//=======================================================================================================
always_comb begin
    risc_request      = matched && (PORT_IDX == 0); //# Improve timing: If matched=1, it means that there is risc request. .
    risc_mux_re       = risc_argRe && matched && (PORT_IDX == 0);
    risc_mux_we       = (risc_argWe != 0) && matched && (PORT_IDX == 0);
    risc_mux_adr      = risc_argAdr;
    risc_mux_din      = risc_argWdat;
    risc_mux_part_idx = risc_argPartIdx;
    risc_mux_len      = get_risc_mux_len(risc_argWe);
    risc_argAck       = 0;
    risc_argRdy       = mux_ready_r;
    risc_argRdat      = mux_dout;
    //edward 2025-01-28: also output risc_argRdat_vld for SCALAR although xcache top will not use it.
    risc_argRdat_vld  = (RANGE_TYPE == "SCALAR")? (mux_dout_vld & risc_mux_re_r) : (mux_dout_vld & s2_mux_sel_risc);
end
//# risc_argRunning_r is used by xmem top to select riscv read data from scalar, array or cyclic.
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        risc_argRun_state <= CHK_ENABLE;
        risc_argRunning_r <= 0;
        risc_mux_re_r     <= 0;
    end
    else begin
        risc_mux_re_r     <= risc_mux_re;
        case (risc_argRun_state)
            CHK_ENABLE: begin
                risc_argRunning_r <= (mux_re | mux_we) & mux_sel_risc & mux_ready;
                //no need to construct for SCALAR
                if (RANGE_TYPE == "ARRAY" || RANGE_TYPE == "CYCLIC") begin
                    if (mux_re & mux_ready & mux_sel_risc) begin
                        risc_argRun_state <= WAIT_RDAT_VLD;
                    end
                end
            end
            WAIT_RDAT_VLD: begin
                if (mux_dout_vld & s2_mux_sel_risc) begin
                    risc_argRunning_r <= 0;
                    risc_argRun_state <= CHK_ENABLE;
                end
            end
        endcase
    end
end


//=======================================================================================================
//FUNC ACCESS
//=======================================================================================================
always_comb begin
    //---------------------------------------------
    // Ready signal to argument requst port
    //---------------------------------------------
    if (RANGE_TYPE == "ARRAY" || RANGE_TYPE == "CYCLIC") begin
        //Port is not ready if any:
        //1. Not selected by arbiter.
        //2. Read data is not valid at stage3.
        //3. Cache is not ready??? If cache is not ready, arbiter will not select it that is covered by case 1.
        for (int a = 0; a < MUX_NUM; a++) begin
            f_argRdy[a] = ~(s0_f_argVld_r[a] == 1 && s1_f_vld[a] == 0) && ~(f_re_r3[a] == 1 && f_rdat_vld[a] == 0);
        end
    end
    else begin
        f_argRdy = '{default:1'b1};
    end
end
always_comb begin
    //---------------------------------------------
    //stage 0: Register HLS request
    //---------------------------------------------
    //# select either the current hls argument request or registered request
    s0_f_argAck     = 0;
    s0_f_adr        = s0_f_adr_r;
    s0_f_wdat       = s0_f_wdat_r;
    s0_set_fargVld  = 0;
    for (int a = 0; a < MUX_NUM; a++) begin
        s0_f_argVld[a] = f_argRdy[a] & f_argVld[a];
        if (f_argRdy[a] & f_argVld[a]) begin
            s0_set_fargVld[a] = 1;
            s0_f_adr      [a] = f_adr[a];
            s0_f_wdat     [a] = f_wdat[a];
            s0_f_argAck   [a] = 1;    //# grant for f_argAck 1
        end
        f_re[a] = f_argVld[a] & f_ap_ce[a] & (in2Type[a] == READ);
        //edward 2025-02-14: argAck is output after selected by arbiter at stage1
        //f_argAck[a] = s0_f_argAck[a];
    end

    //---------------------------------------------
    //stage 1: Arbiter and cache/RAM request
    //---------------------------------------------
    //# Select one of the argument request to access xmem
    s1_selArg      = s1_selArg_r;
    s1_f_vld       = 0;
    s1_clr_fargVld = 0;
    f_argAck     = '{default:'0};
    if (~risc_request & mux_ready_r) begin
        for (int a = 0; a < MUX_NUM; a++) begin
            if (s0_f_argVld_r[a]) begin
                s1_selArg         = a;
                s1_f_vld[a]       = 1;
                s1_clr_fargVld[a] = 1;
                //edward 2025-02-14: argAck is output after selected by arbiter at stage1
                f_argAck[a]       = 1;
                break;
            end
        end
    end
    //# Request cache/RAM
    s1_re       = (s0_f_argVld_r != 0) & ~risc_request & (in2Type[s1_selArg] == READ );
    s1_we       = (s0_f_argVld_r != 0) & ~risc_request & (in2Type[s1_selArg] == WRITE);
    //edward 2025-01-27
    //s1_adr    = (RANGE_TYPE == "SCALAR")? base[s1_selArg] : (base[s1_selArg] + s0_f_adr_r[s1_selArg][XMEM_PART_AW-1:0]);
    //s1_adr      = (RANGE_TYPE == "SCALAR")? base[s1_selArg] : (base[s1_selArg] + s0_f_adr_r[s1_selArg]);
    s1_adr      = (RANGE_TYPE == "SCALAR")? base_mem_rdat : (base_mem_rdat + s0_f_adr_r[s1_selArg]);
    s1_din      = s0_f_wdat_r[s1_selArg];
    s1_len      = get_hls_mux_len(/*in2Width[s1_selArg]*/in2Width_mem_rdat);
    //edward 2025-01-27: match partition bit defined in custom_connection like:
    //                   scalar_adr = {ap_part_w[0+:LOG2_MAX_PARTITION], {SCALAR_SUBBANK_BYTE_AW{1'b0}}}
    s1_part_idx = (RANGE_TYPE == "SCALAR")? s0_f_adr_r[s1_selArg][XMEM_PART_AW+LOG2_MAX_PARTITION-1:XMEM_PART_AW] : 0;
    //s1_part_idx = (RANGE_TYPE == "SCALAR")? s0_f_adr_r[s1_selArg][SCALAR_SUBBANK_BYTE_AW+LOG2_MAX_PARTITION-1:SCALAR_SUBBANK_BYTE_AW] : 0;

    //---------------------------------------------
    //stage 2: RAM/cache read valid
    //---------------------------------------------
    //# each HLS requested argument may be return at different cycles due to cache misses or access contension.
    //  rfifo is inserted in the data-return path to align the read data time of different argument ports
    //# mru_cache --> rfifo --> rdat --> hls
    s2_rfifo_din    = mux_dout;
    s2_rfifo_push   = '{default: '0};
    s2_rfifo_pop    = '{default: '0};
    s2_bypass_rdat  = '{default: '0};
    s2_outreg_ready = '{default: '0};
    s2_f_rdat_vld   = '{default: '0};
    s2_f_rdat       = s2_f_rdat_r;
    if (RANGE_TYPE == "ARRAY" || RANGE_TYPE == "CYCLIC") begin

        //# Output data register (stage 3) is ready
        for (int a = 0; a < MUX_NUM; a++) begin
            s2_outreg_ready[a] = ~s2_f_rdat_vld_r[a] | (f_ap_ce[a] & f_re_r3[a]);
        end

        //# xmem read data for the argument a0 of function f0 are first push to the rfifo allocated for this port
        //Push to rFifo if any:
        //1. Fifo is not empty
        //2. Output data is still in stage3 output register
        if (mux_dout_vld & ~s2_mux_sel_risc) begin
            if (~s2_rfifo_empty[s2_selArg] | ~s2_outreg_ready[s2_selArg]) begin
                s2_rfifo_push[s2_selArg] = 1;
            end
            else begin
                s2_bypass_rdat[s2_selArg] = 1;
            end
        end

        //# if output register in stage 2 is ready, either pop from fifo or bypass data.
        for (int a = 0; a < MUX_NUM; a++) begin
            s2_rfifo_pop[a] = ~s2_rfifo_empty[a] & s2_outreg_ready[a];
            if (s2_rfifo_pop[a]) begin
                s2_f_rdat[a] = s2_rfifo_dout[a];
                s2_f_rdat_vld[a] = 1;
            end
            else if (s2_bypass_rdat[a] & s2_outreg_ready[a]) begin
                s2_f_rdat[a] = mux_dout;
                s2_f_rdat_vld[a] = 1;
            end
        end
    end
    else begin //SCALAR
        for (int a = 0; a < MUX_NUM; a++) begin
            f_rdat[a] = mux_dout;
            f_rdat_vld[a] = (a == s1_selArg_r && s1_re_r == 1)? mux_dout_vld : 0;
        end
    end

    //---------------------------------------------
    //stage 3: Register read data to HLS
    //---------------------------------------------
    if (RANGE_TYPE == "ARRAY" || RANGE_TYPE == "CYCLIC") begin
        f_rdat = s2_f_rdat_r;
        for (int a = 0; a < MUX_NUM; a++) begin
            f_rdat_vld[a] = s2_f_rdat_vld_r[a] & f_re_r3[a];
        end
    end
end
// Registers
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        s0_f_argVld_r    <= 0;
        s0_f_adr_r       <= '{default: '0};
        s0_f_wdat_r      <= '{default: '0};
        s1_re_r          <= 0;
        s1_selArg_r      <= 0;
        s2_f_rdat_r      <= '{default: '0};
        s2_f_rdat_vld_r  <= '{default: '0};
        f_re_r           <= '{default: '0};
        f_re_r2          <= '{default: '0};
        f_re_r3          <= '{default: '0};
    end
    else begin
        //Stage 0
        s0_f_adr_r  <= s0_f_adr;
        s0_f_wdat_r <= s0_f_wdat;
        for (int a = 0; a < MUX_NUM; a++) begin
            //Clear and set argVld flag
            if (s0_set_fargVld[a]) begin
                s0_f_argVld_r[a] <= 1;
            end
            else if (s1_clr_fargVld[a]) begin
                s0_f_argVld_r[a] <= 0;
            end
        end
        //Stage 1
        s1_re_r     <= s1_re;
        s1_selArg_r <= s1_selArg;
        //Stage 2: hold if HLS is not ready (ap_ce=0)
        for (int a = 0; a < MUX_NUM; a++) begin
            if (s2_outreg_ready[a]) begin
                s2_f_rdat_r[a]     <= s2_f_rdat[a];
                s2_f_rdat_vld_r[a] <= s2_f_rdat_vld[a];
            end
        end
        //Synchronize 3-cycles latency of HLS read with valid signal
        for (int a = 0; a < MUX_NUM; a++) begin
            if (f_ap_ce[a]) begin
                f_re_r[a]  <= f_re[a];
                f_re_r2[a] <= f_re_r[a];
                f_re_r3[a] <= f_re_r2[a];
            end
        end
    end
end


//=======================================================================================================
//RISCV / HLS_FUNCTION -> CACHE / RAM
//=======================================================================================================
always_comb begin
    //# because mux_ready_r is used as ready single for riscv and HLS,
    //  register is used to store request if mux_ready=0 & mux_ready_r=1
    if (~mux_ready_r) begin
        mux_re         = mux_re_r;
        mux_we         = mux_we_r;
        mux_adr        = mux_adr_r;
        mux_len        = mux_len_r;
        mux_din        = mux_din_r;
        mux_part_idx   = mux_part_idx_r;
        mux_sel_risc   = mux_sel_risc_r;
    end
    else if (risc_request) begin
        mux_re        = risc_mux_re;
        mux_we        = risc_mux_we;
        mux_adr       = risc_mux_adr;
        mux_len       = risc_mux_len;
        mux_din       = risc_mux_din;
        mux_part_idx  = risc_mux_part_idx;
        mux_sel_risc  = 1;
    end
    else begin
        mux_re        = s1_re;
        mux_we        = s1_we;
        mux_adr       = s1_adr;
        mux_len       = s1_len;
        mux_din       = s1_din;
        mux_part_idx  = s1_part_idx;
        mux_sel_risc  = 0;
    end
end
// Registers
always @ (posedge clk or negedge rstn) begin
    if (~rstn) begin
        mux_ready_r     <= 0;
        mux_re_r        <= 0;
        mux_we_r        <= 0;
        mux_adr_r       <= 0;
        mux_din_r       <= 0;
        mux_len_r       <= 0;
        mux_part_idx_r  <= 0;
        mux_sel_risc_r  <= 0;
    end
    else begin
        mux_ready_r     <= mux_ready;
        mux_re_r        <= mux_re;
        mux_we_r        <= mux_we;
        mux_ready_r     <= mux_ready;
        mux_adr_r       <= mux_adr;
        mux_din_r       <= mux_din;
        mux_len_r       <= mux_len;
        mux_part_idx_r  <= mux_part_idx;
        mux_sel_risc_r  <= mux_sel_risc;
    end
end


//=======================================================================================================
//FIFO to synchronous HLS function selArg with cache read data (For ARRAY & CYCLIC)
//=======================================================================================================
//# Push at cycle of cache read request
//# Pop at cycle of cache read data valid
//# Depth must be larger than min latency of cache to make sure that fifo will not overflow/underlow
generate
if (RANGE_TYPE == "ARRAY" || RANGE_TYPE == "CYCLIC") begin
    rfifo #(
        .FIFO_DWIDTH( LOG_MUX_NUM + 1 ),
        .FIFO_DEPTH ( 4               )
    )
    inst_selArg_fifo (
        .rstn  ( rstn                        ),
        .clk   ( clk                         ),
        .full  ( selArg_fifo_full            ),
        .we    ( mux_re & mux_ready          ),
        .din   ( {mux_sel_risc,s1_selArg}    ),
        .re    ( mux_dout_vld                ),
        .empty ( selArg_fifo_empty           ),
        .dout  ( {s2_mux_sel_risc,s2_selArg} )
    );
    // synthesis translate_off
    // synopsys translate_off
    always @ (posedge clk) begin
        if (selArg_fifo_full) begin
            $display("[reqMux] ERROR: selArg_fifo should not overflow");
            $stop;
        end
        if (selArg_fifo_empty & mux_dout_vld) begin
            $display("[reqMux] ERROR: selArg_fifo should not underflow");
            $stop;
        end
    end
    // synopsys translate_on
    // synthesis translate_on
end
else begin
    assign selArg_fifo_full  = 0;
    assign selArg_fifo_empty = 0;
    assign s2_selArg         = 0;
    assign s2_mux_sel_risc   = 0;
end
endgenerate


//=======================================================================================================
//Return FIFO (For ARRAY & CYCLIC)
//=======================================================================================================
generate
    if (RANGE_TYPE == "ARRAY" || RANGE_TYPE == "CYCLIC") begin: TYPE
        for (genvar m = 0; m < MUX_NUM; m++) begin: RFIFO
            rfifo #(
                .FIFO_DWIDTH    ( DW            ),
                .FIFO_DEPTH     ( RFIFO_DEPTH   )
            )
            inst_rfifo (
                .rstn       ( rstn              ),
                .clk        ( clk               ),
                .full       ( s2_rfifo_full [m] ),
                .we         ( s2_rfifo_push [m] ),
                .din        ( s2_rfifo_din      ),
                .re         ( s2_rfifo_pop  [m] ),
                .empty      ( s2_rfifo_empty[m] ),
                .dout       ( s2_rfifo_dout [m] )
            );
        end
    end
    else begin
        assign s2_rfifo_full  = '{default:'0};
        assign s2_rfifo_empty = '{default:'0};
        assign s2_rfifo_dout  = '{default:'0};
    end
endgenerate

endmodule

