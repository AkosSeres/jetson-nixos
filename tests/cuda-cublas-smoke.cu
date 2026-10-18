// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 Ákos Seres
#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <set>
#include <string>
#include <vector>

static void cuda_check(cudaError_t status, const char *what) {
    if (status != cudaSuccess) {
        std::fprintf(stderr, "FAIL: %s: %s\n", what, cudaGetErrorString(status));
        std::exit(EXIT_FAILURE);
    }
}

static void blas_check(cublasStatus_t status, const char *what) {
    if (status != CUBLAS_STATUS_SUCCESS) {
        std::fprintf(stderr, "FAIL: %s: cuBLAS status %d\n", what, int(status));
        std::exit(EXIT_FAILURE);
    }
}

__global__ static void fill(float *a, float *b, int elements) {
    const int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < elements) { a[i] = 2.0f; b[i] = 3.0f; }
}

static void print_mapped_cuda_libraries() {
    std::ifstream maps("/proc/self/maps");
    if (!maps) {
        std::fprintf(stderr, "FAIL: cannot inspect mapped CUDA driver libraries\n");
        std::exit(EXIT_FAILURE);
    }
    std::set<std::string> paths;
    std::string line;
    while (std::getline(maps, line)) {
        if (line.find("/libcuda.so") != std::string::npos ||
            line.find("/libcudart.so") != std::string::npos ||
            line.find("/libcublas.so") != std::string::npos ||
            line.find("/libcublasLt.so") != std::string::npos) {
            const auto start = line.find('/');
            if (start != std::string::npos) paths.insert(line.substr(start));
        }
    }
    bool driver_found = false;
    for (const auto &path : paths) {
        std::printf("Mapped CUDA library: %s\n", path.c_str());
        if (path.find("/libcuda.so") != std::string::npos) driver_found = true;
    }
    if (!driver_found) {
        std::fprintf(stderr, "FAIL: libcuda mapping not found after GPU initialization\n");
        std::exit(EXIT_FAILURE);
    }
    std::fflush(stdout);
}

int main() {
    cudaDeviceProp gpu{};
    cuda_check(cudaSetDevice(0), "cudaSetDevice");
    cuda_check(cudaGetDeviceProperties(&gpu, 0), "cudaGetDeviceProperties");
    if (gpu.major != 7 || gpu.minor != 2) {
        std::fprintf(stderr, "FAIL: expected Xavier sm_72, found %d.%d\n", gpu.major, gpu.minor);
        return EXIT_FAILURE;
    }
    int driver = 0, runtime = 0;
    cuda_check(cudaDriverGetVersion(&driver), "cudaDriverGetVersion");
    cuda_check(cudaRuntimeGetVersion(&runtime), "cudaRuntimeGetVersion");
    std::printf("GPU: %s; sm_%d%d; driver API %d; runtime %d; compiled CUDART %d\n",
                gpu.name, gpu.major, gpu.minor, driver, runtime, CUDART_VERSION);
    print_mapped_cuda_libraries();
    if (runtime != CUDART_VERSION) {
        std::fprintf(stderr, "FAIL: CUDA runtime and compiled CUDART versions must match\n");
        return EXIT_FAILURE;
    }

    constexpr int n = 32, elements = n * n;
    constexpr size_t bytes = elements * sizeof(float);
    float *a = nullptr, *b = nullptr, *c = nullptr;
    cuda_check(cudaMalloc(&a, bytes), "cudaMalloc A (4 KiB)");
    cuda_check(cudaMalloc(&b, bytes), "cudaMalloc B (4 KiB)");
    cuda_check(cudaMalloc(&c, bytes), "cudaMalloc C (4 KiB)");
    fill<<<elements / 256, 256>>>(a, b, elements);
    cuda_check(cudaGetLastError(), "native sm_72 fill launch");
    cuda_check(cudaDeviceSynchronize(), "native sm_72 fill synchronize");

    std::puts("PASS: native sm_72 fill kernel (cuBLAS still pending)");
    std::fflush(stdout);

    cublasHandle_t handle{};
    blas_check(cublasCreate(&handle), "cublasCreate");
    int blas_version = 0;
    blas_check(cublasGetVersion(handle, &blas_version), "cublasGetVersion");
    print_mapped_cuda_libraries();
    std::printf("cuBLAS version: %d; CUDA_DISABLE_PTX_JIT=%s\n", blas_version,
                std::getenv("CUDA_DISABLE_PTX_JIT") ? std::getenv("CUDA_DISABLE_PTX_JIT") : "unset");
    const float alpha = 1.0f, beta = 0.0f;
    blas_check(cublasSgemm(handle, CUBLAS_OP_N, CUBLAS_OP_N, n, n, n,
                          &alpha, a, n, b, n, &beta, c, n), "cublasSgemm 32x32");
    cuda_check(cudaDeviceSynchronize(), "cuBLAS synchronize");
    std::vector<float> result(elements);
    cuda_check(cudaMemcpy(result.data(), c, bytes, cudaMemcpyDeviceToHost), "copy result");
    for (int i = 0; i < elements; ++i) {
        if (!std::isfinite(result[i]) || std::fabs(result[i] - 192.0f) > 0.001f) {
            std::fprintf(stderr, "FAIL: C[%d]=%g, expected 192\n", i, result[i]);
            return EXIT_FAILURE;
        }
    }
    blas_check(cublasDestroy(handle), "cublasDestroy");
    cuda_check(cudaFree(c), "cudaFree C");
    cuda_check(cudaFree(b), "cudaFree B");
    cuda_check(cudaFree(a), "cudaFree A");
    std::printf("PASS: CUDA runtime %d native sm_72 kernel and cuBLAS SGEMM; all 1024 results equal 192\n", runtime);
    return EXIT_SUCCESS;
}
