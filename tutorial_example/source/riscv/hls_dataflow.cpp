#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include "hls_dataflow.h"


#define nop() asm volatile("nop")

#ifdef __cplusplus
extern "C" {
#endif

int xmem_partition[32] = { 0 };

//Dummy HSL functon for RISCV function call interface.
void __attribute__((noinline)) hls_func0(void)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif

}
void __attribute__((noinline)) hls_func1(uint32_t a0)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif
}
void __attribute__((noinline)) hls_func2(uint32_t a0, uint32_t a1)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif
}
void __attribute__((noinline)) hls_func3(uint32_t a0, uint32_t a1, uint32_t a2)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif
}
void __attribute__((noinline)) hls_func4(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif
}
void __attribute__((noinline)) hls_func5(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif
}
void __attribute__((noinline)) hls_func6(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif
}
void __attribute__((noinline)) hls_func7(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5, uint32_t a6)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif
}
void __attribute__((noinline)) hls_func8(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5, uint32_t a6, uint32_t a7)
{
#if _rvTranslate
    asm volatile("ecall");
#else
    asm volatile("nop");
#endif
}


#ifdef __cplusplus
}
#endif