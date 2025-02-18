////////////////////////////////////////////////////////////////////////////////
// Company            : ViShare Technology Limited
// Designed by        : Edward Leung
// Date Created       : 2021-04-26
//
// Description        : v1.0 Common macro for coherence cache.
//                      v2.0 Use package to replace macro
////////////////////////////////////////////////////////////////////////////////

package coherence_cache_pkg;
    
    //MESIF (one-hot)
    localparam INVALID        = 0;   //bit0
    localparam EXCLUSIVE      = 1;   //bit1
    localparam MODIFIED       = 2;   //bit2
    localparam SHARED         = 3;   //bit3
    localparam FORWARD        = 4;   //bit4
    
    //Processor operation
    parameter PROC_OP_BITS    = 1;
    parameter PR_RD           = 0;
    parameter PR_WR           = 1;
        
    //Bus operation
    parameter BUS_OP_BITS     = 2;
    parameter BUS_RD          = 0;
    parameter BUS_RDX         = 1;
    parameter BUS_UPGR        = 2;
    parameter BUS_NOP         = 3;
    
    //Bus response (bit vector)
    parameter BUS_RESP_BITS   = 3;
    parameter LINE_EXIST_BIT  = 0;
    parameter FLUSH_OPT_BIT   = 1;
    parameter FLUSH_BIT       = 2;
    parameter LINE_EXIST      = (1 << LINE_EXIST_BIT);
    parameter FLUSH_OPT       = (1 << LINE_EXIST_BIT) | (1 << FLUSH_OPT_BIT);
    parameter FLUSH           = (1 << LINE_EXIST_BIT) | (1 << FLUSH_BIT);

endpackage : coherence_cache_pkg