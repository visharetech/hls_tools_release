
module dma_axiStream_axi4_top_t #(
                                    parameter AXI_AW             = 32,
                                    parameter AXI_DW             = 256,
                                    parameter T_DW               = 256,
                                    parameter REGS_DW            = 32,
                                    parameter REGS_AW            = 4,
                                    parameter usr_ram_style      = "distributed",
                                    parameter FIFO_DEPTH         = 16
                          )(
                              //------------------------------------------------                          
                              output logic regs_rdy_o_tp,
                              output logic start_o_tp,
                              output logic stop_o_tp,                                 
                              //------------------------------------------------                          
                          
                              input                         aclk,
                              input                         areset,
							  output 			    		dma_start,	
                              output                        dma_finish,

                              output                        awvalid,
                              input                         awready,
                              output  [AXI_AW-1 : 0]        awaddr,
                              output  [7 : 0]               awlen,
                              output  [2 : 0]               awsize,
                              output  [1 : 0]               awburst,
                              output                        wvalid,
                              input                         wready,
                              output  [AXI_DW-1 : 0]        wdata,
                              output  [AXI_DW/8-1 : 0]      wstrb,
                              output                        wlast,
                              input                         bvalid,
                              output                        bready,
                              output                        arvalid,
                              input                         arready,
                              output  [AXI_AW-1 : 0]        araddr,
                              output  [7 : 0]               arlen,
                              output  [2 : 0]               arsize,
                              output  [1 : 0]               arburst,
                              input                         rvalid,
                              output                        rready,
                              input   [AXI_DW-1:0]          rdata,
                              input                         rlast,

                              input                         m_tvalid,
                              output                        m_tready,
                              input   [T_DW-1 : 0]          m_tdata,
                              input   [T_DW/8-1 : 0]        m_tstrb,
                              input   [T_DW/8-1 : 0]        m_tkeep,
                              input                         m_tlast,

                              output                        s_tvalid,
                              input                         s_tready,
                              output  [T_DW-1 : 0]          s_tdata,
                              output  [T_DW/8-1 : 0]        s_tstrb,
                              output  [T_DW/8-1 : 0]        s_tkeep,
                              output                        s_tlast,

                              input                         regs_we,
                              input   [REGS_AW-1 : 0]       regs_addr,
                              input   [REGS_DW-1 : 0]       regs_wdata,
                              output                        regs_rdy,
                              output  [REGS_DW-1 : 0]       regs_rdata
                          );
    logic [REGS_DW-1 : 0] min_addr;
    logic [REGS_DW-1 : 0] max_addr;
    logic [REGS_DW-1 : 0] dma_start_addr;
    logic [REGS_DW-1 : 0] dma_len;
    logic                 dma_dir;
//    logic                 dma_start;
    logic                 dma_stop;
    logic                 flush_fifo_axis_axi4;
    logic                 flush_fifo_axi4_axis;
    logic                 dma_mode;

    logic                 axi4_to_stream_busy;
    logic                 stream_to_axi4_busy;

    logic                 axi4_to_stream_finish;
    logic                 stream_to_axi4_finish;

    logic                 axis_axi4_fifo_empty;
    logic                 axis_axi4_fifo_full;
    logic [REGS_DW-1 : 0] axis_axi4_fifo_cnt_bytes;
    logic                 axi4_axis_fifo_empty;
    logic                 axi4_axis_fifo_full;
    logic [REGS_DW-1 : 0] axi4_axis_fifo_cnt_bytes;

    assign dma_finish = axi4_to_stream_finish | stream_to_axi4_finish;

    dma_axiStream_axi4_regs_t #(
            .REGS_DW ( REGS_DW ),
            .REGS_AW ( REGS_AW )
        ) regs (
            //-------------------------------------------------------------------------                          
            .regs_rdy_o_tp        ( regs_rdy_o_tp ),
            .start_o_tp           ( start_o_tp    ),
            .stop_o_tp            ( stop_o_tp     ),                                                  
            //-------------------------------------------------------------------------        
        
            .aclk                 ( aclk          ),
            .areset               ( areset        ),

            .regs_we_i            ( regs_we       ),
            .regs_addr_i          ( regs_addr     ),
            .regs_wdata_i         ( regs_wdata    ),
            .regs_rdata_o         ( regs_rdata    ),
            .regs_rdy_o           ( regs_rdy      ),

            .axi4_to_stream_busy_i( axi4_to_stream_busy ),
            .stream_to_axi4_busy_i( stream_to_axi4_busy ),

            .axis_axi4_fifo_empty (axis_axi4_fifo_empty),
            .axis_axi4_fifo_full  (axis_axi4_fifo_full),
            .axi4_axis_fifo_empty (axi4_axis_fifo_empty),
            .axi4_axis_fifo_full  (axi4_axis_fifo_full),
            .axis_axi4_fifo_cnt_bytes (axis_axi4_fifo_cnt_bytes),
            .axi4_axis_fifo_cnt_bytes (axi4_axis_fifo_cnt_bytes),

            .start_o                ( dma_start            ),
            .stop_o                 ( dma_stop             ),
            .flush_fifo_axis_axi4_o ( flush_fifo_axis_axi4 ),
            .flush_fifo_axi4_axis_o ( flush_fifo_axi4_axis ),
            .min_addr_o             ( min_addr             ),
            .max_addr_o             ( max_addr             ),
            .dma_start_addr_o       ( dma_start_addr       ),
            .dma_len_o              ( dma_len              ),
            .dma_dir_o              ( dma_dir              ),
            .dma_mode_o             ( dma_mode             )
        );

    dma_axi4_to_stream_t #(
        .AXI_AW           ( AXI_AW           ),
        .AXI_DW           ( AXI_DW           ),
        .T_DW             ( T_DW             ),
        .REGS_DW          ( REGS_DW          ),
        .REGS_AW          ( REGS_AW          ),
        .usr_ram_style    ( usr_ram_style    ),
        .FIFO_DEPTH       ( FIFO_DEPTH       )
        )axi4_to_stream(
            .aclk             ( aclk                  ),
            .areset           ( areset                ),
            .tclk             ( aclk                  ),

            .arvalid          ( arvalid               ),
            .arready          ( arready               ),
            .araddr           ( araddr                ),
            .arlen            ( arlen                 ),
            .arsize           ( arsize                ),
            .arburst          ( arburst               ),
            .rvalid           ( rvalid                ),
            .rready           ( rready                ),
            .rdata            ( rdata                 ),
            .rlast            ( rlast                 ),
            .rresp            ( 2'b0                  ),

            .s_tvalid         ( s_tvalid              ),
            .s_tready         ( s_tready              ),
            .s_tdata          ( s_tdata               ),
            .s_tstrb          ( s_tstrb               ),
            .s_tkeep          ( s_tkeep               ),
            .s_tlast          ( s_tlast               ),

            .dma_busy         ( axi4_to_stream_busy   ),
            .dma_finish       ( axi4_to_stream_finish ),
            .dma_start        ( dma_start             ),
            .dma_stop         ( dma_stop              ),
            .flush_fifo       ( flush_fifo_axi4_axis  ),
            .fifo_full_o      ( axi4_axis_fifo_full   ),
            .fifo_empty_o     ( axi4_axis_fifo_empty  ),
            .fifo_cnt_bytes_o (axi4_axis_fifo_cnt_bytes),

            .min_addr         ( min_addr              ),
            .max_addr         ( max_addr              ),
            .dma_start_addr   ( dma_start_addr        ),
            .dma_len          ( dma_len               ),
            .dma_dir          ( dma_dir               )
        );

    dma_stream_to_axi4_t #(
        .AXI_AW           ( AXI_AW           ),
        .AXI_DW           ( AXI_DW           ),
        .T_DW             ( T_DW             ),
        .REGS_DW          ( REGS_DW          ),
        .REGS_AW          ( REGS_AW          ),
        .usr_ram_style    ( usr_ram_style    ),
        .FIFO_DEPTH       ( FIFO_DEPTH       )
        )stream_to_axi4(
            .aclk           ( aclk                  ),
            .areset         ( areset                ),
 //           .tclk           ( aclk                  ),

            .awvalid        ( awvalid               ),
            .awready        ( awready               ),
            .awaddr         ( awaddr                ),
            .awlen          ( awlen                 ),
            .awsize         ( awsize                ),
            .awburst        ( awburst               ),
            .wvalid         ( wvalid                ),
            .wready         ( wready                ),
            .wdata          ( wdata                 ),
            .wstrb          ( wstrb                 ),
            .wlast          ( wlast                 ),
            .bvalid         ( bvalid                ),
            .bready         ( bready                ),

            .m_tvalid       ( m_tvalid              ),
            .m_tready       ( m_tready              ),
            .m_tdata        ( m_tdata               ),
            .m_tstrb        ( m_tstrb                ),
            .m_tkeep        ( m_tkeep               ),
            .m_tlast        ( m_tlast               ),

            .dma_busy       ( stream_to_axi4_busy   ),
            .dma_finish     ( stream_to_axi4_finish ),
            .dma_start      ( dma_start             ),
            .dma_stop       ( dma_stop              ),
            .flush_fifo     ( flush_fifo_axis_axi4  ),
            .fifo_full_o    ( axis_axi4_fifo_full   ),
            .fifo_empty_o   ( axis_axi4_fifo_empty  ),
            .fifo_cnt_bytes_o (axis_axi4_fifo_cnt_bytes),

            .min_addr       ( min_addr              ),
            .max_addr       ( max_addr              ),
            .dma_start_addr ( dma_start_addr        ),
            .dma_len        ( dma_len               ),
            .dma_dir        ( dma_dir               ),
            .dma_mode       ( dma_mode              )
        );


endmodule

