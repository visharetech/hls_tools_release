package dma_axiStream_axi4_pkg_t;
    typedef enum {
        AxSIZE_1B    = 0,
        AxSIZE_2B    = 1,
        AxSIZE_4B    = 2,
        AxSIZE_8B    = 3,
        AxSIZE_16B   = 4,
        AxSIZE_32B   = 5,
        AxSIZE_64B   = 6,
        AxSIZE_128B  = 7
    } axsize_t;

    typedef enum {
        AxBURST_FIXED = 0,
        AxBURST_INCR  = 1,
        AxBURST_WRAP  = 2,
        AxBURST_Rsvd  = 3
    } axburst_t;

    typedef enum {
        xRESP_OKAY   = 0,
        xRESP_EXOKAY = 1,
        xRESP_SLVERR = 2,
        xRESP_DECERR = 3
    } xresp_t;

    typedef enum logic{
        DMA_DIR_AXI_STREAM_TO_AXI4 = 1'b0,
        DMA_DIR_AXI4_TO_AXI_STREAM = 1'b1
    }dma_axis_axi4_dir_t;

    typedef enum logic{
        DMA_DIRECT_MODE   = 1'b0,
        DMA_CIRCULAR_MODE = 1'b1
    }dma_axis_axi4_moder_t;

    typedef enum logic [3 : 0] {
        DMA_AXIS_AXI4_CTRL        = 'h0,
        DMA_AXIS_AXI4_MIN_ADDR    = 'h1,
        DMA_AXIS_AXI4_MAX_ADDR    = 'h2,
        DMA_AXIS_AXI4_DMA_START   = 'h3,
        DMA_AXIS_AXI4_DMA_LEN     = 'h4,
        DMA_AXIS_AXI4_DMA_DIR     = 'h5,
        DMA_AXIS_AXI4_DMA_MODE    = 'h6,
        DMA_AXIS_AXI4_FLUSH_FIFO  = 'h7,
        DMA_AXIS_AXI4_FIFO_STATUS = 'h8,
        DMA_AXIS_AXI4_FIFO_CNT    = 'h9,
        DMA_AXI4_AXIS_FIFO_CNT    = 'hA
    }dma_axis_axi4_regs_t;

endpackage