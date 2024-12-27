nvcc -arch=compute_35 -L/usr/local/cuda/lib64 -lcublas -o cuda_mul ./matrix_mul.cu
