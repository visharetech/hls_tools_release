#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "xmem.h"
#include "crc.h"
#include "hls.h"

int test_xor_diff_type(xmem_t *xmem){
    for (int i=0; i<10000; i++) {
        XMEM_ASSIGN(int8_t, &xmem->xor_val8, i);        // i will be trimmed as 0-0xFF
        XMEM_ASSIGN(int16_t, &xmem->xor_val16, i+1);    // i will be trimmed to 0-0xFFFF

        xor_diff_type(&xmem->xor_val32, xmem->xor_val16, xmem->xor_val8);
    }
    printf("diff_type_add result: 0x%x\n", xmem->xor_val32);
    if(xmem->xor_val32 == 0x271f){
        printf("xor_diff_type passed\n");
    } else {
        printf("xor_diff_type failed\n");
        return -1;
    }
    return 0;
}

int test_assign_arr_complete(xmem_t *xmem){
    for (int i=0; i<10000; i++) {
        assign_array_complete(xmem->arr_complete, i);
    }
    
    printf("assign_array_complete result: ");
    for (int i=0; i<sizeof(xmem->arr_complete)/sizeof(xmem->arr_complete[0]); i++){
        printf("%d ", xmem->arr_complete[i]);
    }
    printf("\n");

    int expected_result[5] = {9999, 10000, 10001, 10002, 10003};

    if (memcmp(expected_result, xmem->arr_complete, sizeof(expected_result)) == 0){
        printf("assign_array_complete passed\n");
    } else {
        printf("assign_array_complete failed\n");
        return -1;
    }
    return 0;
}

int test_array_xor(xmem_t *xmem){
    for (int i=0; i<10; i++) {
        xmem->arr_s1[i] = i;
        xmem->arr_s2[i] = i+3;
        xmem->arr_d1[i] = 0;
    }

    for (int i=0; i<10000; i++) {
        array_xor(xmem->arr_d1, xmem->arr_s1, xmem->arr_s2, 10);
    }

    printf("array_xor result: ");
    for (int i=0; i<10; i++){
        printf("%d ", xmem->arr_d1[i]);
    }
    printf("\n");

    int expected_result[10] = {3, 5, 7, 5, 3, 13, 15, 13, 3, 5};
    if (memcmp(expected_result, xmem->arr_d1, sizeof(expected_result)) == 0){
        printf("array_xor passed\n");
    } else {
        printf("array_xor failed\n");
        return -1;
    }
    return 0;
}

int test_vector_add(xmem_t *xmem){
    xmem->vec_s1.x = 1;
    xmem->vec_s1.y = 2;
    xmem->vec_s2.x = 3;
    xmem->vec_s2.y = 4;

    for (int i=0; i<10000; i++){
        vector_add(&xmem->vec_d1, &xmem->vec_s1, &xmem->vec_s2);
        xmem->vec_s1.x += xmem->vec_d1.x;
        xmem->vec_s1.y += xmem->vec_d1.y;

        xmem->vec_s2.x += xmem->vec_d1.x;
        xmem->vec_s2.y += xmem->vec_d1.y;
    }

    printf("vector_add result: %d %d\n", xmem->vec_d1.x, xmem->vec_d1.y);

    if (xmem->vec_d1.x == -1854842452 && xmem->vec_d1.y == 1512703618){
        printf("vector_add passed\n");
    } else {
        printf("vector_add failed\n");
        return -1;
    }
    return 0;
}

int test_fill_value(xmem_t *xmem){
    for(int i=0; i<10000; i++){
        xmem->big_array[i] = i;
    }

    for(int i=0; i<10000; i++) {
        fill_value(i+10, i, xmem->big_array);
    }

    uint32_t crc_value = crc32((uint8_t*)xmem->big_array, sizeof(xmem->big_array));
    printf("fill_value crc32: %x\n", crc_value);

    if (crc_value == 0xb3338fc){
        printf("fill_value passed\n");
    } else {
        printf("fill_value failed\n");
        return -1;
    }
    return 0;
}

int test_hevc_loop_filter_chroma_8bit_hls(xmem_t *xmem){
    // Initialize test parameters
    int frame_offset = 0; 
    int xstride = 1; // Assuming 1 for simplicity
    int ystride = 1920; // Height of the image
    xmem->tc_arr[0] = 10;
    xmem->tc_arr[1] = 20; // Thresholds for filtering
    xmem->no_p_arr[0] = 0;
    xmem->no_p_arr[1] = 0; // Allow adjustment of P0
    xmem->no_q_arr[0] = 0;
    xmem->no_q_arr[1] = 0; // Allow adjustment of Q0

    int checksum = 0;
    for(int i=0; i<sizeof(xmem->pix_base); i++){
        uint8_t bytevalue = i & 0xff;
        XMEM_ASSIGN(uint8_t, xmem->pix_base+i, bytevalue);
        checksum += bytevalue;
    }

    uint32_t crc_value = crc32(xmem->pix_base, sizeof(xmem->pix_base));
    printf("crc32: %x\n", crc_value);

    for (int i=10; i<1070; i+=8) {
        hevc_loop_filter_chroma_8bit_hls(xmem->pix_base, frame_offset, xstride, ystride, xmem->tc_arr, xmem->no_p_arr, xmem->no_q_arr);
    }

    crc_value = crc32(xmem->pix_base, sizeof(xmem->pix_base));
    printf("crc32: %x\n", crc_value);

    if(crc_value == 0xb427ab67){
        printf("hevc_loop_filter_chroma_8bit_hls passed\n");
    } else {
        printf("hevc_loop_filter_chroma_8bit_hls failed\n");
        return -1;
    }
    return 0;
}

void test_singlethread_example(){
#if __riscv && HLS_XMEM
    xmem_t *xmem = (xmem_t*)get_riscv_xmem_base();
#else
    xmem_t *xmem = (xmem_t*)malloc(sizeof(xmem_t));
    if (xmem == NULL){
        printf("cannot allocate xmem\n");
        exit(1);
    }
#endif

    printf("==== test signle thread example ====\n");

    test_xor_diff_type(xmem);
    test_assign_arr_complete(xmem);
    test_array_xor(xmem);
    test_vector_add(xmem);
    test_fill_value(xmem);
    test_hevc_loop_filter_chroma_8bit_hls(xmem);

#if !(__riscv && HLS_XMEM)
    free(xmem);
#endif
}