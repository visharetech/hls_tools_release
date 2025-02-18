#ifndef RISCV_SYS_H
#define RISCV_SYS_H

#include "syscall.h"
#include "../riscv/io_map.h"

//Hardware version
enum
{
    VER_MAJOR,
    VER_MINOR,
    VER_PATCH,
    VER_YY,
    VER_MM,
    VER_DD,
    VER_ICACHE_WAY_NUM,
    VER_ICACHE_SET_NUM,
    VER_DCACHE_WAY_NUM,
    VER_DCACHE_SET_NUM,
    VER_ENABLE_HLS,
    VER_ENABLE_MTDMA,
    VER_ENABLE_MICRO_THREAD,
    VER_CORE_NUM,
    VER_ENABLE_PROFILE,
    VER_RISCV_FREQUENCY,
    VER_ENABLE_DATAFLOW,
    VER_ENABLE_ENCODER,
    VER_ENABLE_DECODER,
    VER_DATAFLOW_CABAC_NUM,
    VER_DATAFLOW_OUTPIX_NUM,
    VER_ENABLE_L2CACHE,
    VER_L2CACHE_SIZE,
    VER_L2CACHE_WAY,
    VER_L2CACHE_LEN,
    VER_ENALBE_HLS_LOCAL_CACHE,
    VER_HLS_LOCAL_CACHE_WAY,
    VER_HLS_LOCAL_CACHE_SET,
    VER_ENALBE_HLS_RISCV_L1CACHE,
    VER_ENABLE_HLS_PROFILE
};
static inline uint32_t get_riscv_hw_ver(int id)
{
    volatile int * hw_ver = (int*)(HW_VERSION);
    return hw_ver[id];
}

#ifdef __cplusplus
extern  "C" {
#endif

void riscv_init();
void riscv_exit();
void riscv_writeback_dcache_all();
void riscv_writeback_dcache(uint8_t *adr);
void riscv_writeback_dcache_lines(const uint8_t *buf, int len);

#if NETFILE
void nf_argv_open(const char * filepath);
void nf_argv_close();
bool nf_argv_load(int *argc_ptr, char ***argv_ptr);
#endif

#if FUNCLOG
void funclog_profile_init();
void funclog_profile_report();
void funclog_profile_start();
void funclog_profile_stop();
#endif

#if LOG_MEMCPY_MEMSET
void memcpy_memset_log_clear(void);
void memcpy_memset_log_print(void);
#endif

#ifdef  __cplusplus
}
#endif

#endif