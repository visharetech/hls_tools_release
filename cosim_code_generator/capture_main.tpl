//####################################
// Append auto generated functions to the end of ${cap_inc}.cpp
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

static const unsigned int MAX_CAPTURE_COUNT = ${capture_count};
static const unsigned int MAX_CAPTURE_INTERVAL = ${capture_interval};

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

${cap_testcase}

#ifdef __cplusplus
}
#endif