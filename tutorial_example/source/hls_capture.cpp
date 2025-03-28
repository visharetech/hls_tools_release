//####################################
// Append auto generated functions to the end of hls.cpp
#include <mutex>
#include "tgcapture.h"

template<typename T> T& ASSIGN_REF(T* ptr, const char *func_name) {
    if(ptr == NULL) {
        static T zero;
        static unsigned int i;
        if (i < 10) {
            std::cout << "warning: " <<  i << ':' << func_name << ": pointer is NULL\n";
            ++i;
        }
        return zero;
    } else {
        return *ptr;
    }
}

template<typename T> const T& ASSIGN_REF(const T* ptr, const char *func_name) {
    if(ptr == NULL) {
        static T zero;
        static unsigned int i;
        if (i < 10) {
            std::cout << "warning: " <<  i << ':' << func_name << ": const pointer is NULL\n";
            ++i;
        }
        return zero;
    } else {
        return *ptr;
    }
}

const unsigned int MAX_CAPTURE_COUNT = 10000;
const unsigned int MAX_CAPTURE_INTERVAL = 1;

//==============================================================
// Save cabac data bin
// capture to cabac file in case of PARENT_FUNC_MATCHED or PARENT_FUNC_NONE
// Hence, the child function cabac data doesn't modified the g_fbin, so it will be save to parent function one.
#define CABAC_LOG_START()           for (auto & capture : capture_list) {       \
                                            CaptureGrpKey cabackey(__tid, capture->get_function_name());    \
                                            cabac_log.enable_cabac(cabackey);        \
                                    }


#define CABAC_LOG_END()             for (auto & capture : capture_list) {        \
                                            CaptureGrpKey cabackey(__tid, capture->get_function_name());    \
                                            cabac_log.disable_cabac(cabackey);        \
                                    }

CCabacLog cabac_log;

void decodeBin_log(int ctx, int bin)
{
    cabac_log.log_data(ctx, bin);
}

//==============================================================

#ifdef __cplusplus
extern "C" {
#endif

void CAPTURE_(xor_diff_type)(uint32_t * xor_val32_ptr,uint16_t xor_val16,uint8_t xor_val8){
#if 1

    pthread_t __tid = pthread_self();
    CaptureGrpKey key(__tid, __func__);
    capture_group.create_if_not_exist(key, false);
    std::unordered_set<CCapture*> capture_list;
    capture_group.get_capture_list(__func__, capture_list);
    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);


    // define temporary variables to hold pointers
    uint32_t & xor_val32 = ASSIGN_REF(xor_val32_ptr, __FUNCTION__);


    tgOpen(xor_val32, xor_val16, xor_val8);

    tgCaptureBeforeCall(xor_val32,xor_val16,xor_val8);

    // call the function with the initial parameters
    IMPL(xor_diff_type)(xor_val32_ptr, xor_val16, xor_val8);

    tgCaptureAfterCall(xor_val32);

    tgClose();
#else
    IMPL(xor_diff_type)(xor_val32_ptr, xor_val16, xor_val8);
#endif
}

void CAPTURE_(assign_array_complete)(int arr_complete[5],int base){
#if 1

    pthread_t __tid = pthread_self();
    CaptureGrpKey key(__tid, __func__);
    capture_group.create_if_not_exist(key, false);
    std::unordered_set<CCapture*> capture_list;
    capture_group.get_capture_list(__func__, capture_list);
    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);


    // define temporary variables to hold pointers


    tgOpen(arr_complete, base);

    tgCaptureBeforeCall(arr_complete,5,base);

    // call the function with the initial parameters
    IMPL(assign_array_complete)(arr_complete, base);

    tgCaptureAfterCall(arr_complete,5);

    tgClose();
#else
    IMPL(assign_array_complete)(arr_complete, base);
#endif
}

void CAPTURE_(array_xor)(int arr_d1[10],int arr_s1[10],int arr_s2[10],int count){
#if 1

    pthread_t __tid = pthread_self();
    CaptureGrpKey key(__tid, __func__);
    capture_group.create_if_not_exist(key, false);
    std::unordered_set<CCapture*> capture_list;
    capture_group.get_capture_list(__func__, capture_list);
    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);


    // define temporary variables to hold pointers


    tgOpen(arr_d1, arr_s1, arr_s2, count);

    tgCaptureBeforeCall(arr_d1,10,arr_s1,10,arr_s2,10,count);

    // call the function with the initial parameters
    IMPL(array_xor)(arr_d1, arr_s1, arr_s2, count);

    tgCaptureAfterCall(arr_d1,10,arr_s1,10,arr_s2,10);

    tgClose();
#else
    IMPL(array_xor)(arr_d1, arr_s1, arr_s2, count);
#endif
}

void CAPTURE_(vector_add)(vector_2d * vec_d1_ptr,const vector_2d * vec_s1_ptr,const vector_2d * vec_s2_ptr){
#if 1

    pthread_t __tid = pthread_self();
    CaptureGrpKey key(__tid, __func__);
    capture_group.create_if_not_exist(key, false);
    std::unordered_set<CCapture*> capture_list;
    capture_group.get_capture_list(__func__, capture_list);
    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);


    // define temporary variables to hold pointers
    vector_2d & vec_d1 = ASSIGN_REF(vec_d1_ptr, __FUNCTION__);
    const vector_2d & vec_s1 = ASSIGN_REF(vec_s1_ptr, __FUNCTION__);
    const vector_2d & vec_s2 = ASSIGN_REF(vec_s2_ptr, __FUNCTION__);


    tgOpen(vec_d1, vec_s1, vec_s2);

    tgCaptureBeforeCall(vec_d1,vec_s1,vec_s2);

    // call the function with the initial parameters
    IMPL(vector_add)(vec_d1_ptr, vec_s1_ptr, vec_s2_ptr);

    tgCaptureAfterCall(vec_d1,vec_s1,vec_s2);

    tgClose();
#else
    IMPL(vector_add)(vec_d1_ptr, vec_s1_ptr, vec_s2_ptr);
#endif
}

void CAPTURE_(fill_value)(int value,int fillsize,int big_array[10000]){
#if 1

    pthread_t __tid = pthread_self();
    CaptureGrpKey key(__tid, __func__);
    capture_group.create_if_not_exist(key, false);
    std::unordered_set<CCapture*> capture_list;
    capture_group.get_capture_list(__func__, capture_list);
    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);


    // define temporary variables to hold pointers


    tgOpen(value, fillsize, big_array);

    tgCaptureBeforeCall(value,fillsize,big_array,10000);

    // call the function with the initial parameters
    IMPL(fill_value)(value, fillsize, big_array);

    tgCaptureAfterCall(big_array,10000);

    tgClose();
#else
    IMPL(fill_value)(value, fillsize, big_array);
#endif
}

void CAPTURE_(hevc_loop_filter_chroma_8bit_hls)(uint8_t pix_base[2073600],int frame_offset,int xstride,int ystride,int tc_arr[2],uint8_t no_p_arr[2],uint8_t no_q_arr[2]){
#if 1

    pthread_t __tid = pthread_self();
    CaptureGrpKey key(__tid, __func__);
    capture_group.create_if_not_exist(key, false);
    std::unordered_set<CCapture*> capture_list;
    capture_group.get_capture_list(__func__, capture_list);
    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);


    // define temporary variables to hold pointers


    tgOpen(pix_base, frame_offset, xstride, ystride, tc_arr, no_p_arr, no_q_arr);

    tgCaptureBeforeCall(pix_base,2073600,frame_offset,xstride,ystride,tc_arr,2,no_p_arr,2,no_q_arr,2);

    // call the function with the initial parameters
    IMPL(hevc_loop_filter_chroma_8bit_hls)(pix_base, frame_offset, xstride, ystride, tc_arr, no_p_arr, no_q_arr);

    tgCaptureAfterCall(pix_base,2073600,tc_arr,2,no_p_arr,2,no_q_arr,2);

    tgClose();
#else
    IMPL(hevc_loop_filter_chroma_8bit_hls)(pix_base, frame_offset, xstride, ystride, tc_arr, no_p_arr, no_q_arr);
#endif
}

void CAPTURE_(cnn_hls)(int width,int height,int filter,char pixel[5041],char filter_map[64],int sum[4096]){
#if 1

    pthread_t __tid = pthread_self();
    CaptureGrpKey key(__tid, __func__);
    capture_group.create_if_not_exist(key, false);
    std::unordered_set<CCapture*> capture_list;
    capture_group.get_capture_list(__func__, capture_list);
    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);


    // define temporary variables to hold pointers


    tgOpen(width, height, filter, pixel, filter_map, sum);

    tgCaptureBeforeCall(width,height,filter,pixel,5041,filter_map,64,sum,4096);

    // call the function with the initial parameters
    IMPL(cnn_hls)(width, height, filter, pixel, filter_map, sum);

    tgCaptureAfterCall(pixel,5041,filter_map,64,sum,4096);

    tgClose();
#else
    IMPL(cnn_hls)(width, height, filter, pixel, filter_map, sum);
#endif
}



#ifdef __cplusplus
}
#endif