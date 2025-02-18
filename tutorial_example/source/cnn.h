/*
This function perform convolution operation on a(W+F-1)x(H+F-1) image with a FxF filter by get WxH sum buffer
- load pixels to a (W+F-1)x(H+F-1) buffer
- initialize WxH sum buffer to 0
- shift pixel operation type 
    - UP: shift each line upwards by 1 pixel while the top line is shifted to the bottom
    - LEFT: shift each line leftwards by 1 pixel while the leftmost column is shifted to the rightmost column
    - DOWN: shift each line downwards by 1 pixel while the bottom line is shifted to the top
    - RIGHT: shift each line rightwards by 1 pixel while the rightmost column is shifted to the leftmost column

- vdir is set a DOWN
- for each column c0 of the filter
    - for each row r0 of the filter
        - apply filter[r0][c0] to for each pixel at x,y in the buffer
            - sum[r][c] += pixel[r][c] * filter[r0][c0] for each r,c
        - if r0<F-1, shift in the vdir direction 
        - else shift LEFT by 1 step
    - toggle vdir, i.e. vdir = (vdir == DOWN) ? UP : DOWN

assume W=2, H=2, d=1, filter=2x2, the pixel buffer at each step is as follows:
step 1:
0 1 2 
3 4 5 
6 7 8
shift UP 

step 2: 
3 4 5 
6 7 8
0 1 2
shift LEFT

step 3: 
4 5 3 
7 8 6
1 2 0
shift DOWN 

step 4:
1 2 0
4 5 3
7 8 6

*/

#include <iostream>
#include <string>
#include <cstring>


enum {UP, LEFT, DOWN};


class cnnCore {
// declare sum buffer, pixel buffer and filter buffer
 	int *sum;
	char *pixel;
	int width;
	int height;
	int rwidth;
	int rheight;
	
public:

	cnnCore() 
	{
		pixel = NULL;
		sum = NULL;
	}

    // load pixel and filter data
	void config(int width, int height, int filter, char *datIn, int* dataOut) 
	{
		this->rwidth = width + filter - 1;
		this->rheight = height + filter - 1;
		//pixel = (char*)malloc(rwidth * rheight);
		//sum = (int*)malloc(width * height * sizeof(int));
		//memcpy(pixel, datIn, rwidth * rheight);
		pixel = datIn;
		sum = dataOut;
		this->width = width;
		this->height = height;
    }

    //output the sum buffer by copying the sum[y][x] to the output buffer outbuf
	void output(int *outbuf) 
	{
		memcpy(outbuf, sum, width * height * sizeof(int));
		//if (pixel != NULL) {
		//	free(pixel);
		//	pixel = NULL;
		//}
		//if (sum != NULL) {
		//	free(sum);
		//	sum = NULL;
		//}
	}
	
	void shift(int dir) 
	{
		char tmp_pixel;
		int x, y;
		
//		printf("original: ");
//		for (int i = 0; i < rwidth * rheight; i++)
//			printf("%d ", pixel[i]);
//		printf("\n");
		
        switch (dir) {
            case UP:
				for (x = 0; x < rwidth; x++) {
					tmp_pixel = pixel[(rheight - 1) * rwidth + x];
					for (y = rheight - 2; y >= 0; y--) 
						pixel[(y + 1) * rwidth + x] = pixel[y * rwidth + x];
					pixel[x] = tmp_pixel;
				}
                break;
            case LEFT:
				for (y = 0; y < rheight; y++) {
					tmp_pixel = pixel[y * rwidth];
					for (x = 1; x < rwidth; x++) 
						pixel[y * rwidth + x - 1] = pixel[y * rwidth + x];
					pixel[y * rwidth + rwidth - 1] = tmp_pixel;
				}
                break;
			default: // case DOWN: 
				for (x = 0; x < rwidth; x++) {
					tmp_pixel = pixel[x];
					for (y = 1; y < rheight; y++) 
						pixel[(y - 1) * rwidth + x] = pixel[y * rwidth + x];
					pixel[(rheight - 1) * rwidth + x] = tmp_pixel;
				}
                break;
        }
		
//		printf("new %d: ", dir);
//		for (int i = 0; i < rwidth * rheight; i++)
//			printf("%d ", pixel[i]);
//		printf("\n");
		
    }


    // implement scalar multiply operation
	void scalar_matrix_multAdd(bool clear, char filter) 
	{
		int i;

		for (i = 0; i < width * height; i++) {
			if (clear)
				sum[i] = 0;
			sum[i] += pixel[(i / width) * rwidth + (i % width)] * filter;
		}
    }

}; 

