package cacheIf_axi4_pkg;
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

endpackage