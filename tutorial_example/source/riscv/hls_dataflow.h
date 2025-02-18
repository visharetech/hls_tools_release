#ifndef HLS_DATAFLOW_H
#define HLS_DATAFLOW_H

#if __riscv


//Machine hart ID (Cabac ID = CORE ID - 1)
static inline uint32_t hls_mhartid(void)
{
  uint32_t id;
  asm volatile ("csrr %0, mhartid" :"=r"(id));
  return id;
}

#define CORE_ID   hls_mhartid()

#ifdef __cplusplus
extern "C" {
#endif

//Dummy HSL functon for RISCV function call interface.
void hls_func0(void);
void hls_func1(uint32_t a0);
void hls_func2(uint32_t a0, uint32_t a1);
void hls_func3(uint32_t a0, uint32_t a1, uint32_t a2);
void hls_func4(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3);
void hls_func5(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4);
void hls_func6(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5);
void hls_func7(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5, uint32_t a6);
void hls_func8(uint32_t a0, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5, uint32_t a6, uint32_t a7);

#ifdef __cplusplus
}
#endif

#endif //#if __riscv

#endif