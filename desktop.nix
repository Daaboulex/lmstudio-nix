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
  # ROCm 6.4.3 from nixos-25.11 — LM Studio's ROCm engine needs 6.x ABI.
  # First version with RDNA 4 (gfx1201) support. Remove once LM Studio ships ROCm 7.x.
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

  # ROCm 6.4.3 libraries from nixos-25.11 — injected via LD_LIBRARY_PATH only.
  # NOT in extraPkgs to avoid pulling nixos-25.11 deps into FHS (keeps all other
  # packages on latest nixpkgs-unstable). The nix store is bind-mounted into the
  # FHS sandbox, so these store paths are accessible via LD_LIBRARY_PATH.
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

  # All FHS packages from nixpkgs-unstable (latest). ROCm 6.x libs are NOT in
  # extraPkgs — they're injected via LD_LIBRARY_PATH only, avoiding older deps
  # from nixos-25.11 polluting the FHS environment. The nix store is bind-mounted
  # into the FHS sandbox so the store paths are accessible.
  extraPkgs =
    pkgs: with pkgs; [
      ocl-icd
      vulkan-loader
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

    # GPU driver injection + ROCm 6.x libs + Wayland support + window class for icon
    wrapProgram $out/bin/${pname} \
      --set HSA_ENABLE_SDMA 0 \
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
