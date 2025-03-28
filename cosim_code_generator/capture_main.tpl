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

const unsigned int MAX_CAPTURE_COUNT = ${capture_count};
const unsigned int MAX_CAPTURE_INTERVAL = ${capture_interval};

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

${cap_testcase}

#ifdef __cplusplus
}
#endif