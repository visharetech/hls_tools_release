#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

#include "xmem.h"
#include "hls.h"
#include "hls_apcall.h"


int main(int argc, char **argv){
    printf("=== main entry ===\n");
    
#if ASIM_CALL
    printf("Enable ASIM_CALL\n");
#endif

#if CAPTURE_COSIM
    printf("Enable CAPTURE_COSIM\n");
#endif

#if _rvTranslate
    asim_notify_xmem_size(sizeof(xmem_t));
#endif

#if __riscv
    riscv_init();
#endif

    xmem_rw_test();
    test_singlethread_example();
    test_multithread_cnn_example();

    return 0;
}