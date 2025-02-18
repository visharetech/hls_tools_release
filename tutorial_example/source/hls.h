#ifndef _HLS_H_
#define _HLS_H_


#if __VITIS_HLS__
    #include <ap_int.h>
#endif

#include <stdint.h>
#include <stddef.h>
#include "hls_config.h"
#include "xmem.h"
#include "common_with_hls.h"


#ifdef __cplusplus
extern "C" {
#endif

void HLS_DECLARE(xor_diff_type)(HLS_COMMON_ARG uint32_t *xor_val32, uint16_t xor_val16, uint8_t xor_val8);
void HLS_DECLARE(assign_array_complete)(HLS_COMMON_ARG int arr_complete[5], int base);
void HLS_DECLARE(array_xor)(HLS_COMMON_ARG int arr_d1[10], int arr_s1[10], int arr_s2[10], int count);
void HLS_DECLARE(vector_add)(HLS_COMMON_ARG vector_2d *vec_d1, const vector_2d *vec_s1, const vector_2d *vec_s2);
void HLS_DECLARE(fill_value)(HLS_COMMON_ARG int value, int fillsize, int big_array[10000]);
void HLS_DECLARE(hevc_loop_filter_chroma_8bit_hls)(HLS_COMMON_ARG uint8_t pix[1920*1080], int frame_offset, int xstride, int ystride, int tc_arr[2], uint8_t no_p_arr[2], uint8_t no_q_arr[2]);
void HLS_DECLARE(cnn_hls)(HLS_COMMON_ARG int width, int height, int filter, char pixel[(MAX_WIDTH_SIZE + MAX_FILTER_SIZE -1 ) * (MAX_HEIGHT_SIZE + MAX_FILTER_SIZE - 1)], char filter_map[MAX_FILTER_SIZE * MAX_FILTER_SIZE], int sum[MAX_WIDTH_SIZE * MAX_HEIGHT_SIZE]);

#ifdef __cplusplus
}
#endif

#if __riscv
    #include "hls_apcall.h"
#endif


#endif
