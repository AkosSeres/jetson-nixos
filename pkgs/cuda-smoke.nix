# SPDX-License-Identifier: MIT
{ lib, cudaPackages }:
cudaPackages.backendStdenv.mkDerivation {
  pname = "xavier-cuda-smoke";
  version = "1";
  src = ../tests/cuda-smoke.cu;
  dontUnpack = true;
  nativeBuildInputs = [ cudaPackages.cuda_nvcc ];
  buildInputs = [ cudaPackages.cuda_cudart ];
  buildPhase = ''
    runHook preBuild
    nvcc -O2 -arch=sm_72 --cudart=shared "$src" -o xavier-cuda-smoke
    runHook postBuild
  '';
  installPhase = ''
    install -Dm755 xavier-cuda-smoke "$out/bin/xavier-cuda-smoke"
  '';
  meta = {
    description = "Bounded Xavier CUDA discovery, allocation, and compute smoke test";
    license = lib.licenses.mit;
    platforms = [ "aarch64-linux" ];
    mainProgram = "xavier-cuda-smoke";
  };
}
