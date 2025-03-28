#if __riscv

#include <stdio.h>
#include <string.h>
#include "hls_apcall.h"

#ifdef __cplusplus 
extern "C" {
#endif 

#if _DEBUG
    #define DEBUG_PRINTF(...)       printf(__VA_ARGS__);
#else
    #define DEBUG_PRINTF(...)
#endif


#if ASIM_CALL

static dcache_info_t dcache_info[MAX_CORE_NUM];

#define ASIM_FUNC_ARBITER_ARG_CALL xmem, &ret_rdy, &ret, &call_child

void /*__attribute__ ((interrupt ("supervisor")))*/ asim_hls_handler(){

    child_cmd_t call_child;
    int ret;
    bool ret_rdy;

    int __return_status__ = 0;

    xmem_t *xmem = (xmem_t*)get_riscv_xmem_base();

    hls_enum_t hls_id = (hls_enum_t)asim_get_apcall_hls_id();
    
    switch(hls_id){
    case enum_xor_diff_type:
    {
        DEBUG_PRINTF("APCALL HLS function: xor_diff_type\n");
        uint32_t * xor_val32 = &xmem->xor_val32; //xmem pointer
        uint16_t xor_val16 = xmem->xor_val16;  //xmem input
        uint8_t xor_val8 = xmem->xor_val8;  //xmem input
        IMPL(xor_diff_type)(HLS_COMMON_ARG_CALL  xor_val32, xor_val16, xor_val8);
        break;
    }
    case enum_assign_array_complete:
    {
        DEBUG_PRINTF("APCALL HLS function: assign_array_complete\n");
        int *arr_complete = xmem->arr_complete;  //xmem array
        int base = (int)asim_get_apcall_arg0();
        IMPL(assign_array_complete)(HLS_COMMON_ARG_CALL  arr_complete, base);
        break;
    }
    case enum_array_xor:
    {
        DEBUG_PRINTF("APCALL HLS function: array_xor\n");
        int *arr_d1 = xmem->arr_d1;  //xmem array
        int *arr_s1 = xmem->arr_s1;  //xmem array
        int *arr_s2 = xmem->arr_s2;  //xmem array
        int count = (int)asim_get_apcall_arg0();
        IMPL(array_xor)(HLS_COMMON_ARG_CALL  arr_d1, arr_s1, arr_s2, count);
        break;
    }
    case enum_vector_add:
    {
        DEBUG_PRINTF("APCALL HLS function: vector_add\n");
        vector_2d * vec_d1 = &xmem->vec_d1; //xmem pointer
        const vector_2d * vec_s1 = &xmem->vec_s1; //xmem pointer
        const vector_2d * vec_s2 = &xmem->vec_s2; //xmem pointer
        IMPL(vector_add)(HLS_COMMON_ARG_CALL  vec_d1, vec_s1, vec_s2);
        break;
    }
    case enum_fill_value:
    {
        DEBUG_PRINTF("APCALL HLS function: fill_value\n");
        int value = (int)asim_get_apcall_arg0();
        int fillsize = (int)asim_get_apcall_arg1();
        int *big_array = xmem->big_array;  //xmem array
        IMPL(fill_value)(HLS_COMMON_ARG_CALL  value, fillsize, big_array);
        break;
    }
    case enum_hevc_loop_filter_chroma_8bit_hls:
    {
        DEBUG_PRINTF("APCALL HLS function: hevc_loop_filter_chroma_8bit_hls\n");
        uint8_t *pix_base = xmem->pix_base;  //xmem array
        int frame_offset = (int)asim_get_apcall_arg0();
        int xstride = (int)asim_get_apcall_arg1();
        int ystride = (int)asim_get_apcall_arg2();
        int *tc_arr = xmem->tc_arr;  //xmem array
        uint8_t *no_p_arr = xmem->no_p_arr;  //xmem array
        uint8_t *no_q_arr = xmem->no_q_arr;  //xmem array
        IMPL(hevc_loop_filter_chroma_8bit_hls)(HLS_COMMON_ARG_CALL  pix_base, frame_offset, xstride, ystride, tc_arr, no_p_arr, no_q_arr);
        break;
    }
    case enum_cnn_hls:
    {
        DEBUG_PRINTF("APCALL HLS function: cnn_hls\n");
        int width = (int)asim_get_apcall_arg0();
        int height = (int)asim_get_apcall_arg1();
        int filter = (int)asim_get_apcall_arg2();
        char *pixel = xmem->pixel;  //xmem array
        char *filter_map = xmem->filter_map;  //xmem array
        int *sum = xmem->sum;  //xmem array
        IMPL(cnn_hls)(HLS_COMMON_ARG_CALL  width, height, filter, pixel, filter_map, sum);
        break;
    }

        default:
            printf("Undefined HLS func ID %d\n", hls_id);
    }

    asim_set_apreturn(__return_status__);
}

#endif

#if APCALL_PROFILE

apcall_profile_t apcall_profile[HLS_THREAD][ENUM_FUNC_NUM_ALIGN];

const char *hls_func_name[] = { "xor_diff_type",
    "assign_array_complete",
    "array_xor",
    "vector_add",
    "fill_value",
    "hevc_loop_filter_chroma_8bit_hls",
    "cnn_hls" };

void apcall_profile_init(){
    memset(apcall_profile, 0, sizeof(apcall_profile));
    for (int i=0; i<ENUM_FUNC_NUM; i++){
        for (int j=0; j<HLS_THREAD; j++){
            apcall_profile[j][i].min = 1000000;
//edward 2024-10-09: new cycle profiling with function arbiter and xmem2
#if NEW_HLS_PROF_CNT
            apcall_profile[j][i].min_no_busy = 1000000;
#endif
        }
    }
}

//edward 2025-01-06: hardware accumulate profiling counter
void hw_apcall_profile_done(int thd){
#if HW_HLS_ACC_CNT
    for(int i=0; i<ENUM_FUNC_NUM; i++){
        apcall_profile[thd][i].count = longtail_call_count(i);
        apcall_profile[thd][i].acc_cycle = longtail_total_cycle(i);
        apcall_profile[thd][i].acc_dc_busy = longtail_dc_busy(i);
        apcall_profile[thd][i].acc_xmem_busy = longtail_xmem_busy(i);
        apcall_profile[thd][i].acc_farb_busy = longtail_farb_busy(i);
    }
#endif
}

void apcall_profile_report(){
    printf("write apcall profile\n");
    FILE *f = fopen("apcall_profile.csv", "w");
    if (!f) {
        printf("cannot open apcall_profile.csv\n");
        return;
    }
//edward 2025-01-06: hardware accumulate profiling counter
#if HW_HLS_ACC_CNT
    fprintf(f, "hls_func_name,count,acc_cycle,acc_dc,acc_xmem,acc_farb\n");
//edward 2024-10-09: new cycle profiling with function arbiter and xmem2
#elif NEW_HLS_PROF_CNT
    fprintf(f, "hls_func_name,count,acc_cycle,acc_dc,acc_xmem,acc_farb,min,max,avg,acc_cycle_no_busy,min_no_busy,max_no_busy,avg_no_busy\n");
#else
    fprintf(f, "hls_func_name,count,acc_cycle,min,max,avg\n");
#endif
    for(int i=0; i<ENUM_FUNC_NUM; i++){
        uint32_t count = 0;
        uint32_t acc_cycle = 0;
        uint32_t acc_dc = 0;
        uint32_t acc_xmem = 0;
        uint32_t acc_farb = 0;
        uint32_t min = 1000000;
        uint32_t max = 0;
        uint32_t avg = 0;
        uint32_t acc_cycle_no_busy = 0;
        uint32_t min_no_busy = 1000000;
        uint32_t max_no_busy = 0;
        uint32_t avg_no_busy = 0;
        
        for (int j=0; j<HLS_THREAD; j++){
            count += apcall_profile[j][i].count;
            acc_cycle += apcall_profile[j][i].acc_cycle;
            if (apcall_profile[j][i].max > max)
                max = apcall_profile[j][i].max;
            if (apcall_profile[j][i].min < min)
                min = apcall_profile[j][i].min;
//edward 2024-10-09: new cycle profiling with function arbiter and xmem2
#if NEW_HLS_PROF_CNT
            acc_dc += apcall_profile[j][i].acc_dc_busy;
            acc_xmem += apcall_profile[j][i].acc_xmem_busy;
            acc_farb += apcall_profile[j][i].acc_farb_busy;
            acc_cycle_no_busy += apcall_profile[j][i].acc_cyc_no_busy;
            if (apcall_profile[j][i].max_no_busy > max_no_busy)
                max_no_busy = apcall_profile[j][i].max_no_busy;
            if (apcall_profile[j][i].min_no_busy < min_no_busy)
                min_no_busy = apcall_profile[j][i].min_no_busy;
#endif
        }
        if (count != 0) {
            avg = acc_cycle / count;
            avg_no_busy = acc_cycle_no_busy / count;
        }
        else {
            min = 0;
            min_no_busy = 0;
        }
//edward 2025-01-06: hardware accumulate profiling counter
#if HW_HLS_ACC_CNT
        fprintf(f, "\"%s\", %u, %u, %u, %u, %u\n", hls_func_name[i], count, acc_cycle, acc_dc, acc_xmem, acc_farb);
//edward 2024-10-09: new cycle profiling with function arbiter and xmem2
#elif NEW_HLS_PROF_CNT
        fprintf(f, "\"%s\", %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u, %u\n", hls_func_name[i], count, acc_cycle, acc_dc, acc_xmem, acc_farb, min, max, avg, acc_cycle_no_busy, min_no_busy, max_no_busy, avg_no_busy);
#else
        fprintf(f, "\"%s\", %u, %u, %u, %u, %u\n", hls_func_name[i], count, acc_cycle, min, max, avg);
#endif
    }
    fclose(f);
}


#else

void apcall_profile_init(){
}

void hw_apcall_profile_done(int thd){
}

void apcall_profile_report(){
}

#endif

#ifdef __cplusplus 
}
#endif

#endif //__riscv
