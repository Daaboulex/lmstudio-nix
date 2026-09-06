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

let
  inherit (stdenv.hostPlatform) system;
  upstreamArch =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${system};
  source = (lib.importJSON ./sources.json).server.${system};
in
stdenv.mkDerivation (finalAttrs: {
  pname = "lmstudio-server";
  inherit (source) version;

  src = fetchurl {
    url = "https://llmster.lmstudio.ai/download/${finalAttrs.version}-linux-${upstreamArch}.full.tar.gz";
    inherit (source) hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libgcc
    vulkan-loader
    libxcrypt-legacy
  ];

  # Bun-compiled binaries break when stripped.
  dontStrip = true;

  # libcuda comes from the GPU driver; the x64 bundle vendors CUDA 11 under full-version file names its own loader resolves.
  autoPatchelfIgnoreMissingDeps = [
    "libcuda.so.1"
  ]
  ++ lib.optionals stdenv.hostPlatform.isx86_64 [
    "libcudart.so.11.0"
    "libcublas.so.11"
    "libcublasLt.so.11"
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/lmstudio-server
    cp -r .bundle $out/lib/lmstudio-server/
    cp llmster $out/lib/lmstudio-server/

    makeBinaryWrapper $out/lib/lmstudio-server/.bundle/lms $out/bin/lms \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib"
    makeBinaryWrapper $out/lib/lmstudio-server/llmster $out/bin/llmster \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib"

    runHook postInstall
  '';

  meta = {
    description = "LM Studio headless server and CLI for local LLM inference";
    homepage = "https://lmstudio.ai/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "lms";
  };
})
