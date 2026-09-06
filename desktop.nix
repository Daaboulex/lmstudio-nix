{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
  makeWrapper,
  graphicsmagick,
  addDriverRunpath,
  rocm6,
  channel,
}:

let
  pname = "lmstudio";
  inherit (stdenv.hostPlatform) system;
  upstreamArch =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${system};
  source = (lib.importJSON ./sources.json).${channel}.${system};
  inherit (source) version;

  src = fetchurl {
    url = "https://installers.lmstudio.ai/linux/${upstreamArch}/${version}/LM-Studio-${version}-${upstreamArch}.AppImage";
    inherit (source) hash;
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  # LM Studio's ROCm engine exists for x64 only and is built against the ROCm 6 ABI.
  rocm6Libs = lib.optionals stdenv.hostPlatform.isx86_64 [
    rocm6.rocmPackages.clr
    rocm6.rocmPackages.rocm-runtime
    rocm6.rocmPackages.rocblas
    rocm6.rocmPackages.hipblas
    rocm6.rocmPackages.rocm-smi
  ];

  wrapperArgs =
    lib.optionals stdenv.hostPlatform.isx86_64 [
      "--set"
      "HSA_ENABLE_SDMA"
      "0"
    ]
    ++ [
      "--prefix"
      "LD_LIBRARY_PATH"
      ":"
      (lib.makeLibraryPath ([ addDriverRunpath.driverLink ] ++ rocm6Libs))
    ];
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [
    graphicsmagick
    makeWrapper
  ];

  # The bundled ROCm runtime dlopens libnuma, libdrm, libelf, libz and libzstd from the system.
  extraPkgs = pkgs: [
    pkgs.ocl-icd
    pkgs.vulkan-loader
    pkgs.numactl
    pkgs.libdrm
    pkgs.elfutils
    pkgs.zlib
    pkgs.zstd
  ];

  extraInstallCommands = ''
    # The desktop file's basename must equal the Electron Wayland app_id for KWin and GNOME to find the window icon.
    desktop=$out/share/applications/LM-Studio.desktop

    mapfile -t desktopFiles < <(find ${appimageContents} -type f -name '*.desktop')
    if [ "''${#desktopFiles[@]}" -eq 0 ]; then
      echo "lmstudio: the extracted AppImage holds no .desktop file" >&2
      exit 1
    fi
    for f in "''${desktopFiles[@]}"; do
      if ! cmp -s "''${desktopFiles[0]}" "$f"; then
        echo "lmstudio: the extracted AppImage holds differing .desktop files, cannot choose:" >&2
        printf '  %s\n' "''${desktopFiles[@]}" >&2
        exit 1
      fi
    done
    install -Dm444 "''${desktopFiles[0]}" "$desktop"

    sed -i 's|^Exec=.*|Exec=lmstudio|' "$desktop"
    if ! grep -qx 'Exec=lmstudio' "$desktop"; then
      echo "lmstudio: $desktop carries no Exec line to point at the wrapper" >&2
      exit 1
    fi

    iconName=$(sed -n 's/^Icon=//p' "$desktop")
    if [ "$(printf '%s' "$iconName" | wc -l)" -ne 0 ] || [ -z "$iconName" ]; then
      echo "lmstudio: expected exactly one Icon= line in $desktop, got: ''${iconName:-none}" >&2
      exit 1
    fi

    mapfile -t iconFiles < <(find ${appimageContents} -type f -name "$iconName.png")
    if [ "''${#iconFiles[@]}" -eq 0 ]; then
      echo "lmstudio: $desktop declares Icon=$iconName but the extracted AppImage has no $iconName.png" >&2
      exit 1
    fi
    srcIcon=""
    srcIconBytes=0
    for f in "''${iconFiles[@]}"; do
      bytes=$(stat -c %s "$f")
      if [ "$bytes" -gt "$srcIconBytes" ]; then
        srcIconBytes=$bytes
        srcIcon=$f
      fi
    done

    for size in 16x16 32x32 48x48 64x64 128x128 256x256; do
      install -dm755 "$out/share/icons/hicolor/$size/apps"
      gm convert "$srcIcon" -resize "$size" "$out/share/icons/hicolor/$size/apps/$iconName.png"
    done

    wrapProgram $out/bin/${pname} ${lib.escapeShellArgs wrapperArgs} \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    lms=${appimageContents}/resources/app/.webpack/lms
    if [ ! -f "$lms" ]; then
      echo "lmstudio: the extracted AppImage holds no lms CLI at resources/app/.webpack/lms" >&2
      exit 1
    fi
    install -Dm755 "$lms" $out/bin/lms
    patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
      --set-rpath "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}" \
      $out/bin/lms
  '';

  meta = {
    description = "Desktop application for running local LLMs";
    homepage = "https://lmstudio.ai/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "lmstudio";
  };
}
