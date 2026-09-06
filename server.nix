{
  lib,
  stdenvNoCC,
  fetchurl,
  buildFHSEnv,
  writeShellScript,
  runCommand,
  makeWrapper,
  addDriverRunpath,
}:

let
  inherit (stdenvNoCC.hostPlatform) system;
  upstreamArch =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${system};
  source = (lib.importJSON ./sources.json).server.${system};
  inherit (source) version;

  # lms locates its bundled program by reading its own file, so the whole bundle stays byte-pristine and runs inside an FHS environment.
  bundle = stdenvNoCC.mkDerivation {
    pname = "lmstudio-server-bundle";
    inherit version;

    src = fetchurl {
      url = "https://llmster.lmstudio.ai/download/${version}-linux-${upstreamArch}.full.tar.gz";
      inherit (source) hash;
    };

    sourceRoot = ".";
    dontFixup = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r .bundle llmster $out/
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      for member in .bundle/lms llmster; do
        if ! tar -xOzf "$src" "$member" | cmp -s - "$out/$member"; then
          echo "lmstudio-server: $out/$member is not byte-identical to the upstream tarball's $member" >&2
          exit 1
        fi
      done
      runHook postInstallCheck
    '';
  };

  # The bundled ROCm runtime dlopens libnuma, libdrm, libelf, libz and libzstd from the system.
  env = buildFHSEnv {
    name = "lmstudio-server-env";
    targetPkgs = pkgs: [
      pkgs.libgcc
      pkgs.libxcrypt-legacy
      pkgs.ocl-icd
      pkgs.vulkan-loader
      pkgs.numactl
      pkgs.libdrm
      pkgs.elfutils
      pkgs.zlib
      pkgs.zstd
    ];
    runScript = writeShellScript "lmstudio-server-run" ''exec "$@"'';
  };
in
runCommand "lmstudio-server-${version}"
  {
    pname = "lmstudio-server";
    inherit version;
    nativeBuildInputs = [ makeWrapper ];
    passthru = { inherit bundle env; };
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
  }
  ''
    mkdir -p $out/bin
    makeWrapper ${env}/bin/lmstudio-server-env $out/bin/lms \
      --add-flags ${bundle}/.bundle/lms \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib"
    makeWrapper ${env}/bin/lmstudio-server-env $out/bin/llmster \
      --add-flags ${bundle}/llmster \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib"
  ''
