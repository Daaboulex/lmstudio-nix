{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  addDriverRunpath,
  libgcc,
  vulkan-loader,
  libxcrypt-legacy,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lmstudio-server";
  version = "0.0.9-1";

  src = fetchurl {
    url = "https://llmster.lmstudio.ai/download/${finalAttrs.version}-linux-x64.full.tar.gz";
    hash = "sha256-3G2qWyYXfNDwoxo4fMMooNNGA2rCurBhw7SlhykU5Hk=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++
    libgcc # libatomic, libgomp
    vulkan-loader # libvulkan.so.1
    libxcrypt-legacy # libcrypt.so.1
  ];

  # Bun-compiled binaries break when stripped
  dontStrip = true;

  # CUDA libs are provided by the GPU driver at runtime via addDriverRunpath
  autoPatchelfIgnoreMissingDeps = [
    "libcuda.so.1"
    "libcuda.so"
    "libcudart.so.11.0"
    "libcublas.so.11"
    "libcublasLt.so.11"
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/lmstudio-server

    # Copy the full bundle
    cp -r .bundle $out/lib/lmstudio-server/
    cp llmster $out/lib/lmstudio-server/

    # Create wrapper for lms CLI with GPU driver path
    makeBinaryWrapper $out/lib/lmstudio-server/.bundle/lms $out/bin/lms \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib"

    # Create wrapper for llmster daemon with GPU driver path
    makeBinaryWrapper $out/lib/lmstudio-server/llmster $out/bin/llmster \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib"

    runHook postInstall
  '';

  meta = {
    description = "LM Studio headless server and CLI for local LLM inference";
    homepage = "https://lmstudio.ai/";
    license = lib.licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "lms";
  };
})
