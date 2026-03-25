# lmstudio-nix

A Nix flake for [LM Studio](https://lmstudio.ai/) on NixOS — local LLM inference with both a desktop GUI and headless server/CLI.

## Features

- **Desktop App** (`lmstudio`): AppImage-based GUI with Wayland support, GPU driver injection, and desktop integration (icons, `.desktop` file).
- **Server/CLI** (`lmstudio-server`): Headless `llmster` daemon and `lms` CLI for model management and OpenAI-compatible API serving.
- **GPU Acceleration**: Automatic GPU driver injection via `addDriverRunpath` for CUDA, Vulkan, and OpenCL workloads.
- **Dual Versioning**: Desktop (0.4.x) and server (0.0.x) track independent upstream release schedules.
- **NixOS Module**: System-level `lmstudio` daemon with systemd service, firewall, and dedicated user.
- **Home Manager Module**: User-level desktop app installation and optional user daemon with autostart.
- **Automated Updates**: Daily upstream version detection, hash extraction, build verification, and silent push to main.

## Usage

### Run directly

```bash
# Desktop GUI
NIXPKGS_ALLOW_UNFREE=1 nix run 'github:Daaboulex/lmstudio-nix' --impure

# Server CLI
NIXPKGS_ALLOW_UNFREE=1 nix run 'github:Daaboulex/lmstudio-nix#lmstudio-server' --impure
```

### Add to a NixOS flake

1. Add the input:

   ```nix
   inputs.lmstudio-nix.url = "github:Daaboulex/lmstudio-nix";
   ```

2. Use the overlay or add the package directly:

   ```nix
   # Via overlay (recommended — makes pkgs.lmstudio and pkgs.lmstudio-server available)
   nixpkgs.overlays = [ inputs.lmstudio-nix.overlays.default ];
   environment.systemPackages = [ pkgs.lmstudio ];

   # Or directly
   environment.systemPackages = [
     inputs.lmstudio-nix.packages.${pkgs.system}.lmstudio
   ];
   ```

## GPU Setup

LM Studio uses GPU acceleration for LLM inference. The packages inject GPU driver paths automatically via `addDriverRunpath`, so no manual `LD_LIBRARY_PATH` configuration is needed.

### NVIDIA GPUs

NVIDIA CUDA libraries are loaded at runtime from the driver. The server package ignores missing `libcuda.so` during build (via `autoPatchelfIgnoreMissingDeps`) since these are provided by the NVIDIA driver at runtime.

### AMD GPUs

Vulkan support is included via `vulkan-loader`. OpenCL is available via `ocl-icd`. For full OpenCL support:

```nix
hardware.graphics.extraPackages = [ pkgs.mesa.opencl ];
environment.sessionVariables.RUSTICL_ENABLE = "radeonsi";
```

## NixOS Module

The NixOS module runs LM Studio as a system-level daemon:

```nix
# In your NixOS configuration (after adding the overlay)
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
# Desktop app only
programs.lmstudio.enable = true;

# Desktop app + user daemon
programs.lmstudio = {
  enable = true;
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

Runs **daily at 08:00 UTC** (and on manual dispatch):

1. Checks latest desktop version via redirect URL from `lmstudio.ai`
2. Checks latest server version from `llmster.lmstudio.ai`
3. Updates version strings and extracts new SRI hashes via build failure
4. Runs full verification chain: eval, desktop build, desktop file check, server build, ldd check
5. On success: silent push to main. On failure: creates GitHub Issue with build log and recovery branch

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

Pre-commit hooks are managed via Nix and run automatically on every commit:

```bash
# Enter dev shell (installs git hooks)
nix develop

# Build desktop (default)
nix build

# Build server
nix build .#lmstudio-server

# Run desktop
nix run

# Run server CLI
nix run .#lmstudio-server -- --help

# Format code
nix fmt

# Run all checks
nix flake check
```

## License

- **Nix packaging**: Licensed under the [MIT License](LICENSE).
- **LM Studio software**: Proprietary. This repository does **not** distribute the LM Studio binary -- it only provides instructions to fetch and package it. Your use of LM Studio is subject to the [license terms](https://lmstudio.ai/terms) of LM Studio.
- **Unfree**: Requires `nixpkgs.config.allowUnfree = true` in your Nix configuration.
