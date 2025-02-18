#ifndef COMMON_WITH_HLS_H
#define COMMON_WITH_HLS_H

#include <stdint.h>
#include <stdbool.h>
#ifndef WIN32
#define _ALIGN                  __attribute__((aligned(4)))
#else
#define _ALIGN 
#endif

//Vitis HLS: Common ports of ap_core, ap_part & ap_parent
#if __VITIS_HLS__
    #define HLS_COMMON_INIT_VAR()	uint8_t ap_core=0; uint8_t ap_part = 0; uint8_t ap_parent = 0;
    #define HLS_COMMON_ARG          uint8_t ap_core, uint8_t ap_part, uint8_t ap_parent, 
    #define HLS_COMMON_ARG_CALL     ap_core, ap_part, ap_parent, 
#else
    #define HLS_COMMON_ARG
    #define HLS_COMMON_ARG_CALL
    #define HLS_COMMON_INIT_VAR
#endif

#if ENABLE_DCACHE

    #define DCACHE_SIZE     0x1FFFFFFF
    //#define DCACHE_SIZE     0x3FFFFFF

    #if __VITIS_HLS__
        typedef int32_t dcache_ptr_t;
    #else
        typedef intptr_t dcache_ptr_t;
    #endif

    //dc_xxx_p is explicitly used to transfer the memory offset of DACHE to HLS function.
    //In linux / Windows / riscv, DCACHE[] base address 0, so there is no impact on array range
    //In HLS, uint32_t dcache[DCACHE_SIZE] argument should be added if access the data from DCache. 
    #if CAPTURE_COSIM
        #define DCACHE_ARG(type, name, size)   uint32_t dc_##name[((sizeof(type) * (size)) +3)/sizeof(uint32_t)], uintptr_t dc_##name##_p
        #define DCACHE_ARG_CALL(name)          (uint32_t*)(name), (uintptr_t)(name)
        #define DCACHE_ARG_FORWARD(name)       dc_##name, dc_##name##_p  //smply pass the variable to another without altering its value
    #elif __VITIS_HLS__
        #define DCACHE_ARG(type, name, size)   uint32_t dc_##name##_p
        #define DCACHE_ARG_CALL(name)          (uint32_t)(name)
        #define DCACHE_ARG_FORWARD(name)       dc_##name##_p
    #else
        #define DCACHE_ARG(type, name, size)   uintptr_t dc_##name##_p
        #define DCACHE_ARG_CALL(name)          (uintptr_t)(name)
        #define DCACHE_ARG_FORWARD(name)       dc_##name##_p
    #endif


    #if __VITIS_HLS__
        #define DCACHE_GET(var_name)	    &dcache[dc_##var_name##_p / 4];
        #define DCACHE_GET_RAW(var_name)    &dcache[var_name]
    #else
        #define DCACHE_GET(var_name)		(dc_##var_name##_p & ~3);
    #endif

#endif

//=== function arbiter begin
//edward 2024-10-25: one more 32-bit argument.
//Different usage with child type:
//1. HLS  : {returnReq, 15'b0, partition[7:0], riscv[7:0]} 
//2. DF   : {returnReq, pc index[6:0], dependence[7:0], cmdr index[7:0], riscv[7:0]}
//3. RISCV: {returnReq, pc[30:0]}
#define FUNC_ARBITER_ARG_NUM         9

//The child id mapping for riscv cores are
//CHILD ID for RISCV0 is 2+256
//CHILD ID for RISCV1 is 3+256
//CHILD ID for RISCV2 is 4+256
//CHILD ID for RISCV3 is 5+256
//CHILD ID for RISCV4 is 6+256
#define RV_CHILD_ID    2+256
typedef int (*rv_proc)(int arg0, int arg1, int arg2, int arg3, int arg4, int arg5, int arg6, int arg7);


//Vitis HLS: definition of the 9th parameter of function arbiter command fifo interface
#if __VITIS_HLS__
    #define CHILD_PARAM8                  (ap_core | (ap_part<<8) | (ap_parent<<16))
    #define CMDR_PARAM8(id, depend, pc)   ((depend == -1)? (ap_core | (id << 8) | (pc << 24)) : (ap_core | (id << 8) | (pc << 24) | ((depend + 0x80) << 16)))
    #define RV_PARAM8(pc)                 pc
#else
    #define CHILD_PARAM8                  0
    #define CMDR_PARAM8(...)              0
    #define RV_PARAM8(pc)                 pc
#endif

#define FUNC_ARBITER_FIFO_DEPTH      1
typedef struct {
    int32_t id;
#if __riscv || __VITIS_HLS__
    int param[FUNC_ARBITER_ARG_NUM];
#else
    intptr_t param[FUNC_ARBITER_ARG_NUM];
#endif
}child_cmd_t;

typedef enum st_enum{
    ST_SEND_CMD,
    ST_WAIT_RES,
    ST_DONE
} st_t;


//Vitis HLS: Function arbiter fifo interface
#if __VITIS_HLS__
  #define CMD_FIFO_DEFINE    child_cmd_t *call_child, int ap_core, int ap_part, int ap_parent,
  #define CMD_FIFO_CALL      call_child, ap_core, ap_part, ap_parent,
#else
  #define CMD_FIFO_DEFINE
  #define CMD_FIFO_CALL
#endif


//=== function arbiter end

#endif