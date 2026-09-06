# lmstudio-nix

<!-- BEGIN generated:badges -->
[![CI](https://github.com/Daaboulex/lmstudio-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/lmstudio-nix/actions/workflows/ci.yml)
[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
<!-- END generated:badges -->

A Nix flake for [LM Studio](https://lmstudio.ai/) on NixOS: the desktop app and the headless server with its `lms` CLI, for local LLM inference on x86-64 and arm64 Linux.

<!-- BEGIN generated:upstream -->
## Upstream

| | |
|---|---|
| **Project** | [Upstream](https://lmstudio.ai) |
| **License** | Proprietary |
| **Tracked** | Custom update script |

<!-- END generated:upstream -->

## What Is This?

A Nix flake that wraps LM Studio's stable and beta desktop builds and the headless server into NixOS packages, with the automation to keep them current:

- **Two architectures**: every package builds on `x86_64-linux` and `aarch64-linux` from the AppImage or tarball upstream publishes for that architecture, and CI proves both on native runners.
- **Daily upstream check** at 06:00 UTC over three channels (stable, beta, server) and both architectures; a pin that moved is committed to `main`.
- **Pre-publish verification**: every system evaluates, every package builds for the runner's architecture, the desktop file is present, and the built `lms` and `llmster` run offline and report the pinned version, all green before the push.
- **GPU runtime injection**: the desktop app runs in an FHS environment carrying Vulkan, OpenCL and the libraries LM Studio's bundled ROCm runtime dlopens, with the host's GPU driver on the library path; ROCm 6 libraries are added on x86-64, the one architecture upstream ships a ROCm engine for.
- **Two integration paths**: the system-level `services.lmstudio` daemon (multi-user or server) or the user-level `programs.lmstudio` Home Manager module (desktop with an optional user daemon).
- **Stable and beta channels**: `pkgs.lmstudio` and `pkgs.lmstudio-beta` through the overlay.

## Features

- **Desktop App** (`lmstudio`): AppImage-based GUI with Wayland support, GPU driver injection, and desktop integration (icons, `.desktop` file).
- **Beta Channel** (`lmstudio-beta`): tracks the LM Studio beta release channel.
- **Server/CLI** (`lmstudio-server`): headless `llmster` daemon and `lms` CLI for model management and OpenAI-compatible API serving.
- **GPU Acceleration**: CUDA (NVIDIA) and Vulkan on both architectures, ROCm (AMD) on x86-64; the GPU driver is injected automatically.
- **NixOS Module**: system-level `lmstudio` daemon with systemd service, firewall, and dedicated user.
- **Home Manager Module**: user-level desktop app installation with channel selection (stable/beta) and an optional user daemon with autostart.
- **Automated Updates**: daily tracking of every channel on both architectures, hash extraction, build verification, and a silent push to main.

## Architectures

Each channel is pinned per architecture in `sources.json`, because upstream publishes one artifact per architecture and may move them independently. The package for a system reads its own pin:

| | `x86_64-linux` | `aarch64-linux` |
|---|---|---|
| Desktop artifact | `LM-Studio-<version>-x64.AppImage` | `LM-Studio-<version>-arm64.AppImage` |
| Server artifact | `<version>-linux-x64.full.tar.gz` | `<version>-linux-arm64.full.tar.gz` |
| Engines in the desktop bundle (0.4.23-1) | CPU (AVX2), CUDA, Vulkan | CPU, CUDA 13 |
| Engines in the server bundle (0.0.13-1) | CPU (AVX2), CUDA, Vulkan | CPU, CUDA 13 |
| ROCm 6 libraries injected | yes | no (upstream ships no ROCm engine for arm64) |

The x86-64 server bundle is upstream's generic `full` variant. Upstream's installer script picks a `full+cuda12` variant instead on hosts whose NVIDIA driver is 550.54.14 or newer; that variant is not packaged here.

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
  environment.systemPackages = [ inputs.lmstudio.packages.${pkgs.system}.default ];
}
```

<!-- END generated:installation -->

## Usage

### Run directly

```bash
# Desktop GUI (stable)
NIXPKGS_ALLOW_UNFREE=1 nix run 'github:Daaboulex/lmstudio-nix' --impure

# Desktop GUI (beta)
NIXPKGS_ALLOW_UNFREE=1 nix run 'github:Daaboulex/lmstudio-nix#lmstudio-beta' --impure

# Server CLI
NIXPKGS_ALLOW_UNFREE=1 nix run 'github:Daaboulex/lmstudio-nix#lmstudio-server' --impure
```

### Add to a NixOS flake

1. Add the input:

   ```nix
   inputs.lmstudio.url = "github:Daaboulex/lmstudio-nix";
   ```

2. Use the overlay or add the package directly:

   ```nix
   # Via overlay (recommended: makes pkgs.lmstudio, pkgs.lmstudio-beta,
   # and pkgs.lmstudio-server available)
   nixpkgs.overlays = [ inputs.lmstudio.overlays.default ];
   environment.systemPackages = [ pkgs.lmstudio ];

   # Or directly
   environment.systemPackages = [
     inputs.lmstudio.packages.${pkgs.system}.lmstudio
   ];
   ```

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

Upstream ships no ROCm engine for arm64, so the arm64 packages carry no ROCm libraries.

### NVIDIA GPUs (CUDA)

CUDA's driver library is loaded at runtime from the NVIDIA driver. The server package ignores the missing `libcuda.so.1` during build since the driver provides it at runtime. After launching:

1. Go to **Settings > Runtime**
2. Download the **CUDA llama.cpp** engine
3. Select it as the active GGUF runtime

On arm64 the bundled engine is the **CUDA 13** build upstream made for NVIDIA's arm64 platforms (DGX Spark and similar).

### Vulkan

Vulkan support is included via `vulkan-loader`. The **Vulkan llama.cpp** engine is the cross-vendor fallback on x86-64; upstream ships no Vulkan engine in its arm64 bundles as of 0.4.23-1.

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
  openFirewall = false;  # Open firewall for API port
  dataDir = "/var/lib/lmstudio";  # Model storage directory
};
```

This creates a dedicated `lmstudio` user/group, a systemd service, and optionally opens the firewall port.

## Home Manager Module

The Home Manager module provides user-level integration:

```nix
# Desktop app only (stable channel)
programs.lmstudio.enable = true;

# Desktop app (beta channel) + user daemon
programs.lmstudio = {
  enable = true;
  package = pkgs.lmstudio-beta;  # Use beta channel
  server = {
    enable = true;
    port = 1234;
    autostart = false;  # Start on login
  };
};
```

The user daemon runs as a systemd user service. Enable `autostart` to have it start automatically on login.

## Automation & CI

Three GitHub Actions workflows keep the package up to date and verified:

### Upstream Update (`update.yml`)

Runs **daily at 06:00 UTC** (and on manual dispatch):

1. Resolves the latest stable and beta desktop version per architecture from the `lmstudio.ai` download redirect, and the latest server version from the `APP_VERSION` upstream's own installer script pins
2. Prefetches every artifact whose pin moved and, for the server, checks the download against the `.sha512` upstream publishes next to it
3. Writes the new pins to `sources.json`
4. Runs the verification chain: eval of every system, a build of every package for the runner's architecture, the desktop file, and an offline `lms version` and `llmster version` of the built server
5. On success: silent push to main. On failure: creates a GitHub Issue with the log and a recovery branch

### Build CI (`ci.yml`)

Runs on every push and PR: an AI-artifact guard, then builds every output the
flake declares (stable/beta desktop + server packages, plus the standard's
lint/conformance/schema and both module-eval checks) via `nix-fast-build`, once
on an x86-64 runner and once on an arm64 runner.

### Maintenance (`maintenance.yml`)

Runs **weekly on Sunday at 04:00 UTC**:

- Updates `flake.lock` and test-builds before pushing
- Cleans up stale `update/*` branches older than 30 days

### Supply Chain Security

- All GitHub Actions are **pinned to commit SHAs** (not mutable tags)
- SRI hashes (`sha256-...`) used everywhere

## Development

```bash
nix develop                        # Enter dev shell (installs git hooks)
nix build                          # Build desktop (stable, default)
nix build .#lmstudio-beta          # Build desktop (beta)
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
- **Unfree**: Requires `nixpkgs.config.allowUnfree = true` in your Nix configuration.

<!-- BEGIN generated:footer -->
<!-- END generated:footer -->
