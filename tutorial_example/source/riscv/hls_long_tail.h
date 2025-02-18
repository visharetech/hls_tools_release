#ifndef HLS_LONG_TAIL_H
#define HLS_LONG_TAIL_H

#if __riscv

//#include "hls_common.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "../riscv/syscall.h"
#include "../riscv/io_map.h"
#ifndef _MSC_VER
#define nop() asm volatile("nop")
#else
#define nop()
#endif

#if __cplusplus
    extern "C" {
#endif



//edward 2025-02-03
//XMEM adress base (configure)
#define DEC_XMEM_BASE     (LONGTAIL_IO + (XMEM_ACCESS << 20))
#define DEC_DMA_BASE      (LONGTAIL_IO + (DMA_ACCESS << 20))

#define XCACHE_ACCESS_BASE   (0xe0000000)

//edward 2025-02-12
//HLS LOCAL CACHE address base (access)
#define HLS_LCACHE_ACCESS_BASE   (0xd0000000)

//RISCV Command
//edward 2024-05-29: new command for HLS_FUNCTION_ARB
#define XMEM_ACCESS       0    //HLS xmem (v2) access
#define XMEM1_ACCESS      1    //HLS xmem (v1) access (for debug)
#define DMA_ACCESS        2    //Access DMA in long tail functions  
#define GET_HLS_CYCLE     3    //Read profiling cycle (total)
#define GET_HLS_DC_BUSY   4    //Read profiling cycle (dc cache miss)
#define GET_HLS_XMEM_BUSY 5    //Read profiling cycle (xmem2 not ready)
#define GET_HLS_FARB_BUSY 6    //Read profiling cycle (func_arbiter not ready)
#define CLR_HLS_PROFILE   7    //Clear profiling cycle
#define GET_HLS_CALL_CNT  8    //Read call count



//edward 2024-10-09: new cycle profiling with function arbiter and xmem2
//1. total cycle
//2. DCACHE busy cycle
//3. XMEM busy cycle
//4. Function arbiter busy cycel
static ALWAYS_INLINE uint32_t longtail_total_cycle(int id)
{
    uint32_t ret;
#if 1   
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_CYCLE << 20) + (id << 2);
    asm volatile ("lw   %0, 0(%1)" :"=r"(ret):"r"(adr));
#else
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_CYCLE << 20);
    asm volatile ("lw   %0, %2(%1)" :"=r"(ret):"r"(adr & (~0x7ff)),"i"(adr & 0x7ff));
#endif
    return ret;
}
static ALWAYS_INLINE uint32_t longtail_dc_busy(int id)
{
    uint32_t ret;
#if 1   
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_DC_BUSY << 20) + (id << 2);
    asm volatile ("lw   %0, 0(%1)" :"=r"(ret):"r"(adr));
#else
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_DC_BUSY << 20);
    asm volatile ("lw   %0, %2(%1)" :"=r"(ret):"r"(adr & (~0x7ff)),"i"(adr & 0x7ff));
#endif
    return ret;
}
static ALWAYS_INLINE uint32_t longtail_xmem_busy(int id)
{
    uint32_t ret;
#if 1   
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_XMEM_BUSY << 20) + (id << 2);
    asm volatile ("lw   %0, 0(%1)" :"=r"(ret):"r"(adr));
#else
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_XMEM_BUSY << 20);
    asm volatile ("lw   %0, %2(%1)" :"=r"(ret):"r"(adr & (~0x7ff)),"i"(adr & 0x7ff));
#endif
    return ret;
}
static ALWAYS_INLINE uint32_t longtail_farb_busy(int id)
{
    uint32_t ret;
#if 1   
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_FARB_BUSY << 20) + (id << 2);
    asm volatile ("lw   %0, 0(%1)" :"=r"(ret):"r"(adr));
#else
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_FARB_BUSY << 20);
    asm volatile ("lw   %0, %2(%1)" :"=r"(ret):"r"(adr & (~0x7ff)),"i"(adr & 0x7ff));
#endif
    return ret;
}
static ALWAYS_INLINE uint32_t longtail_call_count(int id)
{
    uint32_t ret;
#if 1   
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_CALL_CNT << 20) + (id << 2);
    asm volatile ("lw   %0, 0(%1)" :"=r"(ret):"r"(adr));
#else
    uint32_t adr = (LONGTAIL_IO) + (GET_HLS_CALL_CNT << 20);
    asm volatile ("lw   %0, %2(%1)" :"=r"(ret):"r"(adr & (~0x7ff)),"i"(adr & 0x7ff));
#endif
    return ret;
}
static ALWAYS_INLINE void longtail_clear_profile(int id)
{
#if 1   
    uint32_t adr = (LONGTAIL_IO) + (CLR_HLS_PROFILE << 20) + (id << 2);
    asm volatile ("sw  zero, 0(%0)" ::"r"(adr));
#else
    uint32_t adr = (LONGTAIL_IO) + (CLR_HLS_PROFILE << 20);
    asm volatile ("sw  zero, %1(%0)" ::"r"(adr & (~0x7ff)),"i"(adr & 0x7ff));
#endif
}



#include "hls_dataflow.h"
//edward 2024-05-29: CHILD ID for longtail HLS start from 0.
#define CHILD     (hls_id)
//Request child control
static ALWAYS_INLINE void call_itf_ctrl(int child, int argc, int reqRet)
{
    if (reqRet)
    {
        if (argc == 0)      asm volatile ("slti x0, x16, %0" ::"i"(child + (1 << 10)));
        else if (argc == 1) asm volatile ("slti x0, x17, %0" ::"i"(child + (1 << 10)));
        else if (argc == 2) asm volatile ("slti x0, x18, %0" ::"i"(child + (1 << 10)));
        else if (argc == 3) asm volatile ("slti x0, x19, %0" ::"i"(child + (1 << 10)));
        else if (argc == 4) asm volatile ("slti x0, x20, %0" ::"i"(child + (1 << 10)));
        else if (argc == 5) asm volatile ("slti x0, x21, %0" ::"i"(child + (1 << 10)));
        else if (argc == 6) asm volatile ("slti x0, x22, %0" ::"i"(child + (1 << 10)));
        else if (argc == 7) asm volatile ("slti x0, x23, %0" ::"i"(child + (1 << 10)));
        else if (argc == 8) asm volatile ("slti x0, x24, %0" ::"i"(child + (1 << 10)));
    }
    else
    {
        if (argc == 0)      asm volatile ("slti x0, x0, %0" ::"i"(child + (1 << 10)));
        else if (argc == 1) asm volatile ("slti x0, x1, %0" ::"i"(child + (1 << 10)));
        else if (argc == 2) asm volatile ("slti x0, x2, %0" ::"i"(child + (1 << 10)));
        else if (argc == 3) asm volatile ("slti x0, x3, %0" ::"i"(child + (1 << 10)));
        else if (argc == 4) asm volatile ("slti x0, x4, %0" ::"i"(child + (1 << 10)));
        else if (argc == 5) asm volatile ("slti x0, x5, %0" ::"i"(child + (1 << 10)));
        else if (argc == 6) asm volatile ("slti x0, x6, %0" ::"i"(child + (1 << 10)));
        else if (argc == 7) asm volatile ("slti x0, x7, %0" ::"i"(child + (1 << 10)));
        else if (argc == 8) asm volatile ("slti x0, x8, %0" ::"i"(child + (1 << 10)));
    }
}
//Get return valid from child (timeout version)
static ALWAYS_INLINE int call_itf_return_timeout(int child, uint32_t timeout_cyc)
{    
    int vld, dat;
    uint32_t cyc = cycle32();
    do {
        uint32_t d = cycle32() - cyc;
        if (d > timeout_cyc) {
            exit(1);
        }
        asm volatile ("csrrw %0, %1, x0" :"=r"(vld) :"i"(CSR_CALL_VLD));
    } while (vld == 0);
    asm volatile ("csrrw %0, %1, x0" :"=r"(dat) :"i"(CSR_CALL_DAT));
    return dat;
}
//Get return valid from child
static ALWAYS_INLINE int call_itf_return(int child)
{    
    int vld, dat;
    //edward 2024-11-20: not profile cycle to wait HLS finish
//#if HW_PROFILE
//    hw_ptree_prof_set_enable(0);
//#endif
    do {
        asm volatile ("csrrw %0, %1, x0" :"=r"(vld) :"i"(CSR_CALL_VLD));
    } while (vld == 0);
//#if HW_PROFILE
//    hw_ptree_prof_set_enable(1);
//#endif
    asm volatile ("csrrw %0, %1, x0" :"=r"(dat) :"i"(CSR_CALL_DAT));
    return dat;
}

//Return
static ALWAYS_INLINE int ap_ret(int hls_id)
{
    return call_itf_return(CHILD);
}

//No argument HLS function call
static ALWAYS_INLINE int ap_call_0(int hls_id)
{
    call_itf_ctrl(CHILD, 0, 1);
    hls_func0();
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_0(int hls_id)
{
    call_itf_ctrl(CHILD, 0, 1);
    hls_func0();
}
static ALWAYS_INLINE void ap_call_nb_noret_0(int hls_id)
{
    call_itf_ctrl(CHILD, 0, 0);
    hls_func0();
}

//1 argument HLS function call
static ALWAYS_INLINE int ap_call_1(int hls_id, int arg0)
{
    call_itf_ctrl(CHILD, 1, 1);
    hls_func1(arg0);
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_1(int hls_id, int arg0)
{
    call_itf_ctrl(CHILD, 1, 1);
    hls_func1(arg0);
}
static ALWAYS_INLINE void ap_call_nb_noret_1(int hls_id, int arg0)
{
    call_itf_ctrl(CHILD, 1, 0);
    hls_func1(arg0);
}

//2 arguments HLS function call
static ALWAYS_INLINE int ap_call_2(int hls_id, int arg0, int arg1)
{
    call_itf_ctrl(CHILD, 2, 1);
    hls_func2(arg0, arg1);
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_2(int hls_id, int arg0, int arg1)
{
    call_itf_ctrl(CHILD, 2, 1);
    hls_func2(arg0, arg1);
}
static ALWAYS_INLINE void ap_call_nb_noret_2(int hls_id, int arg0, int arg1)
{
    call_itf_ctrl(CHILD, 2, 0);
    hls_func2(arg0, arg1);
}

//3 arguments HLS function call
static ALWAYS_INLINE int ap_call_3(int hls_id, int arg0, int arg1, int arg2)
{
    call_itf_ctrl(CHILD, 3, 1);
    hls_func3(arg0, arg1, arg2);
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_3(int hls_id, int arg0, int arg1, int arg2)
{
    call_itf_ctrl(CHILD, 3, 1);
    hls_func3(arg0, arg1, arg2);
}
static ALWAYS_INLINE void ap_call_nb_noret_3(int hls_id, int arg0, int arg1, int arg2)
{
    call_itf_ctrl(CHILD, 3, 0);
    hls_func3(arg0, arg1, arg2);
}

//4 arguments HLS function call
static ALWAYS_INLINE int ap_call_4(int hls_id, int arg0, int arg1, int arg2, int arg3)
{
    call_itf_ctrl(CHILD, 4, 1);
    hls_func4(arg0, arg1, arg2, arg3);
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_4(int hls_id, int arg0, int arg1, int arg2, int arg3)
{
    call_itf_ctrl(CHILD, 4, 1);
    hls_func4(arg0, arg1, arg2, arg3);
}
static ALWAYS_INLINE void ap_call_nb_noret_4(int hls_id, int arg0, int arg1, int arg2, int arg3)
{
    call_itf_ctrl(CHILD, 4, 0);
    hls_func4(arg0, arg1, arg2, arg3);
}

//5 arguments HLS function call
static ALWAYS_INLINE int ap_call_5(int hls_id, int arg0, int arg1, int arg2, int arg3,
                            int arg4)
{
    call_itf_ctrl(CHILD, 5, 1);
    hls_func5(arg0, arg1, arg2, arg3, arg4);
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_5(int hls_id, int arg0, int arg1, int arg2, int arg3,
                                    int arg4)
{
    call_itf_ctrl(CHILD, 5, 1);
    hls_func5(arg0, arg1, arg2, arg3, arg4);
}
static ALWAYS_INLINE void ap_call_nb_noret_5(int hls_id, int arg0, int arg1, int arg2, int arg3,
                                    int arg4)
{
    call_itf_ctrl(CHILD, 5, 0);
    hls_func5(arg0, arg1, arg2, arg3, arg4);
}

//6 arguments
static ALWAYS_INLINE int ap_call_6(int hls_id, int arg0, int arg1, int arg2, int arg3,
                            int arg4, int arg5)
{
    call_itf_ctrl(CHILD, 6, 1);
    hls_func6(arg0, arg1, arg2, arg3, arg4, arg5);
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_6(int hls_id, int arg0, int arg1, int arg2, int arg3,
                                    int arg4, int arg5)
{
    call_itf_ctrl(CHILD, 6, 1);
    hls_func6(arg0, arg1, arg2, arg3, arg4, arg5);
}
static ALWAYS_INLINE void ap_call_nb_noret_6(int hls_id, int arg0, int arg1, int arg2, int arg3,
                                    int arg4, int arg5)
{
    call_itf_ctrl(CHILD, 6, 0);
    hls_func6(arg0, arg1, arg2, arg3, arg4, arg5);
}

//7 arguments HLS function call
static ALWAYS_INLINE int ap_call_7(int hls_id, int arg0, int arg1, int arg2, int arg3,
                            int arg4, int arg5, int arg6)
{
    call_itf_ctrl(CHILD, 7, 1);
    hls_func7(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_7(int hls_id, int arg0, int arg1, int arg2, int arg3,
                                    int arg4, int arg5, int arg6)
{
    call_itf_ctrl(CHILD, 7, 1);
    hls_func7(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
}
static ALWAYS_INLINE void ap_call_nb_noret_7(int hls_id, int arg0, int arg1, int arg2, int arg3,
                                    int arg4, int arg5, int arg6)
{
    call_itf_ctrl(CHILD, 7, 0);
    hls_func7(arg0, arg1, arg2, arg3, arg4, arg5, arg6);
}

//8 arguments HLS function call
static ALWAYS_INLINE int ap_call_8(int hls_id, int arg0, int arg1, int arg2, int arg3,
                            int arg4, int arg5, int arg6, int arg7)
{
    call_itf_ctrl(CHILD, 8, 1);
    hls_func8(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
    return call_itf_return(CHILD);
}
static ALWAYS_INLINE void ap_call_nb_8(int hls_id, int arg0, int arg1, int arg2, int arg3,
                                    int arg4, int arg5, int arg6, int arg7)
{
    call_itf_ctrl(CHILD, 8, 1);
    hls_func8(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
}
static ALWAYS_INLINE void ap_call_nb_noret_8(int hls_id, int arg0, int arg1, int arg2, int arg3,
                                    int arg4, int arg5, int arg6, int arg7)
{
    call_itf_ctrl(CHILD, 8, 0);
    hls_func8(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
}

static ALWAYS_INLINE void * get_riscv_xmem_base(void)
{
	return (void*)(XCACHE_ACCESS_BASE);
}

extern int xmem_partition[32];

//edward 2024-09-25: Set HLS xmem2 partition
static ALWAYS_INLINE void set_hls_xmem_partition(int value)
{    
    asm volatile ("csrw %0, %1" : :"i"(CSR_CALL_PART),"r"(value));
    xmem_partition[mhartid()] = value;
}
//edward 2024-09-25: Xmem2 base with partition
static ALWAYS_INLINE void * get_riscv_xmem_partition_base(int partition)
{
	return (void*)(XCACHE_ACCESS_BASE);
}
//edward 2025-02-06: Get current xmem2 partition
static ALWAYS_INLINE int get_riscv_xmem_partition(void)
{
	return xmem_partition[mhartid()];
}
//edward 2024-09-25: top & left pixel buffer (in XMEM1) is accessed with new command
static ALWAYS_INLINE void * get_riscv_xmem1_topPix_base(int part, int cidx, int x0, int shift)
{
    //return (void*)(LONGTAIL_IO + (XMEM1_ACCESS << 20) + (0 << 18) + (part * 2048 * 3) + (cidx * 2048) + (x0 >> shift));
    return (void*)(LONGTAIL_IO + (XMEM1_ACCESS << 20) + (0 << 18) + (part << 15) + (cidx * 2048) + (x0 >> shift));
}
static ALWAYS_INLINE void * get_riscv_xmem1_leftPix_base(int part, int cidx, int y0, int shift)
{
    //return (void*)(LONGTAIL_IO + (XMEM1_ACCESS << 20) + (1 << 18) + (part * 64 * 6) + (cidx * 64) + ((y0 & 63) >> shift));
    return (void*)(LONGTAIL_IO + (XMEM1_ACCESS << 20) + (1 << 18) + (part << 15) + (cidx * 64) + ((y0 & 63) >> shift));
}
static ALWAYS_INLINE void * get_riscv_xmem1_topleftPix_base(int part, int cidx, int y0, int shift)
{
    //return (void*)(LONGTAIL_IO + (XMEM1_ACCESS << 20) + (1 << 18) + (part * 64 * 6) + (cidx * 64) + ((y0 & 63) >> shift) + (64 * 3) + 3);
    return (void*)(LONGTAIL_IO + (XMEM1_ACCESS << 20) + (1 << 18) + (part << 15) + (cidx * 64) + ((y0 & 63) >> shift) + (64 * 3) + 3);
}
//edward 2025-02-13: append base to pointer to allow riscv to access HLS local cache
static ALWAYS_INLINE void * get_riscv_hls_cache_addr(void *ptr)
{
    intptr_t adr = (int)ptr;
    if (adr > 0xfffffff) {
        printf("HLS local cache address cannot be larger than 28-bits\n");
        return NULL;
    }
    else {
        return (void*)(HLS_LCACHE_ACCESS_BASE | adr);
    }
}

#if __cplusplus
    }
#endif


//---------------------------------------------------------
//Get cabac function for longtail HLS without dataflow HLS
//---------------------------------------------------------
#if (!HLS_CMDR && HLS_XMEM)
//#include "hls_axi4_dma.h"
#include "hls_dataflow.h"

#endif

#endif // end of __riscv

#endif