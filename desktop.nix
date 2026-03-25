{
  lib,
  appimageTools,
  fetchurl,
  makeWrapper,
  graphicsmagick,
  addDriverRunpath,
  stdenv,
  ocl-icd,
  vulkan-loader,
  rocmPackages,
  # Arguments for multi-channel support (stable / beta)
  version,
  hash,
}:

let
  pname = "lmstudio";

  src = fetchurl {
    url = "https://installers.lmstudio.ai/linux/x64/${version}/LM-Studio-${version}-x64.AppImage";
    inherit hash;
  };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };

  # LM Studio's ROCm llama.cpp engine is compiled against ROCm 6.x sonames
  # (libhipblas.so.2, librocblas.so.4, libamdhip64.so.6) but nixpkgs has
  # ROCm 7.x (soname .3, .5, .7). The ABI is backward-compatible, so we
  # create symlinks from the old sonames to the new libraries.
  rocm-compat = stdenv.mkDerivation {
    pname = "rocm-compat-symlinks";
    version = rocmPackages.hipblas.version;
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/lib
      ln -s ${rocmPackages.hipblas}/lib/libhipblas.so.3 $out/lib/libhipblas.so.2
      ln -s ${rocmPackages.rocblas}/lib/librocblas.so.5 $out/lib/librocblas.so.4
      ln -s ${rocmPackages.clr}/lib/libamdhip64.so.7 $out/lib/libamdhip64.so.6
    '';
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [
    graphicsmagick
    makeWrapper
  ];

  extraPkgs =
    pkgs: with pkgs; [
      ocl-icd
      vulkan-loader
      # ROCm runtime for AMD GPU acceleration (llama.cpp ROCm backend)
      rocmPackages.clr
      rocmPackages.rocm-runtime
      rocmPackages.rocblas
      rocmPackages.hipblas
      rocmPackages.rocm-smi
      # ROCm 6.x → 7.x soname compatibility symlinks
      rocm-compat
    ];

  extraInstallCommands = ''
    # Desktop file — fix Exec, Icon, and StartupWMClass to match our binary name
    install -Dm444 ${appimageContents}/lm-studio.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/lm-studio.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=lmstudio' \
      --replace-fail 'Icon=lm-studio' 'Icon=lmstudio' \
      --replace-fail 'StartupWMClass=LM-Studio' 'StartupWMClass=lmstudio'

    # Icons (resize from upstream 0x0 PNG, install as both lmstudio and lm-studio)
    src_icon="${appimageContents}/usr/share/icons/hicolor/0x0/apps/lm-studio.png"
    for size in 16x16 32x32 48x48 64x64 128x128 256x256; do
      install -dm755 "$out/share/icons/hicolor/$size/apps"
      gm convert "$src_icon" -resize "$size" "$out/share/icons/hicolor/$size/apps/lmstudio.png"
      ln -s lmstudio.png "$out/share/icons/hicolor/$size/apps/lm-studio.png"
    done

    # GPU driver injection + Wayland support + window class for icon
    wrapProgram $out/bin/${pname} \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib" \
      --add-flags "--class=LM-Studio" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    # Extract and patch the bundled lms CLI (available inside the AppImage)
    if [ -f ${appimageContents}/resources/app/.webpack/lms ]; then
      install -Dm755 ${appimageContents}/resources/app/.webpack/lms $out/bin/lms
      patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
        --set-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
        $out/bin/lms
    fi
  '';

  meta = {
    description = "Desktop application for running local LLMs";
    homepage = "https://lmstudio.ai/";
    license = lib.licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "lmstudio";
  };
}
