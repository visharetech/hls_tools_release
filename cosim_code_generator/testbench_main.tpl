#include <memory>
#include "${tb_inc}_config.h"
#include "${tb_inc}.h"
#include "tgload.h"
#if __VITIS_HLS__
    #include <ap_int.h>
#endif

${tb_config}

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

${tb_testcase}

int main(){
${tb_main_body}
    return 0;
}