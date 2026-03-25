{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  addDriverRunpath,
  libgcc,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lmstudio-server";
  version = "0.4.7";

  src = fetchurl {
    url = "https://llmster.lmstudio.ai/download/${finalAttrs.version}-linux-x64.tar.gz";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib # libstdc++
    libgcc # libatomic, libgomp
  ];

  # Bun-compiled binaries break when stripped
  dontStrip = true;

  # autoPatchelfHook may warn about libcuda.so.1 — this is expected,
  # it's provided by the GPU driver at runtime via addDriverRunpath
  autoPatchelfIgnoreMissingDeps = [
    "libcuda.so.1"
    "libcuda.so"
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    # Find and install the lms binary
    mkdir -p $out/bin $out/lib/lmstudio-server

    # Copy the full bundle
    cp -r . $out/lib/lmstudio-server/

    # Create wrapper for lms CLI with GPU driver path
    makeBinaryWrapper $out/lib/lmstudio-server/bin/lms $out/bin/lms \
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
