# SPDX-License-Identifier: GPL-2.0-only
{ lib, cudaPackages }:
cudaPackages.backendStdenv.mkDerivation {
  pname = "xavier-cuda-cublas-smoke";
  version = "1";
  src = ../tests/cuda-cublas-smoke.cu;
  dontUnpack = true;
  nativeBuildInputs = [ cudaPackages.cuda_nvcc ];
  buildInputs = [
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
  ];
  buildPhase = ''
    runHook preBuild
    nvcc -std=c++17 -O2 --generate-code=arch=compute_72,code=sm_72 --cudart=shared \
      -I${lib.getInclude cudaPackages.libcublas}/include \
      -L${lib.getLib cudaPackages.libcublas}/lib \
      "$src" -lcublas -o xavier-cuda-cublas-smoke
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 xavier-cuda-cublas-smoke "$out/bin/xavier-cuda-cublas-smoke"
    install -Dm644 ${../tests/LICENSE} "$out/share/licenses/xavier-cuda-cublas-smoke/LICENSE"
    runHook postInstall
  '';
  # CUDA's postFixupHooks can still change RUNPATH after the postFixup hook.
  # A final phase records the ELF only after every fixup hook has completed.
  postPhases = [ "recordDynamicSectionPhase" ];
  recordDynamicSectionPhase = ''
    mkdir -p "$out/share/xavier-cuda-cublas-smoke"
    ${lib.getExe' cudaPackages.backendStdenv.cc.bintools "readelf"} \
      -d "$out/bin/xavier-cuda-cublas-smoke" \
      > "$out/share/xavier-cuda-cublas-smoke/dynamic-section.txt"
  '';
  meta = {
    description = "Bounded Xavier native CUDA kernel and cuBLAS SGEMM smoke test";
    license = lib.licenses.mit;
    platforms = [ "aarch64-linux" ];
    mainProgram = "xavier-cuda-cublas-smoke";
  };
}
