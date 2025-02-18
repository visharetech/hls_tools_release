#include <memory>
#include "hls_config.h"
#include "hls.h"
#include "tgload.h"
#if __VITIS_HLS__
    #include <ap_int.h>
#endif

#ifndef TBCONFIG_ALL
    #define TBCONFIG_ALL                             0
#endif

#ifndef TBCONFIG_CNN_HLS
    #define TBCONFIG_CNN_HLS                         0
#endif



template<typename TSRC, typename TDST>
void array_to_ap_uint(TSRC *src, size_t src_count, TDST &dst){
    size_t idx = 0;
    for(size_t i=0; i<src_count; i++){
        for (size_t j=0; j<32; j++) {
            if (idx < dst.length()) {
                uint8_t value = (src[i] >> j) & 1;
                dst[idx] = value;
                ++idx;
            }
        }
    }
}

template<typename TSRC, typename TDST>
void ap_uint_to_array(TSRC &src, TDST *dst, size_t dst_count){
    size_t idx = 0;
    for(size_t i=0; i<dst_count; i++){
        dst[i] = 0;
        for (size_t j=0; j<32; j++) {
            if (idx < src.length()) {
                uint8_t value = src[idx];
                if (value) {
                    dst[i] |= (1 << j);
                }
                ++idx;
            }
        }
    }
}

#if (DCACHE_SIZE >= 0x1FFFFFFF)
    #error "DCACHE_SIZE is too large for cosimulation, please minimize the DACHE_SIZE for cosimulation and revert back the DCACHE_SIZE to 0x1FFFFFFF after cosim"
#endif

bool test_xor_diff_type(){
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
    printf("Test xor_diff_type\n");
    // define input variables 
    uint16_t xor_val16;
    uint8_t xor_val8;

    // define arrays

    // define temp variables
    uint32_t xor_val32;


    HLS_COMMON_INIT_VAR();

    // start loading 
    tgLoad("xor_diff_type_output.bin")
    
    unsigned int total_count = 0;
    bool finish = false;
    do{
        tgPop(xor_val32,xor_val16,xor_val8);

        if (finish) {
            break;
        }
        // call the function
        xor_diff_type(HLS_COMMON_ARG_CALL &xor_val32,xor_val16,xor_val8);

        tgCheck(xor_val32);
        ++total_count;
    } while(true);

    printf("Passed after %d\n", total_count);
    return true;
#else
    printf("Skip xor_diff_type\n");
    return true;
#endif
}

bool test_assign_array_complete(){
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
    printf("Test assign_array_complete\n");
    // define input variables 
    int base;

    // define arrays
    int arr_complete [5];

    // define temp variables


    HLS_COMMON_INIT_VAR();

    // start loading 
    tgLoad("assign_array_complete_output.bin")
    
    unsigned int total_count = 0;
    bool finish = false;
    do{
        tgPop(arr_complete,base);

        if (finish) {
            break;
        }
        // call the function
        assign_array_complete(HLS_COMMON_ARG_CALL arr_complete,base);

        tgCheck(arr_complete);
        ++total_count;
    } while(true);

    printf("Passed after %d\n", total_count);
    return true;
#else
    printf("Skip assign_array_complete\n");
    return true;
#endif
}

bool test_array_xor(){
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
    printf("Test array_xor\n");
    // define input variables 
    int count;

    // define arrays
    int arr_d1 [10];
    int arr_s1 [10];
    int arr_s2 [10];

    // define temp variables


    HLS_COMMON_INIT_VAR();

    // start loading 
    tgLoad("array_xor_output.bin")
    
    unsigned int total_count = 0;
    bool finish = false;
    do{
        tgPop(arr_d1,arr_s1,arr_s2,count);

        if (finish) {
            break;
        }
        // call the function
        array_xor(HLS_COMMON_ARG_CALL arr_d1,arr_s1,arr_s2,count);

        tgCheck(arr_d1,arr_s1,arr_s2);
        ++total_count;
    } while(true);

    printf("Passed after %d\n", total_count);
    return true;
#else
    printf("Skip array_xor\n");
    return true;
#endif
}

bool test_vector_add(){
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
    printf("Test vector_add\n");
    // define input variables 

    // define arrays

    // define temp variables
    vector_2d vec_d1;
    vector_2d vec_s1;
    vector_2d vec_s2;


    HLS_COMMON_INIT_VAR();

    // start loading 
    tgLoad("vector_add_output.bin")
    
    unsigned int total_count = 0;
    bool finish = false;
    do{
        tgPop(vec_d1,vec_s1,vec_s2);

        if (finish) {
            break;
        }
        // call the function
        vector_add(HLS_COMMON_ARG_CALL &vec_d1,&vec_s1,&vec_s2);

        tgCheck(vec_d1,vec_s1,vec_s2);
        ++total_count;
    } while(true);

    printf("Passed after %d\n", total_count);
    return true;
#else
    printf("Skip vector_add\n");
    return true;
#endif
}

bool test_fill_value(){
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
    printf("Test fill_value\n");
    // define input variables 
    int value;
    int fillsize;

    // define arrays
    int big_array [10000];

    // define temp variables


    HLS_COMMON_INIT_VAR();

    // start loading 
    tgLoad("fill_value_output.bin")
    
    unsigned int total_count = 0;
    bool finish = false;
    do{
        tgPop(value,fillsize,big_array);

        if (finish) {
            break;
        }
        // call the function
        fill_value(HLS_COMMON_ARG_CALL value,fillsize,big_array);

        tgCheck(big_array);
        ++total_count;
    } while(true);

    printf("Passed after %d\n", total_count);
    return true;
#else
    printf("Skip fill_value\n");
    return true;
#endif
}

bool test_hevc_loop_filter_chroma_8bit_hls(){
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
    printf("Test hevc_loop_filter_chroma_8bit_hls\n");
    // define input variables 
    int frame_offset;
    int xstride;
    int ystride;

    // define arrays
    uint8_t pix_base [2073600];
    int tc_arr [2];
    uint8_t no_p_arr [2];
    uint8_t no_q_arr [2];

    // define temp variables


    HLS_COMMON_INIT_VAR();

    // start loading 
    tgLoad("hevc_loop_filter_chroma_8bit_hls_output.bin")
    
    unsigned int total_count = 0;
    bool finish = false;
    do{
        tgPop(pix_base,frame_offset,xstride,ystride,tc_arr,no_p_arr,no_q_arr);

        if (finish) {
            break;
        }
        // call the function
        hevc_loop_filter_chroma_8bit_hls(HLS_COMMON_ARG_CALL pix_base,frame_offset,xstride,ystride,tc_arr,no_p_arr,no_q_arr);

        tgCheck(pix_base,tc_arr,no_p_arr,no_q_arr);
        ++total_count;
    } while(true);

    printf("Passed after %d\n", total_count);
    return true;
#else
    printf("Skip hevc_loop_filter_chroma_8bit_hls\n");
    return true;
#endif
}

bool test_cnn_hls(){
#if (TBCONFIG_CNN_HLS || TBCONFIG_ALL)
    printf("Test cnn_hls\n");
    // define input variables 
    int width;
    int height;
    int filter;

    // define arrays
    char pixel [5041];
    char filter_map [64];
    int sum [4096];

    // define temp variables


    HLS_COMMON_INIT_VAR();

    // start loading 
    tgLoad("cnn_hls_output.bin")
    
    unsigned int total_count = 0;
    bool finish = false;
    do{
        tgPop(width,height,filter,pixel,filter_map,sum);

        if (finish) {
            break;
        }
        // call the function
        cnn_hls(HLS_COMMON_ARG_CALL width,height,filter,pixel,filter_map,sum);

        tgCheck(pixel,filter_map,sum);
        ++total_count;
    } while(true);

    printf("Passed after %d\n", total_count);
    return true;
#else
    printf("Skip cnn_hls\n");
    return true;
#endif
}



int main(){
    test_xor_diff_type();
    test_assign_array_complete();
    test_array_xor();
    test_vector_add();
    test_fill_value();
    test_hevc_loop_filter_chroma_8bit_hls();
    test_cnn_hls();

    return 0;
}