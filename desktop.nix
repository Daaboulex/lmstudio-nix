{
  lib,
  stdenv,
  appimageTools,
  buildFHSEnv,
  fetchurl,
  makeWrapper,
  graphicsmagick,
  addDriverRunpath,
  rocm6,
  channel,
}:

let
  lmstudio = {
    pname = "lmstudio";
    description = "Desktop application for running local LLMs";
    host = "installers.lmstudio.ai";
    product = "LM-Studio";
    lms = "resources/app/.webpack/lms";
  };
  app =
    {
      stable = lmstudio;
      beta = lmstudio;
      bionic = {
        pname = "lmstudio-bionic";
        description = "LM Studio Bionic, the agent desktop application for open models";
        host = "bionic-installers.lmstudio.ai";
        product = "Bionic";
        lms = null;
      };
    }
    .${channel};
  inherit (app) pname;
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
    url = "https://${app.host}/linux/${upstreamArch}/${version}/${app.product}-${version}-${upstreamArch}.AppImage";
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

  # The bundled ROCm runtime dlopens libnuma, libdrm, libelf, libz and libzstd from the system.
  runtimePkgs = pkgs: [
    pkgs.ocl-icd
    pkgs.vulkan-loader
    pkgs.numactl
    pkgs.libdrm
    pkgs.elfutils
    pkgs.zlib
    pkgs.zstd
  ];

  lmsPristine = "${appimageContents}/${app.lms}";

  # lms locates its bundled program by reading its own file, so it runs byte-pristine inside an FHS environment instead of being patched.
  lms = buildFHSEnv {
    name = "lms";
    targetPkgs = runtimePkgs;
    runScript = lmsPristine;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [
    graphicsmagick
    makeWrapper
  ];

  extraPkgs = runtimePkgs;

  extraInstallCommands = ''
    mapfile -t desktopFiles < <(find ${appimageContents} -type f -name '*.desktop')
    if [ "''${#desktopFiles[@]}" -eq 0 ]; then
      echo "${pname}: the extracted AppImage holds no .desktop file" >&2
      exit 1
    fi
    for f in "''${desktopFiles[@]}"; do
      if ! cmp -s "''${desktopFiles[0]}" "$f"; then
        echo "${pname}: the extracted AppImage holds differing .desktop files, cannot choose:" >&2
        printf '  %s\n' "''${desktopFiles[@]}" >&2
        exit 1
      fi
    done

    # The desktop file's basename must equal the Electron Wayland app_id, the Name= field, for KWin and GNOME to find the window icon.
    appName=$(sed -n 's/^Name=//p' "''${desktopFiles[0]}")
    if [ "$(printf '%s' "$appName" | wc -l)" -ne 0 ] || ! [[ "$appName" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo "${pname}: expected exactly one Name= line naming a plain app_id in ''${desktopFiles[0]}, got: ''${appName:-none}" >&2
      exit 1
    fi
    desktop=$out/share/applications/$appName.desktop
    install -Dm444 "''${desktopFiles[0]}" "$desktop"

    sed -i 's|^Exec=.*|Exec=${pname}|' "$desktop"
    if ! grep -qx 'Exec=${pname}' "$desktop"; then
      echo "${pname}: $desktop carries no Exec line to point at the wrapper" >&2
      exit 1
    fi

    iconName=$(sed -n 's/^Icon=//p' "$desktop")
    if [ "$(printf '%s' "$iconName" | wc -l)" -ne 0 ] || [ -z "$iconName" ]; then
      echo "${pname}: expected exactly one Icon= line in $desktop, got: ''${iconName:-none}" >&2
      exit 1
    fi

    mapfile -t iconFiles < <(find ${appimageContents} -type f -name "$iconName.png")
    if [ "''${#iconFiles[@]}" -eq 0 ]; then
      echo "${pname}: $desktop declares Icon=$iconName but the extracted AppImage has no $iconName.png" >&2
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
  ''
  + lib.optionalString (app.lms != null) ''
    if [ ! -f ${lmsPristine} ]; then
      echo "${pname}: the extracted AppImage holds no lms CLI at ${app.lms}" >&2
      exit 1
    fi
    ln -s ${lms}/bin/lms $out/bin/lms
    wrapProgram $out/bin/lms ${lib.escapeShellArgs wrapperArgs}
  '';

  meta = {
    inherit (app) description;
    homepage = "https://lmstudio.ai/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = pname;
  };
}
