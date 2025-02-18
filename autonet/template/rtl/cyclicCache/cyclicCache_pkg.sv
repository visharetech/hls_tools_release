//`timescale 1ns / 1ps
package cyclicCache_pkg;
    typedef enum logic [1:0]
    {
        MESI_STATE_INVALID     = 'd0,
        MESI_STATE_MODIFIED    = 'd1,
        MESI_STATE_EXCLUSIVE   = 'd2,
        MESI_STATE_SHARED      = 'd3
    } mesi_state_t;

    typedef enum logic [1:0]
    {
        MESI_REQ_NULL                = 'd0,
        MESI_REQ_HANDLE_WRITE_SHARE  = 'd1,
        MESI_REQ_HANDLE_WRITE_MISS   = 'd2,
        MESI_REQ_HANDLE_READ_MISS    = 'd3
    } mesi_req_t;

    typedef enum logic [1:0]
    {
        MESI_ACT_NULL    = 'd0,
        MESI_ACT_REFILL  = 'd1,
        MESI_ACT_FORWARD = 'd2,
        MESI_ACT_REVOKE  = 'd3
    } mesi_action_t;

endpackage