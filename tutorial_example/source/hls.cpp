#include "hls.h"
#include "xmem.h"
#include "hls_config.h"
#include "cnn.h"

#ifdef __cplusplus
extern "C" {
#endif

//Below function demonstrate different data type are supported
void IMPL(xor_diff_type)(HLS_COMMON_ARG uint32_t *xor_val32, uint16_t xor_val16, uint8_t xor_val8){
    *xor_val32 = xor_val16 ^ xor_val8;
}

// Below function demonstrate it can identify complete partition
void IMPL(assign_array_complete)(HLS_COMMON_ARG int arr_complete[5], int base){
#pragma HLS array_partition variable=arr_complete type=complete
    for (int i=0; i<5; i++){
#pragma HLS PIPELINE OFF
        arr_complete[i] = base + i;
    }
}

//Below function demonstrate it can support array in xmem
// but the count is not declared in xmem, it will be passed by APCALL argument
void IMPL(array_xor)(HLS_COMMON_ARG int arr_d1[10], int arr_s1[10], int arr_s2[10], int count){
#pragma HLS interface mode=bram port=arr_d1 storage_type=RAM_1P latency=3
#pragma HLS interface mode=bram port=arr_s1 storage_type=RAM_1P latency=3
#pragma HLS interface mode=bram port=arr_s2 storage_type=RAM_1P latency=3

    constexpr size_t MAX_ARR_SIZE = 10;

    for (int i=0; i<MAX_ARR_SIZE && i < count; i++){
        arr_d1[i] = arr_s1[i] ^ arr_s2[i];
    }
}

//Below function demonstrate it can support struct in xmem
void IMPL(vector_add)(HLS_COMMON_ARG vector_2d *vec_d1, const vector_2d *vec_s1, const vector_2d *vec_s2){
#pragma HLS disaggregate variable=vec_s1
#pragma HLS disaggregate variable=vec_s2
#pragma HLS disaggregate variable=vec_d1

    vec_d1->x = vec_s1->x + vec_s2->x;
    vec_d1->y = vec_s1->y + vec_s2->y;
}

//Below function demonstrate it can support access from bigarray
void IMPL(fill_value)(HLS_COMMON_ARG int value, int fillsize, int big_array[10000]){
#pragma HLS interface mode=bram port=big_array storage_type=RAM_1P latency=3

    for (int i = 0; i < fillsize; ++i) {
#pragma HLS PIPELINE OFF
        big_array[i] = value;
    }
}

#define P3 pix[-4 * xstride]
#define P2 pix[-3 * xstride]
#define P1 pix[-2 * xstride]
#define P0 pix[-1 * xstride]
#define Q0 pix[0 * xstride]
#define Q1 pix[1 * xstride]
#define Q2 pix[2 * xstride]
#define Q3 pix[3 * xstride]


//TODO: Below function demonstrate it can support large array
void IMPL(hevc_loop_filter_chroma_8bit_hls)(HLS_COMMON_ARG uint8_t pix_base[1920*1080], int frame_offset, int xstride,
    int ystride, int tc_arr[2],
    uint8_t no_p_arr[2], uint8_t no_q_arr[2])
{
#pragma HLS interface mode=bram port=pix_base storage_type=RAM_1P latency=3
#pragma HLS ARRAY_PARTITION variable=tc_arr type=complete
#pragma HLS ARRAY_PARTITION variable=no_p_arr type=complete
#pragma HLS ARRAY_PARTITION variable=no_q_arr type=complete

    int d, j;
    bool no_p, no_q;
    pix_base += frame_offset;

    uint8_t *pix        = (uint8_t *)pix_base;

    for (j = 0; j < 2; j++) {
        
#pragma HLS UNROLL OFF = TRUE
        const int16_t tc = tc_arr[j];
        if (tc <= 0) {
            pix += 4 * ystride;
            continue;
        }
        no_p = no_p_arr[j];
        no_q = no_q_arr[j];

        for (d = 0; d < 4; d++) {
#pragma HLS PIPELINE
            const int16_t p1 = P1;
            const int16_t p0 = P0;
            const int16_t q0 = Q0;
            const int16_t q1 = Q1;

            //delta0 = av_clip((((q0 - p0) * 4) + p1 - q1 + 4) >> 3, -tc, tc);
            int16_t temp = (((q0 - p0) << 2) + p1 - q1 + 4) >> 3;
            int16_t delta = (temp < -tc ? -tc : (temp > tc ? tc : temp));
            if (!no_p){
                P0 = (p0 + delta < 0 ? 0 : ((p0 + delta > 255) ? 255 : p0 + delta));
            }
            if (!no_q) {
                Q0 = (q0 - delta < 0 ? 0 : ((q0 - delta > 255) ? 255 : q0 - delta));
            }
            pix += ystride;
        }
    }
}

#undef P3
#undef P2
#undef P1
#undef P0
#undef Q0
#undef Q1
#undef Q2
#undef Q3

void IMPL(cnn_hls)(HLS_COMMON_ARG int width, int height, int filter, char pixel[(MAX_WIDTH_SIZE + MAX_FILTER_SIZE -1 ) * (MAX_HEIGHT_SIZE + MAX_FILTER_SIZE - 1)], char filter_map[MAX_FILTER_SIZE * MAX_FILTER_SIZE], int sum[MAX_WIDTH_SIZE * MAX_HEIGHT_SIZE]) {
#pragma HLS interface mode=bram port=pixel storage_type=RAM_1P latency=3
#pragma HLS interface mode=bram port=filter_map storage_type=RAM_1P latency=3
#pragma HLS interface mode=bram port=sum storage_type=RAM_1P latency=3

    /*
    - vdir is set a DOWN
    - for each column c0 of the filter
        - for each row r0 of the filter
            - apply filter[r0][c0] to for each pixel at x,y in the buffer
                - sum[r][c] += pixel[r][c] * filter[r0][c0] for each r,c
            - if r0<F-1, shift in the vdir direction 
            - else shift LEFT by 1 stepDOWN
        - toggle vdir, i.e. vdir = (vdir == ) ? UP : DOWN
    */  
    int i, c0, r0, target;
    bool clear;
    cnnCore core;

    core.config(width, height, filter, pixel, sum);    
    clear = 1; 
    c0 = 0;
    r0 = 0;
    target = filter - 1;	
    for (i = 0; i < filter * filter; i++) {
        //printf("c0 %d r0 %d filter %d\n", c0, r0, r0 * filter + c0);
        core.scalar_matrix_multAdd(clear, filter_map[r0 * filter + c0]);
        clear = 0;
        // shift in target direction if r0 < filter - 1, else shift LEFT by 1 step        		
        if (r0 == target) {
            c0++;
            target = (target == 0) ? (filter - 1) : 0;
            core.shiftLeft();
        } else if (target == 0) {
            core.shiftUp();
            r0--;
        } else {
            core.shiftDown();
            r0++;
        }
    }   
    //core.output(sum);
}


#ifdef __cplusplus
}
#endif

#if CAPTURE_COSIM
	#include "hls_capture.cpp"
#endif
