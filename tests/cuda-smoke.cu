// SPDX-License-Identifier: MIT
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <vector>

static void check(cudaError_t result, const char *operation) {
    if (result != cudaSuccess) {
        std::fprintf(stderr, "%s: %s\n", operation, cudaGetErrorString(result));
        std::exit(EXIT_FAILURE);
    }
}

__global__ static void fill(int *output, int count) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < count) output[i] = i ^ 0x172;
}

int main() {
    int count = 0;
    check(cudaGetDeviceCount(&count), "cudaGetDeviceCount");
    if (count < 1) {
        std::fprintf(stderr, "No CUDA device found\n");
        return EXIT_FAILURE;
    }
    check(cudaSetDevice(0), "cudaSetDevice");
    cudaDeviceProp properties{};
    check(cudaGetDeviceProperties(&properties, 0), "cudaGetDeviceProperties");
    std::printf("GPU: %s; compute capability %d.%d\n",
                properties.name, properties.major, properties.minor);
    if (properties.major != 7 || properties.minor != 2) {
        std::fprintf(stderr, "Expected a Xavier sm_72 device\n");
        return EXIT_FAILURE;
    }
    constexpr int elements = 1024 * 1024;
    constexpr size_t bytes = elements * sizeof(int);
    int *device = nullptr;
    check(cudaMalloc(&device, bytes), "cudaMalloc (4 MiB)");
    fill<<<elements / 256, 256>>>(device, elements);
    check(cudaGetLastError(), "kernel launch");
    check(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    std::vector<int> host(elements);
    check(cudaMemcpy(host.data(), device, bytes, cudaMemcpyDeviceToHost), "cudaMemcpy");
    check(cudaFree(device), "cudaFree");
    for (int i = 0; i < elements; ++i) {
        if (host[i] != (i ^ 0x172)) {
            std::fprintf(stderr, "Incorrect result at %d\n", i);
            return EXIT_FAILURE;
        }
    }
    std::puts("PASS: CUDA discovery, allocation, kernel execution, and copy-back");
    return EXIT_SUCCESS;
}
