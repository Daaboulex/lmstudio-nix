# lmstudio-nix

<!-- BEGIN generated:badges -->
[![CI](https://github.com/Daaboulex/lmstudio-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/lmstudio-nix/actions/workflows/ci.yml)
[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
<!-- END generated:badges -->

A Nix flake for [LM Studio](https://lmstudio.ai/) on NixOS: the desktop app, [LM Studio Bionic](https://lmstudio.ai/bionic) (the agent desktop app), and the headless server with its `lms` CLI, for local LLM inference on x86-64 and arm64 Linux.

<!-- BEGIN generated:upstream -->
## Upstream

| | |
|---|---|
| **Project** | [Upstream](https://lmstudio.ai) |
| **License** | Proprietary |
| **Tracked** | Custom update script |

<!-- END generated:upstream -->

## What Is This?

A Nix flake that wraps LM Studio's stable and beta desktop builds, LM Studio Bionic, and the headless server into NixOS packages, with the automation to keep them current:

- **Two architectures**: every package builds on `x86_64-linux` and `aarch64-linux` from the AppImage or tarball upstream publishes for that architecture, and CI proves both on native runners.
- **Daily upstream check** at 06:00 UTC over four channels (stable, beta, bionic, server) and both architectures; a pin that moved is committed to `main`.
- **Pre-publish verification**: every system evaluates, every package builds for the runner's architecture, the desktop files are present, and the built `lms` runs and the built `llmster` reports the pinned version offline, all green before the push.
- **Vendor binaries run as shipped**: the AppImage contents and the server bundle stay byte-identical to upstream's and run inside an FHS environment carrying Vulkan, OpenCL and the libraries LM Studio's bundled ROCm runtime dlopens, with the host's GPU driver on the library path; ROCm 6 libraries are added to the desktop and Bionic packages on x86-64.
- **Two integration paths**: the system-level `services.lmstudio` daemon (multi-user or server) or the user-level `programs.lmstudio` Home Manager module (desktop apps, the LM Studio home directory, and an optional user daemon).
- **Stable, beta and Bionic**: `pkgs.lmstudio`, `pkgs.lmstudio-beta` and `pkgs.lmstudio-bionic` through the overlay.

## Features

- **Desktop App** (`lmstudio`): AppImage-based GUI with Wayland support, GPU driver injection, and desktop integration (icons, `.desktop` file).
- **Beta Channel** (`lmstudio-beta`): tracks the LM Studio beta release channel.
- **Bionic** (`lmstudio-bionic`): LM Studio Bionic, the agent desktop app on the same runtime, packaged the same way.
- **Server/CLI** (`lmstudio-server`): headless `llmster` daemon and `lms` CLI for model management and OpenAI-compatible API serving.
- **GPU Acceleration**: CUDA (NVIDIA) on both architectures, Vulkan and ROCm (AMD) on x86-64; the GPU driver is injected automatically.
- **NixOS Module**: system-level `lmstudio` daemon with systemd service, firewall, and dedicated user.
- **Home Manager Module**: user-level installation of LM Studio and Bionic with channel selection (stable/beta), the LM Studio home directory, and an optional user daemon with autostart.
- **Automated Updates**: daily tracking of every channel on both architectures, hash extraction, build verification, and a silent push to main.

## Architectures

Each channel is pinned per architecture in [`sources.json`](./sources.json), because upstream publishes one artifact per architecture and may move them independently. The package for a system reads its own pin:

| | `x86_64-linux` | `aarch64-linux` |
|---|---|---|
| Desktop artifact | `LM-Studio-<version>-x64.AppImage` | `LM-Studio-<version>-arm64.AppImage` |
| Bionic artifact | `Bionic-<version>-x64.AppImage` | `Bionic-<version>-arm64.AppImage` |
| Server artifact | `<version>-linux-x64.full.tar.gz` | `<version>-linux-arm64.full.tar.gz` |
| ROCm 6 libraries injected into the desktop and Bionic packages | yes | no |

The x86-64 server bundle is upstream's generic `full` variant. Upstream's installer script picks a `full+cuda12` variant instead on hosts whose NVIDIA driver is 550.54.14 or newer; that variant is not packaged here.

## Vendor binaries stay pristine

`lms` is a standalone JavaScript runtime binary that locates its bundled program by reading its own executable file. Rewriting its ELF interpreter or rpath moves that payload and the binary fails at start ("Could not find standalone binary section", or a segfault). So nothing in the AppImage or the server tarball is patched: the server bundle is installed with fixup disabled and checked byte-identical to the tarball, and every entry point (`lmstudio`, `lmstudio-bionic`, `lms`, `llmster`) runs inside an FHS environment whose own loader starts the pristine binary. The environment carries the runtime libraries listed above, so the llama.cpp engines LM Studio downloads later find the FHS layout they were built for.

<!-- BEGIN generated:installation -->
## Installation

Add as a flake input:

```nix
{
  inputs.lmstudio = {
    url = "github:Daaboulex/lmstudio-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then use the package:

```nix
{ pkgs, inputs, ... }:
{
  environment.systemPackages = [ inputs.lmstudio.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
```

<!-- END generated:installation -->

## Usage

### Run directly

```bash
# Desktop GUI (stable)
nix run 'github:Daaboulex/lmstudio-nix'

# Desktop GUI (beta)
nix run 'github:Daaboulex/lmstudio-nix#lmstudio-beta'

# LM Studio Bionic
nix run 'github:Daaboulex/lmstudio-nix#lmstudio-bionic'

# Server CLI
nix run 'github:Daaboulex/lmstudio-nix#lmstudio-server'
```

### Add to a NixOS flake

1. Add the input:

   ```nix
   inputs.lmstudio.url = "github:Daaboulex/lmstudio-nix";
   ```

2. Use the overlay or add the package directly:

   ```nix
   # Via overlay (recommended: makes pkgs.lmstudio, pkgs.lmstudio-beta,
   # pkgs.lmstudio-bionic and pkgs.lmstudio-server available)
   nixpkgs.overlays = [ inputs.lmstudio.overlays.default ];
   environment.systemPackages = [ pkgs.lmstudio ];

   # Or directly
   environment.systemPackages = [
     inputs.lmstudio.packages.${pkgs.stdenv.hostPlatform.system}.lmstudio
   ];
   ```

## Where LM Studio keeps its state

LM Studio, Bionic, `lms` and `llmster` share one home directory for models, engines and settings. Upstream decides it in `findLMStudioHome` (lmstudio-js, `packages/lms-common-server/src/findLMStudioHome.ts`): the content of `~/.lmstudio-home-pointer` when that file exists, else a legacy `~/.cache/lm-studio` when that directory exists, else `~/.lmstudio`; in the last two cases the app writes the pointer itself. No environment variable and no XDG variable is read.

The Home Manager module therefore seeds the pointer with `programs.lmstudio.home` (default: `$XDG_DATA_HOME/lmstudio`) at activation, only when the pointer, `~/.cache/lm-studio` and `~/.lmstudio` are all absent. When the pointer is absent and one of those two directories exists, it prints a warning naming the directory to move and does not seed. It never changes an existing pointer. The NixOS daemon runs with `dataDir` as its `HOME`, so its state lives under `/var/lib/lmstudio`.

## GPU Setup

LM Studio manages its own inference backends (llama.cpp engines) internally in its home directory. The package provides the GPU runtime libraries so these backends can detect and use your GPU.

### AMD GPUs (ROCm, x86-64 only)

ROCm 6 runtime libraries are bundled in the x86-64 desktop package. After launching LM Studio:

1. Go to **Settings > Runtime**
2. Download the **ROCm llama.cpp** engine
3. Select it as the active GGUF runtime

For full ROCm support, also add the ROCm ICD to your NixOS configuration:

```nix
hardware.graphics.extraPackages = with pkgs; [
  rocmPackages.clr.icd
];
```

The arm64 packages carry no ROCm libraries.

### NVIDIA GPUs (CUDA)

CUDA's driver library is loaded at runtime from the NVIDIA driver through the driver path on the library path. After launching:

1. Go to **Settings > Runtime**
2. Download the **CUDA llama.cpp** engine
3. Select it as the active GGUF runtime

### Vulkan

Vulkan support is included via `vulkan-loader`. The **Vulkan llama.cpp** engine is the cross-vendor fallback on x86-64.

### Runtime Engines

LM Studio downloads and manages its own llama.cpp inference engines in its home directory. These include CPU-only, Vulkan, CUDA, and ROCm variants where upstream builds them for the architecture. The "Update" and "Download" buttons in **Settings > Runtime** are the app managing its own backends; this is normal, not a packaging issue.

### GPU Detection Notes

The package provides the system libraries LM Studio's bundled ROCm runtime dlopens
(`numactl`, `libdrm`, `elfutils`, `zlib`, `zstd`), so the **ROCm** engine loads and
enumerates AMD GPUs, including integrated Radeon graphics, with their VRAM.

- **The Vulkan engine hides the integrated GPU when a discrete GPU is present** (an
  upstream ggml-vulkan behavior). Prefer the **ROCm** engine to use an AMD iGPU; or,
  for Vulkan, force one device per launch with
  `MESA_VK_DEVICE_SELECT=<vendor:device>! lmstudio` (the trailing `!` is required and
  overrides any system-wide `MESA_VK_DEVICE_SELECT`).
- **Live GPU-memory readout** depends on the active engine: the ROCm engine reports
  AMD VRAM; the Vulkan engine reads it via NVML (NVIDIA-only) and shows "No live GPU
  info available" for AMD. Use `amdgpu_top`/`rocm-smi` for live AMD VRAM on Vulkan.

## NixOS Module

The NixOS module runs LM Studio as a system-level daemon (for multi-user or server deployments):

```nix
services.lmstudio = {
  enable = true;
  port = 1234;          # API port (default: 1234)
  host = "127.0.0.1";   # Address the API binds to; 0.0.0.0 serves the network
  openFirewall = false;  # Open firewall for API port; needs a host other than loopback
  dataDir = "/var/lib/lmstudio";  # The daemon's home; models and engines live under it
};
```

This creates a dedicated `lmstudio` user/group, a systemd service, and optionally opens the firewall port.

## How the daemon runs

Both modules run the same unit ([`service.nix`](./service.nix)). The service's main process is `llmster` itself, which stays in the foreground, so systemd supervises the daemon and restarts it if it fails. Once `lms daemon status` reports it running, `lms server start` attaches the API server to it on the configured port; stopping the service runs `lms daemon down`.

The unit does not start the server with `lms server start` alone: that command expects a daemon to be running already, and without one it wakes the install it last recorded in the LM Studio home. With the desktop app in the same home that is the desktop app, which cannot start inside a service with no display. Run `lms server start` by hand only when `llmster` or the app is already up.

## Home Manager Module

The Home Manager module provides user-level integration:

```nix
# Desktop app only (stable channel)
programs.lmstudio.enable = true;

# Desktop app (beta channel), Bionic, an explicit home, and the user daemon
programs.lmstudio = {
  enable = true;
  package = pkgs.lmstudio-beta;  # Use beta channel
  home = "/data/lmstudio";       # Default: $XDG_DATA_HOME/lmstudio
  bionic.enable = true;
  server = {
    enable = true;
    port = 1234;
    autostart = false;  # Start on login
  };
};
```

The user daemon runs as a systemd user service in the user's LM Studio home, so the desktop app and the daemon share models, engines and settings. Enable `autostart` to have it start automatically on login.

## Updates

[`update.yml`](./.github/workflows/update.yml) runs daily at 06:00 UTC and on manual dispatch:

1. Resolves the latest stable, beta and Bionic version per architecture from the `lmstudio.ai` download redirects, and the latest server version from the `APP_VERSION` upstream's own installer script pins
2. Prefetches every artifact whose pin moved and, for the server, checks the download against the `.sha512` upstream publishes next to it
3. Writes the new pins to [`sources.json`](./sources.json)
4. Runs the verification chain: eval of every system, a build of every package for the runner's architecture, the desktop files, and an offline `lms version` and `llmster version` of the built server
5. On success: silent push to main. On failure: creates a GitHub Issue with the log and a recovery branch

## Development

```bash
nix develop                        # Enter dev shell (installs git hooks)
nix build                          # Build desktop (stable, default)
nix build .#lmstudio-beta          # Build desktop (beta)
nix build .#lmstudio-bionic        # Build LM Studio Bionic
nix build .#lmstudio-server        # Build server
nix run                            # Run desktop
nix run .#lmstudio-server -- --help  # Run server CLI
nix fmt                            # Format code
nix flake check                    # Run all checks for this system
scripts/update.sh                  # Pull the latest upstream pins and verify them
```

## License

- **Nix packaging**: Licensed under the [MIT License](LICENSE).
- **LM Studio software**: Proprietary. This repository does **not** distribute the LM Studio binary -- it only provides instructions to fetch and package it. Your use of LM Studio is subject to the [license terms](https://lmstudio.ai/terms) of LM Studio.
- **Unfree**: the flake's own outputs (`nix run`, `nix build`, `inputs.lmstudio.packages`) need no setting, because the flake allows unfree for them. The overlay packages, which both modules use by default, require `nixpkgs.config.allowUnfree = true` in your Nix configuration.

<!-- BEGIN generated:footer -->
<!-- END generated:footer -->
