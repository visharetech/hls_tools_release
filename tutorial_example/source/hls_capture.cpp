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

static const unsigned int MAX_CAPTURE_COUNT = 10000;
static const unsigned int MAX_CAPTURE_INTERVAL = 1;

//==============================================================
// Save cabac data bin
// capture to cabac file in case of PARENT_FUNC_MATCHED or PARENT_FUNC_NONE
// Hence, the child function cabac data doesn't modified the g_fbin, so it will be save to parent function one.
#define CABAC_LOG_START(filename)   bool is_capture_func = (parent_func_status == PARENT_FUNC_MATCHED || parent_func_status == PARENT_FUNC_NONE); \
                                    auto cabac_iter = g_fbin.find(__tid);       \
                                    if (is_capture_func) {                      \
                                        if(cabac_iter == g_fbin.end()){         \
                                            FILE *fbin = fopen(filename_append_tidx(filename).c_str(), "wb");           \
                                            if (fbin == NULL) {                     \
                                                printf("cannot open file to write: %s", filename);  \
                                                exit(-1);                           \
                                            }                                       \
                                            capture_cabac_info info(fbin, true);    \
                                            g_fbin[__tid] = info;           \
                                        } else {                                    \
                                            cabac_iter->second.enable = true;       \
                                        }                                           \
                                    }


#define CABAC_LOG_END()             if (is_capture_func) {   \
                                        if (capture_group.items[__tid]->get_capture_count() == MAX_CAPTURE_COUNT &&  g_fbin[__tid].f != NULL) {   \
                                            fclose(g_fbin[__tid].f);                \
                                            g_fbin[__tid].f = NULL;                 \
                                        }                                           \
                                        g_fbin[__tid].enable = false;               \
                                    }



struct capture_cabac_info{
    FILE* f;
    bool enable;

    capture_cabac_info(){
        f= NULL;
        enable = false;
    }
    capture_cabac_info(FILE* p_f, bool p_enable){
        f= p_f;
        enable = p_enable;
    }
};

static std::unordered_map<pthread_t, capture_cabac_info> g_fbin;

void decodeBin_log(int ctx, int bin)
{
    pthread_t tid = pthread_self();
    auto iter = g_fbin.find(tid);
    if (iter == g_fbin.end()){
        return;
    }

    if (iter->second.f != NULL && iter->second.enable)
    {
        //fputc(ctx & 0xff, outF);
        //fputc((ctx >> 8) & 0xff, outF);
        fputc(bin, iter->second.f);
    }
}

//==============================================================

#ifdef __cplusplus
extern "C" {
#endif

void CAPTURE_(xor_diff_type)(uint32_t * xor_val32_ptr,uint16_t xor_val16,uint8_t xor_val8){
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
static CCapture capture_xor_diff_type;
CCapture *capture = &capture_xor_diff_type;
pthread_t __tid = pthread_self();

    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);

    enum PARENT_FUNCTION_STATUS parent_func_status = CCapture::is_parent_func(__func__);

    // define temporary variables to hold pointers
    uint32_t & xor_val32 = ASSIGN_REF(xor_val32_ptr, __FUNCTION__);


    tgOpen("xor_diff_type_output.bin", xor_val32, xor_val16, xor_val8);

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
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
static CCapture capture_assign_array_complete;
CCapture *capture = &capture_assign_array_complete;
pthread_t __tid = pthread_self();

    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);

    enum PARENT_FUNCTION_STATUS parent_func_status = CCapture::is_parent_func(__func__);

    // define temporary variables to hold pointers


    tgOpen("assign_array_complete_output.bin", arr_complete, base);

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
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
static CCapture capture_array_xor;
CCapture *capture = &capture_array_xor;
pthread_t __tid = pthread_self();

    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);

    enum PARENT_FUNCTION_STATUS parent_func_status = CCapture::is_parent_func(__func__);

    // define temporary variables to hold pointers


    tgOpen("array_xor_output.bin", arr_d1, arr_s1, arr_s2, count);

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
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
static CCapture capture_vector_add;
CCapture *capture = &capture_vector_add;
pthread_t __tid = pthread_self();

    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);

    enum PARENT_FUNCTION_STATUS parent_func_status = CCapture::is_parent_func(__func__);

    // define temporary variables to hold pointers
    vector_2d & vec_d1 = ASSIGN_REF(vec_d1_ptr, __FUNCTION__);
    const vector_2d & vec_s1 = ASSIGN_REF(vec_s1_ptr, __FUNCTION__);
    const vector_2d & vec_s2 = ASSIGN_REF(vec_s2_ptr, __FUNCTION__);


    tgOpen("vector_add_output.bin", vec_d1, vec_s1, vec_s2);

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
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
static CCapture capture_fill_value;
CCapture *capture = &capture_fill_value;
pthread_t __tid = pthread_self();

    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);

    enum PARENT_FUNCTION_STATUS parent_func_status = CCapture::is_parent_func(__func__);

    // define temporary variables to hold pointers


    tgOpen("fill_value_output.bin", value, fillsize, big_array);

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
#if 0 //cosim_code_generator: This function is marked as skip in function_list.txt
static CCapture capture_hevc_loop_filter_chroma_8bit_hls;
CCapture *capture = &capture_hevc_loop_filter_chroma_8bit_hls;
pthread_t __tid = pthread_self();

    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);

    enum PARENT_FUNCTION_STATUS parent_func_status = CCapture::is_parent_func(__func__);

    // define temporary variables to hold pointers


    tgOpen("hevc_loop_filter_chroma_8bit_hls_output.bin", pix_base, frame_offset, xstride, ystride, tc_arr, no_p_arr, no_q_arr);

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
static CCapture capture_cnn_hls;
CCapture *capture = &capture_cnn_hls;
pthread_t __tid = pthread_self();

    static std::mutex mtx;
    std::lock_guard<std::mutex> lock(mtx);

    enum PARENT_FUNCTION_STATUS parent_func_status = CCapture::is_parent_func(__func__);

    // define temporary variables to hold pointers


    tgOpen("cnn_hls_output.bin", width, height, filter, pixel, filter_map, sum);

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