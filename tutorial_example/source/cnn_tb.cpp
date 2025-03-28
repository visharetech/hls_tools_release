#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <pthread.h>
#include "xmem.h"
#include "hls.h"
#include "riscv/hls_long_tail.h"

#ifdef __cplusplus
extern "C" {
#endif

pthread_mutex_t cnn_lock = PTHREAD_MUTEX_INITIALIZER;

// create a standard convolutional function with input of filter and pixel data without using cnnCore class; don't use the shift function
void cnn_reference(int width, int height, int filter, char *pixel, char *filter_map, int *sum) 
{
	int x, y, c, r;
	
    for (x = 0; x < width; x++) {
        for (y = 0; y < height; y++) {
            sum[y * width + x] = 0;
            for (c = 0; c < filter; c++) {
                for (r = 0; r < filter; r++) {
                    sum[y * width + x] += pixel[(y + r) * (width + filter - 1) + x + c] * filter_map[r * filter + c];
//					printf("x %d y %d c %d r %d pixel %d filter %d\n", x, y, c, r, pixel[y+r][x+c], filter[r][c]);
                }
            }
        }
    }
}

//implement testbench function to compare the cnn_hls() against the cnn() function
void test_cnn_hls(xmem_t * xmem, int width, int height, int filter) 
{
	int i, j, *sum0, *sum1;
	char *pixel, *filter_map;
	bool match;

	sum0 = (int*)malloc(width * height * sizeof(int));
//	sum1 = (int*)malloc(width * height * sizeof(int));
	//pixel = (char*)malloc((width + filter - 1) * (height + filter - 1));
	//filter_map = (char*)malloc(filter * filter);
	
	for (i = 0; i < filter * filter; i++)
		xmem->filter_map[i] = i;
	for (i = 0; i < (width + filter - 1) * (height + filter - 1); i++)
		xmem->pixel[i] = i;




	cnn_reference(width, height, filter, xmem->pixel, xmem->filter_map, sum0);
    //print the sum buffer
//    cout << "ref sum:\n";
//    for (int i = 0; i < width; i++) {
//        for (int j = 0; j < height; j++) {
//            cout << sum0[j * width + i] << "\t";
//        }
//        cout << endl; 
//    }
	
    //cnn_hls(width, height, filter, pixel, filter_map, sum1);
    cnn_hls(width, height, filter, xmem->pixel, xmem->filter_map, xmem->sum);
//    cout << "sum:\n";
//    for (int i = 0; i < width; i++) {
//        for (int j = 0; j < height; j++) {
//            cout << sum1[j * width + i] << "\t";
//        }
//        cout << endl; 
//    }
//    cout << endl;

    //compare the sum buffer
    match = 1;
    for (i = 0; i < width; i++) {
        for (j = 0; j < height; j++) {
            if (xmem->sum[j * width + i] != sum0[j * width + i]) {
                match = 0;
				pthread_mutex_lock(&cnn_lock);
                printf("sum mismatch at %d,%d : %d != %d\n", j, i, xmem->sum[j * width + i], sum0[j * width + i]);
				pthread_mutex_unlock(&cnn_lock);
                //break both loops
                i = width;
                j = height;                
            }
        }
    }
    if(match) {
		pthread_mutex_lock(&cnn_lock);
        printf("test passed\n");
		pthread_mutex_unlock(&cnn_lock);
    } else {
		pthread_mutex_lock(&cnn_lock);
        printf("test failed (width:%d, height:%d, filter:%d)\n", width, height, filter);
		pthread_mutex_unlock(&cnn_lock);
        exit(1);
    }
	
	free(sum0);
	//free(sum1);
	//free(pixel);
	//free(filter_map);
}



int test_cnn(xmem_t *xmem) 
{
	int i, width, height, filter;
	
	for (i = 0; i < 1; i++) {
		width = (rand() % MAX_WIDTH_SIZE) + 1;
		height = (rand() % MAX_HEIGHT_SIZE) + 1;
		filter = (rand() % MAX_FILTER_SIZE) + 1;
		pthread_mutex_lock(&cnn_lock);
		printf("test width %d height %d filter %d:\n", width, height, filter);
		pthread_mutex_unlock(&cnn_lock);

		test_cnn_hls(xmem, width, height, filter);
	}
    return 0;
}


void *cnn_task(void *param){

#if __riscv
    set_hls_xmem_partition(mhartid());
#endif

#if __riscv && HLS_XMEM
    xmem_t *xmem = (xmem_t*)get_riscv_xmem_base();
#else
    xmem_t *xmem = (xmem_t*)malloc(sizeof(xmem_t));
#endif

    intptr_t i = (intptr_t)param;


	pthread_mutex_lock(&cnn_lock);
    printf("thread created: %ld\n", i);
	pthread_mutex_unlock(&cnn_lock);

    test_cnn(xmem);

#if !(__riscv && HLS_XMEM)
    free(xmem);
#endif
    return 0;
}

int test_multithread_cnn_example(){

    printf("==== test multi thread cnn example ====\n");
    const int NUM_THREADS = 3; // Number of threads
    pthread_t threads[NUM_THREADS];


    // Create threads
    for (int i = 0; i < NUM_THREADS; ++i) {
        int id = i + 1;
        //run cnn from created threads, the test data will be saved as cnn_hls_output_tidX.bin
        if (pthread_create(&threads[i], nullptr, cnn_task, (void*)id) != 0) {
            std::cerr << "Error creating thread " << i << std::endl;
            return 1; // Exit if thread creation fails
        }
    }

    //also run cnn at main thread, the test data will be saved as cnn_hls_output.bin
    cnn_task(0);
    
    // Wait for all threads to complete
    for (int i = 0; i < NUM_THREADS; ++i) {
            pthread_join(threads[i], nullptr);
    }

    return 0;
}

#ifdef __cplusplus
}
#endif