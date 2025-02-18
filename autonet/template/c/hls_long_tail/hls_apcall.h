#ifndef _${header}_H_
#define _${header}_H_

//#include <stdio.h>
//#include <iostream>
//#include <stdlib.h>
#include <stdint.h>
#include "hls_enum.h"
#include "hls.h"

/*
enum long_tail_id
{
${enum_statement}
};
*/

#ifdef __cplusplus
extern "C" {
#endif

#if ASIM_CALL
    #define ASIM_SET_HEVC_CONTEXT() asim_set_hevc_context(HEVCCONTEXT_CALL_NoComma)
#else
    #define ASIM_SET_HEVC_CONTEXT()
#endif

#if __riscv && ASIM_CALL
void asim_hls_handler(void) __attribute__ ((interrupt ("supervisor")));
#endif

#if __riscv

//----- Longtail HLS with get cabac interface ----
#if HLS_GET_CABAC || HLS_CMDR || ASIM_CALL
    #define LONGTAIL_WITH_CABAC     1
#else
    #define LONGTAIL_WITH_CABAC     0
#endif

// Calculate the cycle count within apcall by mcycle32()  
#define APCALL_PROFILE      0

//----- Non-blocking ap call (for riscv fpga only) ----
#define NON_BLOCK_AP_CALL   0
#define HLS_SELECT          ((NON_BLOCK_AP_CALL)? 3 : 1)

//----- Hardware dma for memcpy/memset (for riscv fpga only) ----
//edward 2024-10-22: Since copyEngine is used, there is no MTDMA for riscv core.
#define HLS_MTDMA                   0
//#if _rvTranslate
//    #define HLS_MTDMA             0
//#else
//    #define HLS_MTDMA             1  
//#endif

//----- Select HLS run by hardware -----
#if _rvTranslate || HLS_XMEM
${define_statement}
#endif

#define ENUM_FUNC_NUM       HLS_NUM
#define ENUM_FUNC_NUM_ALIGN (((HLS_NUM + 31) / 32) * 32) //aligned with 32-bytes
#define HLS_THREAD          8
#define NEW_HLS_PROF_CNT    1   //edward 2024-10-09: new cycle profiling with function arbiter and xmem2
#define HW_HLS_ACC_CNT      1   //edward 2025-01-06: hardware accumulate profiling counter

#if APCALL_PROFILE
    typedef struct {
        uint32_t count;
        uint32_t acc_cycle;
        uint32_t min;
        uint32_t max;
        //edward 2024-10-09: new cycle profiling with function arbiter and xmem2
        #if NEW_HLS_PROF_CNT
        uint32_t acc_dc_busy;
        uint32_t acc_xmem_busy;
        uint32_t acc_farb_busy;
        uint32_t acc_cyc_no_busy;
        uint32_t min_no_busy;
        uint32_t max_no_busy;
        #endif
    }apcall_profile_t;

    extern apcall_profile_t apcall_profile[HLS_THREAD][ENUM_FUNC_NUM_ALIGN];
    extern const char *hls_func_name[];

  //edward 2025-01-06: hardware accumulate profiling counter
  #if HW_HLS_ACC_CNT

    #define APCALL_PROFILE_START()
    #define APCALL_PROFILE_STOP(FUNC_ID)

  //edward 2024-10-09: new cycle profiling with function arbiter and xmem2
  #elif NEW_HLS_PROF_CNT

    #define APCALL_PROFILE_START()          
    #define APCALL_PROFILE_STOP(FUNC_ID)                                                                   \
                                        do {                                                               \
                                            uint32_t thd       = mhartid();                                \
                                            uint32_t cyc       = longtail_total_cycle(FUNC_ID);                   \
                                            uint32_t dc_busy   = longtail_dc_busy(FUNC_ID);                       \
                                            uint32_t xmem_busy = longtail_xmem_busy(FUNC_ID);                     \
                                            uint32_t farb_busy = longtail_farb_busy(FUNC_ID);                     \
                                            longtail_clear_profile(FUNC_ID);                               \
                                            uint32_t cyc_no_busy = cyc - dc_busy - xmem_busy - farb_busy;  \
                                            if (cyc > apcall_profile[thd][FUNC_ID].max)                    \
                                                apcall_profile[thd][FUNC_ID].max = cyc;                    \
                                            if (cyc < apcall_profile[thd][FUNC_ID].min)                    \
                                                apcall_profile[thd][FUNC_ID].min = cyc;                    \
                                            apcall_profile[thd][FUNC_ID].acc_cycle += cyc;                 \
                                            apcall_profile[thd][FUNC_ID].acc_dc_busy += dc_busy;           \
                                            apcall_profile[thd][FUNC_ID].acc_xmem_busy += xmem_busy;       \
                                            apcall_profile[thd][FUNC_ID].acc_farb_busy += farb_busy;       \
                                            apcall_profile[thd][FUNC_ID].acc_cyc_no_busy += cyc_no_busy;   \
                                            if (cyc_no_busy > apcall_profile[thd][FUNC_ID].max_no_busy)    \
                                                apcall_profile[thd][FUNC_ID].max_no_busy = cyc_no_busy;    \
                                            if (cyc_no_busy < apcall_profile[thd][FUNC_ID].min_no_busy)    \
                                                apcall_profile[thd][FUNC_ID].min_no_busy = cyc_no_busy;    \
                                            ++apcall_profile[thd][FUNC_ID].count;                          \
                                        } while (0)

  #else

    #define APCALL_PROFILE_START()          uint32_t cyc = mcycle32();
    #define APCALL_PROFILE_STOP(FUNC_ID)    uint32_t now = mcycle32();                          \
                                            uint32_t thd = mhartid();                           \
                                            uint32_t diff;                                      \
                                            if(now>cyc) {                                       \
                                                diff = now - cyc;                               \
                                            } else {                                            \
                                                diff = cyc - now;                               \
                                                printf("*** cycle overflow ***\n");             \
                                            }                                                   \
                                            if (diff > 100) {                                   \
                                                printf("*** apcall cycle > 100: %s %u ***\n", hls_func_name[FUNC_ID], diff);   \
                                            }                                                   \
                                            if (diff > apcall_profile[thd][FUNC_ID].max)        \
                                                apcall_profile[thd][FUNC_ID].max = diff;        \
                                            if (diff < apcall_profile[thd][FUNC_ID].min)        \
                                                apcall_profile[thd][FUNC_ID].min = diff;        \
                                            apcall_profile[thd][FUNC_ID].acc_cycle += diff;     \
                                            ++apcall_profile[thd][FUNC_ID].count;

  #endif
#else
    #define APCALL_PROFILE_START()
    #define APCALL_PROFILE_STOP(FUNC_ID)
#endif

void apcall_profile_init(void);
void apcall_profile_done(int thd);
void apcall_profile_report(void);

#if DEBUG
    static void TRACE() {}

    template<typename T, typename ... Types>
    static void TRACE (T firstArg, Types ... args) {
        std::cout << firstArg << ' ';

        TRACE(args...);
    }
#else
    #define TRACE(...)
#endif

#ifndef ARRAY_SIZE
    #define ARRAY_SIZE(arr) (sizeof(arr)/sizeof((arr)[0])
#endif

#if 0
// memcpy may encounter error in xmem because the element may only support dedicated data width 
// use xmem_copy to clone the element to ensure the data width is exactly matched.
template <typename T>
void inline xmem_copy(T *dest, const T *src, size_t num){
    for (size_t i=0; i<num; i++) {
        dest[i] = src[i];
    }
}
#endif

// not use inline function for profilnig
#if APCALL_PROFILE
#define inline __attribute__((noinline))
#endif

${func_content}
#if APCALL_PROFILE
#undef inline
#endif

#endif

#ifdef __cplusplus
}
#endif

#endif
