#ifndef _HLS_ENUM_H_
#define _HLS_ENUM_H_

typedef enum {
        enum_xor_diff_type,
        enum_assign_array_complete,
        enum_array_xor,
        enum_vector_add,
        enum_fill_value,
        enum_hevc_loop_filter_chroma_8bit_hls,
        enum_cnn_hls
    } hls_enum_t;
    #define HLS_NUM 7
    #define HLS_CACHE 0
    #define HLS_PARENT 0
#endif
