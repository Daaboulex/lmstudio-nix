# lmstudio-nix

[![CI](https://github.com/Daaboulex/lmstudio-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/lmstudio-nix/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/Daaboulex/lmstudio-nix)](./LICENSE)
[![NixOS](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![Last commit](https://img.shields.io/github/last-commit/Daaboulex/lmstudio-nix)](https://github.com/Daaboulex/lmstudio-nix/commits)
[![Stars](https://img.shields.io/github/stars/Daaboulex/lmstudio-nix?style=flat)](https://github.com/Daaboulex/lmstudio-nix/stargazers)
[![Issues](https://img.shields.io/github/issues/Daaboulex/lmstudio-nix)](https://github.com/Daaboulex/lmstudio-nix/issues)

A Nix flake for [LM Studio](https://lmstudio.ai/) on NixOS — local LLM inference with both a desktop GUI and headless server/CLI.

## Upstream

This is a **Nix packaging wrapper** — not the original program. LM Studio is **proprietary, unfree** software:

- **Project**: [LM Studio](https://lmstudio.ai/)
- **Vendor**: LM Studio
- **License**: Proprietary; AppImage / server binaries fetched from `lmstudio.ai` at install time. This repo does **not** redistribute LM Studio — it only generates the fetch + wrap pipeline.
- **Requires**: `nixpkgs.config.allowUnfree = true`

Your use of LM Studio is subject to the [license terms](https://lmstudio.ai/terms) of LM Studio.

## What Is This?

A Nix flake that wraps LM Studio's stable + beta + server binaries into NixOS-portable packages with full CI infrastructure:

- **Daily upstream check** at 06:00 UTC tracking three channels (stable, beta, server) — auto-PR on hash change
- **Pre-publish verification** — eval + desktop build + `.desktop` check + server build + ldd check, all green before push
- **GPU runtime injection** — bundles ROCm + CUDA + Vulkan + OpenCL libs so LM Studio's bundled llama.cpp engines can detect any GPU
- **Two integration paths** — system-level `services.lmstudio` (multi-user / server) or user-level `programs.lmstudio` HM module (desktop with optional autostart user daemon)
- **Stable + Beta channels** — both shipped as `pkgs.lmstudio` and `pkgs.lmstudio-beta` via the overlay

## Features

- **Desktop App** (`lmstudio`): AppImage-based GUI with Wayland support, GPU driver injection, and desktop integration (icons, `.desktop` file).
- **Beta Channel** (`lmstudio-beta`): Track the LM Studio beta release channel for early access features.
- **Server/CLI** (`lmstudio-server`): Headless `llmster` daemon and `lms` CLI for model management and OpenAI-compatible API serving.
- **GPU Acceleration**: ROCm (AMD), CUDA (NVIDIA), Vulkan, and OpenCL support bundled — GPU drivers injected automatically.
- **NixOS Module**: System-level `lmstudio` daemon with systemd service, firewall, and dedicated user.
- **Home Manager Module**: User-level desktop app installation with channel selection (stable/beta) and optional user daemon with autostart.
- **Automated Updates**: Daily tracking of both stable and beta upstream versions, hash extraction, build verification, and silent push to main.

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
   # Via overlay (recommended — makes pkgs.lmstudio, pkgs.lmstudio-beta,
   # and pkgs.lmstudio-server available)
   nixpkgs.overlays = [ inputs.lmstudio.overlays.default ];
   environment.systemPackages = [ pkgs.lmstudio ];

   # Or directly
   environment.systemPackages = [
     inputs.lmstudio.packages.${pkgs.system}.lmstudio
   ];
   ```

## GPU Setup

LM Studio manages its own inference backends (llama.cpp engines) internally in `~/.lmstudio/`. The package provides the GPU runtime libraries so these backends can detect and use your GPU.

### AMD GPUs (ROCm)

ROCm runtime libraries are bundled in the desktop package. After launching LM Studio:

1. Go to **Settings > Runtime**
2. Download the **ROCm llama.cpp** engine
3. Select it as the active GGUF runtime

For full ROCm support, also add the ROCm ICD to your NixOS configuration:

```nix
hardware.graphics.extraPackages = with pkgs; [
  rocmPackages.clr.icd
];
```

### NVIDIA GPUs (CUDA)

CUDA libraries are loaded at runtime from the NVIDIA driver. The server package ignores missing `libcuda.so` during build since these are provided by the driver at runtime. After launching:

1. Go to **Settings > Runtime**
2. Download the **CUDA llama.cpp** engine
3. Select it as the active GGUF runtime

### Vulkan (all GPUs)

Vulkan support is included via `vulkan-loader` and works out of the box. The **Vulkan llama.cpp** engine is a good cross-platform fallback that works on both AMD and NVIDIA.

### Runtime Engines

LM Studio downloads and manages its own llama.cpp inference engines in `~/.lmstudio/`. These include CPU-only, Vulkan, CUDA, and ROCm variants. The "Update" and "Download" buttons in **Settings > Runtime** are the app managing its own backends — this is normal, not a packaging issue.

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

### Channel Selection (with wrapper module)

If using the provided `myModules.home.lmstudio` wrapper:

```nix
myModules.home.lmstudio = {
  enable = true;
  channel = "beta";  # "stable" (default) or "beta"
  server.enable = true;
  server.autostart = true;
};
```

## Automation & CI

Three GitHub Actions workflows keep the package up to date and verified:

### Upstream Update (`update.yml`)

Runs **daily at 08:00 UTC** (and on manual dispatch):

1. Checks latest stable version via redirect from `lmstudio.ai`
2. Checks latest beta version via `?channel=beta`
3. Checks latest server version from `llmster.lmstudio.ai`
4. Updates version strings and extracts new SRI hashes
5. Runs full verification chain: eval, desktop build, desktop file check, server build, ldd check
6. On success: silent push to main. On failure: creates GitHub Issue with build log and recovery branch

### Build CI (`ci.yml`)

Runs on **every PR and push to main**:

- `nix flake check --no-build` (evaluation)
- `nix fmt -- --check .` (formatting)
- Builds both `lmstudio` and `lmstudio-server`
- Verifies `.desktop` file exists in desktop package
- Verifies `lms` binary exists and has no missing shared libraries

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
nix flake check                    # Run all checks
```

## License

- **Nix packaging**: Licensed under the [MIT License](LICENSE).
- **LM Studio software**: Proprietary. This repository does **not** distribute the LM Studio binary -- it only provides instructions to fetch and package it. Your use of LM Studio is subject to the [license terms](https://lmstudio.ai/terms) of LM Studio.
- **Unfree**: Requires `nixpkgs.config.allowUnfree = true` in your Nix configuration.