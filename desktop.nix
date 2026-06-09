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

  # ROCm 6.4.3 libraries from nixos-25.11 — LM Studio's ROCm engine is built against
  # the 6.x ABI; nixpkgs-unstable has 7.x. First version with RDNA 4 (gfx1201).
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

  # LM Studio bundles its own ROCm runtime (extensions/backends/vendor/), a generic
  # Linux build that dlopens these base libs from the system. The FHS must carry them
  # or its libamdhip64/libhsa-runtime fail to load and the ROCm hardware survey errors
  # out ("load lib failed"). rocm6Libs below stay on LD_LIBRARY_PATH as a fallback.
  extraPkgs =
    pkgs: with pkgs; [
      ocl-icd
      vulkan-loader
      numactl # libnuma.so.1
      libdrm # libdrm.so.2, libdrm_amdgpu.so.1
      elfutils # libelf.so.1
      zlib # libz.so.1
      zstd # libzstd.so.1
    ];

  extraInstallCommands = ''
    # Desktop-file basename must equal the Electron Wayland app_id (LM-Studio) so
    # KWin/GNOME resolve the window icon; StartupWMClass=LM-Studio stays for X11.
    install -Dm444 ${appimageContents}/lm-studio.desktop $out/share/applications/LM-Studio.desktop
    substituteInPlace $out/share/applications/LM-Studio.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=lmstudio'

    # Icons: resize the upstream 0x0 PNG to standard sizes (Icon=lm-studio).
    src_icon="${appimageContents}/usr/share/icons/hicolor/0x0/apps/lm-studio.png"
    for size in 16x16 32x32 48x48 64x64 128x128 256x256; do
      install -dm755 "$out/share/icons/hicolor/$size/apps"
      gm convert "$src_icon" -resize "$size" "$out/share/icons/hicolor/$size/apps/lm-studio.png"
    done

    # GPU driver + ROCm 6.x libs on LD_LIBRARY_PATH; Wayland hints only under Wayland.
    wrapProgram $out/bin/${pname} \
      --set HSA_ENABLE_SDMA 0 \
      --prefix LD_LIBRARY_PATH : "${addDriverRunpath.driverLink}/lib:${rocm6LibPath}" \
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
