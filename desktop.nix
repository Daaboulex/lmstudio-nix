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
  # ROCm 6.x from nixos-25.05 — LM Studio's ROCm engine needs 6.x ABI.
  # Remove once LM Studio ships a ROCm 7.x engine.
  rocm6,
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

  # ROCm 6.x libraries from nixos-25.05 for LM Studio's pre-compiled ROCm engine.
  # The engine links against ROCm 6.x sonames (libhipblas.so.2, librocblas.so.4,
  # libamdhip64.so.6). ROCm 7.x (current nixpkgs) has ABI-incompatible sonames
  # (.so.3, .so.5, .so.7). Using actual ROCm 6.x libs instead of compat symlinks.
  rocm6Libs = [
    rocm6.rocmPackages.clr
    rocm6.rocmPackages.rocm-runtime
    rocm6.rocmPackages.rocblas
    rocm6.rocmPackages.hipblas
    rocm6.rocmPackages.rocm-smi
  ];

  rocm6LibPath = lib.makeLibraryPath rocm6Libs;
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
      # ROCm 7.x runtime (for future engine updates)
      rocmPackages.clr
      rocmPackages.rocm-runtime
      rocmPackages.rocblas
      rocmPackages.hipblas
      rocmPackages.rocm-smi
    ]
    # ROCm 6.x libs for current LM Studio engine
    ++ rocm6Libs;

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

    # GPU driver injection + ROCm 6.x libs + Wayland support + window class for icon
    wrapProgram $out/bin/${pname} \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib:${rocm6LibPath}" \
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
