`include "common.vh"
//TEST_16_CORES: Change parameters for 16 cores.
package commander_system_pkg;
    
`ifdef ENABLE_DEC
    //Encoder/Decoder enable
    localparam ENABLE_ENCODE              = 0;
    localparam ENABLE_DECODE              = 1;
`else   
    //Encoder/Decoder enable
    localparam ENABLE_ENCODE              = 1;
    localparam ENABLE_DECODE              = 0;
`endif 

    //**************************************
    //***** moved to xmem_param_pkg.sv *****
    //**************************************
    //Top/Left Pixel
    //localparam MAX_FWIDTH                 = 2048;
    //localparam MAX_CTU                    = 64;
    //function [31:0] top_pixel_addr(input [1:0] part, input [1:0] cidx, input [12:0] x0, input shift);
    //    return (part * 3 * MAX_FWIDTH) + (cidx * MAX_FWIDTH) + (x0 >> shift);
    //endfunction
    //function [31:0] left_pixel_addr(input [1:0] part, input [1:0] cidx, input [12:0] y0, input shift);
    //    return (part * 6 * MAX_CTU) + (cidx * MAX_CTU) + ((y0 & (MAX_CTU - 1)) >> shift);
    //endfunction
    //function [31:0] topleft_pixel_addr(input [1:0] part, input [1:0] cidx, input [12:0] y0, input shift);
    //    return (part * 6 * MAX_CTU) + (cidx * MAX_CTU) + ((y0 & (MAX_CTU - 1)) >> shift) + (MAX_CTU * 3) + 3;
    //endfunction
 
    //SPQ parameters
`ifdef TEST_16_CORES
    localparam SPQ_NUM_MAX                = 32;
`else
    localparam SPQ_NUM_MAX                = 16;
`endif
    localparam SPQ_INST_MEM_DEPTH         = 256;
    localparam SPQ_LPR                    = 16;
    localparam SPQ_LP_LEVEL               = 8;
    localparam SPQ_LP_LEN_BIT             = 12;
    localparam SPQ_LP_RAM_STYLE           = "distributed";
    localparam SPQ_LP_QUEUE_DEPTH         = 4;
    localparam SPQ_FLOW                   = 4;
    localparam SPQ_CMD_BIT                = 2;
    localparam SPQ_OP_BIT                 = 4;
    localparam SPQ_PARAM_BIT              = 40; //36; //32!
    localparam SPQ_FLOW_BIT               = 2;
    localparam SPQ_RET_BIT                = 3;
    localparam SPQ_HOLD_CNT_BIT           = 16;
    localparam SPQ_FLOW_PTR_BIT           = 32;
    localparam SPQ_FLOW_PTR_INC_BIT       = 32;
    localparam SPQ_VLANE_BIT              = 16;
    localparam SPQ_MODE_BIT               = 8;
    localparam SPQ_STRIDE_BIT             = 16;
    localparam SPQ_DMA_LEN_BIT            = 16;
    localparam SPQ_DMA_CMD_BIT            = 3;
    localparam SPQ_DMA_FLOW               = 1;
    localparam SPQ_LPR_IDX_BIT            = $clog2(SPQ_LPR);
    localparam SPQ_DMA_FLOW_BIT           = $clog2(SPQ_DMA_FLOW);
    localparam SPQ_INST_BIT               = SPQ_PARAM_BIT + SPQ_OP_BIT;
    localparam SPQ_INST_MEM_DWIDTH        = SPQ_INST_BIT;
    localparam SPQ_INST_MEM_AWIDTH        = $clog2(SPQ_INST_MEM_DEPTH);
    localparam SPQ_CMD_DWIDTH             = SPQ_INST_MEM_DWIDTH + SPQ_CMD_BIT;

    //Task queue
    localparam TSKQ_ARG_NUM               = 8;
    localparam TSKQ_ARG_DEPTH             = 128;
    localparam TSKQ_NUM_DEPTH             = 32;
    localparam TSKQ_IDX_WIDTH             = $clog2(TSKQ_ARG_NUM);
    localparam RETQ_FLOW_NUM              = 16;
    localparam RETQ_DEPTH                 = 128;
    localparam RETQ_IDX_WIDTH             = $clog2(RETQ_FLOW_NUM);

    //Commnader ID
    localparam CMDR_NUM                   = 18;
    localparam CMDR_IDX_WIDTH             = (CMDR_NUM == 1)? 1 : $clog2(CMDR_NUM);
    localparam CMDR_INTRA0                = 0;
    localparam CMDR_DCT                   = 1;
    localparam CMDR_IDCT                  = 2;
    localparam CMDR_GETRES                = 3;
    localparam CMDR_PIXADD                = 4;
    localparam CMDR_QUANT                 = 5;
    localparam CMDR_DEQUANT               = 6;
    localparam CMDR_FILTER16              = 7;
    localparam CMDR_CABAC                 = 8;
    localparam CMDR_INTRA1                = 9;
    localparam CMDR_INTRA2                = 10;
    localparam CMDR_INTRA3                = 11;
    localparam CMDR_INPIX                 = 12;  // 2023-05-15
    localparam CMDR_CABAC_DEC             = 13;  // 2023-06-16
    localparam CMDR_OUTPIX0               = 14;  // 2023-08-04
    localparam CMDR_OUTPIX1               = 15;  // 2023-09-23
    localparam CMDR_OUTPIX2               = 16;  // 2023-09-23
    localparam CMDR_OUTPIX3               = 17;  // 2023-09-23

    //HLS memory port
    localparam MPORT_ADDR_WIDTH           = 32;
    localparam MPORT_DATA_WIDTH           = 256;
    localparam MPORT_STRB_WIDTH           = MPORT_DATA_WIDTH / 8;
    localparam MPORT_WORD_WIDTH           = 32;

    //Flow Cache (for v2.0)
    localparam        DFLOW_NUM           = 19;
`ifdef TEST_16_CORES
    localparam        DFLOW_MAX_PORT      = 16;
`else
    localparam        DFLOW_MAX_PORT      = 8;
`endif
    localparam [31:0] DFLOW_WORD_PER_LINE = 32;
    localparam [31:0] DFLOW_BYTE_PER_WORD = MPORT_WORD_WIDTH / 8;
    localparam [31:0] DFLOW_BYTE_PER_LINE = DFLOW_WORD_PER_LINE * DFLOW_BYTE_PER_WORD;

    //Dataflow direction
    localparam DFLOW_NULL                 = 0;
    localparam DFLOW_SNDR                 = 1;
    localparam DFLOW_RCVR                 = 2;
    localparam DFLOW_BOTH                 = 3;   //For RISCV!!

    //Dataflow index
    localparam [7:0] DFLOW_NEIGHBOR       = 0;
    localparam [7:0] DFLOW_FILTER_OUT     = 1;
    localparam [7:0] DFLOW_FENC_DDR       = 2;
    localparam [7:0] DFLOW_FENC_0         = 3;
    localparam [7:0] DFLOW_FENC_1         = 4;
    localparam [7:0] DFLOW_PREDICT_0      = 5;
    localparam [7:0] DFLOW_PREDICT_1      = 6;
    localparam [7:0] DFLOW_DCT_IN         = 7;
    localparam [7:0] DFLOW_DCT_OUT        = 8;
    localparam [7:0] DFLOW_QUANT_TBL      = 9;
    localparam [7:0] DFLOW_QCOEF_0        = 10;
    localparam [7:0] DFLOW_QCOEF_1        = 11;
    localparam [7:0] DFLOW_IDCT_IN        = 12;
    localparam [7:0] DFLOW_IDCT_OUT       = 13;
    localparam [7:0] DFLOW_RECON          = 14;
    localparam [7:0] DFLOW_FDEC_DDR_0     = 15;
    localparam [7:0] DFLOW_FDEC_DDR_1     = 16;
    localparam [7:0] DFLOW_FDEC_DDR_2     = 17;
    localparam [7:0] DFLOW_FDEC_DDR_3     = 18;
    
    //Dataflow word per line
    function int dflow_line_words(int flow);
        if (flow == DFLOW_FDEC_DDR_0     ) dflow_line_words = DFLOW_WORD_PER_LINE;
        else if (flow == DFLOW_FDEC_DDR_1) dflow_line_words = DFLOW_WORD_PER_LINE;
        else if (flow == DFLOW_FDEC_DDR_2) dflow_line_words = DFLOW_WORD_PER_LINE;
        else if (flow == DFLOW_FDEC_DDR_3) dflow_line_words = DFLOW_WORD_PER_LINE;
        else                               dflow_line_words = DFLOW_WORD_PER_LINE;
    endfunction
    
    //Dataflow sets
    function int dflow_sets(int flow);
        if      (flow == DFLOW_NEIGHBOR                       ) dflow_sets = 128; //256
        else if (flow == DFLOW_FILTER_OUT                     ) dflow_sets = 128; //256
        else if (flow == DFLOW_FENC_DDR  && ENABLE_ENCODE == 1) dflow_sets = 32;
        else if (flow == DFLOW_FENC_0    && ENABLE_ENCODE == 1) dflow_sets = 128; //256
        else if (flow == DFLOW_FENC_1    && ENABLE_ENCODE == 1) dflow_sets = 128; //256
        else if (flow == DFLOW_PREDICT_0                      ) dflow_sets = 128; //256
        else if (flow == DFLOW_PREDICT_1                      ) dflow_sets = 128; //256
        else if (flow == DFLOW_DCT_IN    && ENABLE_ENCODE == 1) dflow_sets = 128; //256
        else if (flow == DFLOW_DCT_OUT   && ENABLE_ENCODE == 1) dflow_sets = 128; //256
        else if (flow == DFLOW_QUANT_TBL && ENABLE_ENCODE == 1) dflow_sets = 32;
        else if (flow == DFLOW_QCOEF_0   && ENABLE_ENCODE == 1) dflow_sets = 128; //256
        else if (flow == DFLOW_QCOEF_1   && ENABLE_ENCODE == 1) dflow_sets = 128; //256
        else if (flow == DFLOW_IDCT_IN                        ) dflow_sets = 128; //256
        else if (flow == DFLOW_IDCT_OUT                       ) dflow_sets = 256;
        else if (flow == DFLOW_RECON                          ) dflow_sets = 128; //256
        else if (flow == DFLOW_FDEC_DDR_0                     ) dflow_sets = 1024; //256
        else if (flow == DFLOW_FDEC_DDR_1                     ) dflow_sets = 1024; //256
        else if (flow == DFLOW_FDEC_DDR_2                     ) dflow_sets = 1024; //256
        else if (flow == DFLOW_FDEC_DDR_3                     ) dflow_sets = 1024; //256
        else                                                    dflow_sets = 32;
`ifdef TEST_16_CORES        
        dflow_sets = dflow_sets * 4;
`endif
    endfunction

    //Dataflow vlane
    //Flow cache is 32-bit data.
    function int dflow_vlane(int flow);
        int bits;
        if      (flow == DFLOW_NEIGHBOR  ) bits = 8;
        else if (flow == DFLOW_FILTER_OUT) bits = 8;
        else if (flow == DFLOW_FENC_DDR  ) bits = 8;
        else if (flow == DFLOW_FENC_0    ) bits = 8;
        else if (flow == DFLOW_FENC_1    ) bits = 8;
        else if (flow == DFLOW_PREDICT_0 ) bits = 8;
        else if (flow == DFLOW_PREDICT_1 ) bits = 8;
        else if (flow == DFLOW_DCT_IN    ) bits = 16;
        else if (flow == DFLOW_DCT_OUT   ) bits = 16;
        else if (flow == DFLOW_QUANT_TBL ) bits = 32;
        else if (flow == DFLOW_QCOEF_0   ) bits = 16;
        else if (flow == DFLOW_QCOEF_1   ) bits = 16;
        else if (flow == DFLOW_IDCT_IN   ) bits = 16;
        else if (flow == DFLOW_IDCT_OUT  ) bits = 16;
        else if (flow == DFLOW_RECON     ) bits = 8;
        else if (flow == DFLOW_FDEC_DDR_0) bits = 8;
        else if (flow == DFLOW_FDEC_DDR_1) bits = 8;
        else if (flow == DFLOW_FDEC_DDR_2) bits = 8;
        else if (flow == DFLOW_FDEC_DDR_3) bits = 8;
        else                               bits = 8;
        dflow_vlane = (bits * 8) / MPORT_WORD_WIDTH;
    endfunction

    //L2 enable
    function int dflow_L2(int flow);
        if      (flow == DFLOW_FENC_DDR  ) return (ENABLE_ENCODE)? 1 : 0;
        else if (flow == DFLOW_QUANT_TBL ) return (ENABLE_ENCODE)? 1 : 0;
        else if (flow == DFLOW_FDEC_DDR_0) return 1;
        else if (flow == DFLOW_FDEC_DDR_1) return 1;
        else if (flow == DFLOW_FDEC_DDR_2) return 1;
        else if (flow == DFLOW_FDEC_DDR_3) return 1;
        else                               return 0;
    endfunction
    
    //Dataflow without refill (writeback only)
    function int dflow_no_refill(int flow);
        if      (flow == DFLOW_FDEC_DDR_0) return 1;
        else if (flow == DFLOW_FDEC_DDR_1) return 1;
        else if (flow == DFLOW_FDEC_DDR_2) return 1;
        else if (flow == DFLOW_FDEC_DDR_3) return 1;
        else                               return 0;
    endfunction

    //Dataflow multi sender port
    function int dflow_sndr(int flow);
        if      (flow == DFLOW_PREDICT_0) return 4;
        else if (flow == DFLOW_PREDICT_1) return 4;
        else if (flow == DFLOW_IDCT_IN  ) return 2;
`ifdef TEST_16_CORES
        else if (flow == DFLOW_NEIGHBOR ) return 16;
`else
        else if (flow == DFLOW_NEIGHBOR ) return 8;
`endif
        else                              return 1;
    endfunction

    //Dataflow multi receiver port
    function int dflow_rcvr(int flow);
        if      (flow == DFLOW_FILTER_OUT) return 4;
        else if (flow == DFLOW_FENC_0    ) return 4;
        else if (flow == DFLOW_RECON     ) return 8;
        else                               return 1;
    endfunction

    //--------------------------
    //RISCV dataflow connection
    //--------------------------
    localparam RISCV_FULL_CONNECT = 0;
    localparam RISCV_DFLOW_PORT   = (RISCV_FULL_CONNECT)? DFLOW_NUM : ((ENABLE_ENCODE)? 7 : 6);
    function void dflow_riscv_port(int flow, output int dir, output int port);
        if (RISCV_FULL_CONNECT) begin
            port = flow;
            dir  = DFLOW_BOTH;
        end
        else begin
            if (ENABLE_ENCODE == 1) begin            
                case (flow)
                    DFLOW_FDEC_DDR_0: begin dir = DFLOW_RCVR; port = 0; end
                    DFLOW_FDEC_DDR_1: begin dir = DFLOW_RCVR; port = 1; end
                    DFLOW_FDEC_DDR_2: begin dir = DFLOW_RCVR; port = 2; end
                    DFLOW_FDEC_DDR_3: begin dir = DFLOW_RCVR; port = 3; end
                    DFLOW_NEIGHBOR  : begin dir = DFLOW_BOTH; port = 4; end
                    DFLOW_IDCT_OUT  : begin dir = DFLOW_SNDR; port = 5; end
                    DFLOW_FILTER_OUT: begin dir = DFLOW_SNDR; port = 6; end
                    default         : begin dir = DFLOW_NULL; port = 0; end
                endcase
            end
            else begin
                case (flow)
                    DFLOW_FDEC_DDR_0: begin dir = DFLOW_RCVR; port = 0; end
                    DFLOW_FDEC_DDR_1: begin dir = DFLOW_RCVR; port = 1; end
                    DFLOW_FDEC_DDR_2: begin dir = DFLOW_RCVR; port = 2; end
                    DFLOW_FDEC_DDR_3: begin dir = DFLOW_RCVR; port = 3; end
                    DFLOW_NEIGHBOR  : begin dir = DFLOW_BOTH; port = 4; end  //debug
                    DFLOW_IDCT_OUT  : begin dir = DFLOW_SNDR; port = 5; end  //debug
                    default         : begin dir = DFLOW_NULL; port = 0; end
                endcase
            end
        end
    endfunction

    //------------------------------
    //Intra filter ports connection
    //------------------------------
    localparam filter16_port_num = 3;
    function void filter16_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_NEIGHBOR;   end
            2      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_FILTER_OUT; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                end
        endcase
    endfunction

    //-----------------------------
    //Input pixel ports connection
    //-----------------------------
    localparam inpix_port_num = 2;
    function void inpix_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_DDR;               end
            1      : begin dir = DFLOW_SNDR; flowNum = 2; flow = {DFLOW_FENC_1, DFLOW_FENC_0}; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                            end
        endcase
    endfunction
    
    //--------------------------------
    //Output pixel 0 ports connection
    //--------------------------------
    localparam outpix0_port_num = 2;
    function void outpix0_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_RECON;      end
            1      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_FDEC_DDR_0; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                end
        endcase
    endfunction
    
    //--------------------------------
    //Output pixel 1 ports connection
    //--------------------------------
    localparam outpix1_port_num = 2;
    function void outpix1_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_RECON;      end
            1      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_FDEC_DDR_1; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                end
        endcase
    endfunction
    
    //--------------------------------
    //Output pixel 2 ports connection
    //--------------------------------
    localparam outpix2_port_num = 2;
    function void outpix2_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_RECON;      end
            1      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_FDEC_DDR_2; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                end
        endcase
    endfunction
    
    //--------------------------------
    //Output pixel 3 ports connection
    //--------------------------------
    localparam outpix3_port_num = 2;
    function void outpix3_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_RECON;      end
            1      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_FDEC_DDR_3; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                end
        endcase
    endfunction

    //-------------------------
    //Intra 0 ports connection
    //-------------------------
    localparam intra0_port_num = 3;
    function void intra0_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        if (ENABLE_ENCODE == 1) begin
            case (port)
                0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_0;                      end
                1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FILTER_OUT;                  end
                2      : begin dir = DFLOW_SNDR; flowNum = 2; flow = {DFLOW_PREDICT_1,DFLOW_PREDICT_0}; end
                default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                                 end
            endcase
        end
        else begin
            case (port)
                0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_0;      end
                1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FILTER_OUT;  end
                2      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_PREDICT_1;   end
                default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                 end
            endcase
        end
    endfunction

    //-------------------------
    //Intra 1 ports connection
    //-------------------------
    localparam intra1_port_num = 3;
    function void intra1_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        if (ENABLE_ENCODE == 1) begin
            case (port)
                0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_0;                      end
                1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FILTER_OUT;                  end
                2      : begin dir = DFLOW_SNDR; flowNum = 2; flow = {DFLOW_PREDICT_1,DFLOW_PREDICT_0}; end
                default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                                 end
            endcase
        end
        else begin
            case (port)
                0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_0;      end
                1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FILTER_OUT;  end
                2      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_PREDICT_1;   end
                default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                 end
            endcase
        end
    endfunction
    
    //-------------------------
    //Intra 2 ports connection
    //-------------------------
    localparam intra2_port_num = 3;
    function void intra2_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        if (ENABLE_ENCODE == 1) begin
            case (port)
                0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_0;                      end
                1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FILTER_OUT;                  end
                2      : begin dir = DFLOW_SNDR; flowNum = 2; flow = {DFLOW_PREDICT_1,DFLOW_PREDICT_0}; end
                default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                                 end
            endcase
        end
        else begin
            case (port)
                0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_0;      end
                1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FILTER_OUT;  end
                2      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_PREDICT_1;   end
                default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                 end
            endcase
        end
    endfunction
    
    //-------------------------
    //Intra 3 ports connection
    //-------------------------
    localparam intra3_port_num = 3;
    function void intra3_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        if (ENABLE_ENCODE == 1) begin
            case (port)
                0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_0;                      end
                1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FILTER_OUT;                  end
                2      : begin dir = DFLOW_SNDR; flowNum = 2; flow = {DFLOW_PREDICT_1,DFLOW_PREDICT_0}; end
                default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                                 end
            endcase
        end
        else begin
            case (port)
                0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_0;      end
                1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FILTER_OUT;  end
                2      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_PREDICT_1;   end
                default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                 end
            endcase
        end
    endfunction
    
    //------------------------------
    //Get residual ports connection
    //------------------------------
    localparam getres_port_num = 3;
    function void getres_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_FENC_1;    end
            1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_PREDICT_0; end
            2      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_DCT_IN;    end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;               end
        endcase
    endfunction
    
    //---------------------
    //DCT ports connection
    //---------------------
    localparam dct_port_num = 2;
    function void dct_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_DCT_IN;  end
            1      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_DCT_OUT; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;             end
        endcase
    endfunction
    
    //--------------------------
    //Quantize ports connection
    //--------------------------
    localparam quant_port_num = 3;
    function void quant_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_DCT_OUT;                 end
            1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_QUANT_TBL;               end
            2      : begin dir = DFLOW_SNDR; flowNum = 2; flow = {DFLOW_QCOEF_1,DFLOW_QCOEF_0}; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;                             end
        endcase
    endfunction
    
    //----------------------------
    //Dequantize ports connection
    //----------------------------
    localparam dequant_port_num = 3;
    function void dequant_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_QCOEF_0; end
            2      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_IDCT_IN; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;             end
        endcase
    endfunction
    
    //----------------------
    //IDCT ports connection
    //----------------------
    localparam idct_port_num = 2;
    function void idct_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_IDCT_IN;  end
            1      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_IDCT_OUT; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;              end
        endcase
    endfunction
    
    //---------------------------
    //Pixel add ports connection
    //---------------------------
    localparam pixadd_port_num = 3;
    function void pixadd_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        dir = DFLOW_NULL;
        flowNum = 0;
        flow = '{default:'0};
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_PREDICT_1; end
            1      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_IDCT_OUT;  end
            2      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_RECON;     end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;               end
        endcase
    endfunction

    //------------------------
    //Cacbac ports connection
    //------------------------
    localparam cabac_enc_port_num = 1;
    function void cabac_enc_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_RCVR; flowNum = 1; flow = DFLOW_QCOEF_1; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;             end
        endcase
    endfunction
    
    //-------------------------------
    //Cacbac decode ports connection
    //-------------------------------
    localparam cabac_dec_port_num = 1;
    function void cabac_dec_port_info(input int port, output int dir, output int flowNum, output [31:0] flow);
        case (port)
            0      : begin dir = DFLOW_SNDR; flowNum = 1; flow = DFLOW_IDCT_IN; end
            default: begin dir = DFLOW_NULL; flowNum = 0; flow = 0;             end
        endcase
    endfunction

endpackage