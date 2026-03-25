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
    ];

  extraInstallCommands = ''
    # Desktop file
    install -Dm444 ${appimageContents}/lm-studio.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/lm-studio.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=lmstudio'

    # Icons (resize from upstream 0x0 PNG)
    src_icon="${appimageContents}/usr/share/icons/hicolor/0x0/apps/lm-studio.png"
    for size in 16x16 32x32 48x48 64x64 128x128 256x256; do
      install -dm755 "$out/share/icons/hicolor/$size/apps"
      gm convert "$src_icon" -resize "$size" "$out/share/icons/hicolor/$size/apps/lm-studio.png"
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
