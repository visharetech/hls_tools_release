#ifndef _XMEM_H_
#define _XMEM_H_

#include <stdint.h>
#include "common_with_hls.h"
#if __riscv
    #include "riscv/hls_long_tail.h"
#endif

#define MAX_WIDTH_SIZE		64
#define MAX_HEIGHT_SIZE		64
#define MAX_FILTER_SIZE		8



typedef struct {
    int x   _ALIGN;
    int y   _ALIGN;
}vector_2d;



typedef struct xmem_t{
    uint8_t xor_val8                                   _ALIGN; //scalar offs:0 size:4
    uint16_t xor_val16                                 _ALIGN; //scalar offs:4 size:4
    uint32_t xor_val32                                 _ALIGN; //scalar offs:8 size:4
    int arr_complete[5]                                _ALIGN; //scalar offs:12 size:20
    vector_2d vec_s1                                   _ALIGN; //scalar offs:32 size:8
    vector_2d vec_s2                                   _ALIGN; //scalar offs:40 size:8
    vector_2d vec_d1                                   _ALIGN; //scalar offs:48 size:8
    int tc_arr[2]                                      _ALIGN; //scalar offs:56 size:8
    uint8_t no_p_arr[2]                                _ALIGN; //scalar offs:64 size:4
    uint8_t no_q_arr[2]                                _ALIGN; //scalar offs:68 size:4

uint8_t xxxxx_paddingA[1976];

    char filter_map[MAX_FILTER_SIZE * MAX_FILTER_SIZE] _ALIGN; //array offs:2048 size:64
    char pixel[(MAX_WIDTH_SIZE + MAX_FILTER_SIZE -1 ) * (MAX_HEIGHT_SIZE + MAX_FILTER_SIZE - 1)] _ALIGN; //array offs:2112 size:5044
    int sum [MAX_WIDTH_SIZE * MAX_HEIGHT_SIZE]         _ALIGN; //array offs:7156 size:16384
    int arr_s1[10]                                     _ALIGN; //array offs:23540 size:40
    int arr_s2[10]                                     _ALIGN; //array offs:23580 size:40
    int arr_d1[10]                                     _ALIGN; //array offs:23620 size:40
    int big_array[10000]                               _ALIGN; //array offs:23660 size:40000
    uint8_t pix_base[1920*1080]                        _ALIGN; //array offs:63660 size:2073600

// Total scalar size: 72
// Total array size: 2135212
// Total cyclic size: 0

}xmem_t;

#ifdef __cplusplus
extern "C" {
#endif

//void xmem_read_dbg_section(void);
void xmem_rw_test(void);

#ifdef __cplusplus
}
#endif



#ifndef ARRAY_SIZE
    #define ARRAY_SIZE(arr) (sizeof(arr)/sizeof((arr)[0]))
#endif

// Use volatile in xmem here to prevent mismatch load / store instruction being used for memory copy
// e.g. Prevent uint8_t lumaCache[] copy by lw / sw instruction
#ifdef __cplusplus

template <typename T>
static void inline xmem_assign(T *dst, T value)
{
	volatile T *dst_ptr = static_cast<volatile T *>(dst);
	*dst_ptr = value;
}

template <typename T>
static void inline xmem_copy(T *dst, const T *src, size_t num)
{
	for (size_t i = 0; i < num; i++)
	{
		volatile T *dst_ptr = static_cast<volatile T *>(dst);
		dst_ptr[i] = src[i];
	}
}

template <typename T>
static void inline xmem_set(T *dst, T value, size_t num)
{
	for (size_t i = 0; i < num; i++)
	{
		volatile T *dst_ptr = static_cast<volatile T *>(dst);
		dst_ptr[i] = value;
	}
}

#endif

// C version of function template xmem_assign
#define XMEM_ASSIGN(TYPE, DST, VALUE)                    \
	do                                                   \
	{                                                    \
		volatile TYPE *dst_ptr = (volatile TYPE *)(DST); \
		*dst_ptr = VALUE;                                \
	} while (0);

// C version of function template xmem_copy
#define XMEM_COPY(TYPE, DST, SRC, COUNT)                     \
	do                                                       \
	{                                                        \
		volatile TYPE *dst_ptr = (volatile TYPE *)(DST); 	 \
		volatile TYPE *src_ptr = (volatile TYPE *)(SRC); 	 \
		for (size_t i = 0; i < COUNT; i++)                   \
		{                                                    \
			dst_ptr[i] = src_ptr[i];                         \
		}                                                    \
	} while (0);

// C version of function template xmem_set
#define XMEM_SET(TYPE, DST, VAL, COUNT)                      \
	do                                                       \
	{                                                        \
		volatile TYPE *dst_ptr = (volatile TYPE *)(DST); 	 \
		for (size_t i = 0; i < COUNT; i++)                   \
		{                                                    \
			dst_ptr[i] = VAL;                                \
		}                                                    \
	} while (0);

#endif
