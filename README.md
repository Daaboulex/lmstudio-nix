# lmstudio-nix

[LM Studio](https://lmstudio.ai/) for NixOS: the desktop app,
[LM Studio Bionic](https://lmstudio.ai/bionic) (the agent desktop app) and the
headless server with its `lms` CLI. It is for running local LLM inference on
x86-64 and arm64 Linux.

Every package builds on `x86_64-linux` and `aarch64-linux`, and CI builds both
on native runners. The automated checks stop at building the packages,
evaluating the two modules and starting the server binaries. No check loads a
model or uses a GPU.

## What you get

- `lmstudio` is the desktop app on the stable channel.
- `lmstudio-beta` is the desktop app on the beta channel.
- `lmstudio-bionic` is LM Studio Bionic.
- `lmstudio-server` is the headless `llmster` daemon and the `lms` CLI, for
  model management and OpenAI-compatible API serving.

## Install

Add the flake:

```nix
{
  inputs.lmstudio = {
    url = "github:Daaboulex/lmstudio-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then add the overlay, which provides all four packages under `pkgs`, and
install one. LM Studio is unfree.

```nix
{ pkgs, inputs, ... }:
{
  nixpkgs.overlays = [ inputs.lmstudio.overlays.default ];
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [ pkgs.lmstudio ];
}
```

Without the overlay, the same package needs no unfree setting:
`inputs.lmstudio.packages.${pkgs.stdenv.hostPlatform.system}.lmstudio`.

## Use

To try a package without installing it:

```bash
nix run 'github:Daaboulex/lmstudio-nix'
nix run 'github:Daaboulex/lmstudio-nix#lmstudio-server'
```

The first opens the stable app. The second runs the server CLI, `lms`. Use
`#lmstudio-beta` or `#lmstudio-bionic` for the beta app or Bionic.

Two modules build on the packages. Both default to the overlay packages, so the
configuration that imports them needs the overlay and the unfree setting.

The NixOS module runs the server as a system daemon, for a multi-user machine
or a server. It creates an `lmstudio` user and group and a systemd service.

```nix
{
  imports = [ inputs.lmstudio.nixosModules.default ];
  services.lmstudio.enable = true;
}
```

The Home Manager module installs the desktop app for one user.

```nix
{
  imports = [ inputs.lmstudio.homeModules.default ];
  programs.lmstudio.enable = true;
}
```

## Options you are likely to set

| Option | What it is for |
|---|---|
| `services.lmstudio.port` | The API port, 1234 by default |
| `services.lmstudio.host` | The address the API binds to, `127.0.0.1` by default; `0.0.0.0` serves the network |
| `services.lmstudio.openFirewall` | Open the firewall for the API port; needs a `host` other than loopback |
| `services.lmstudio.dataDir` | The daemon's home, `/var/lib/lmstudio` by default; models and engines live under it |
| `programs.lmstudio.package` | Set to `pkgs.lmstudio-beta` for the beta channel |
| `programs.lmstudio.home` | Where models, engines and settings live, `$XDG_DATA_HOME/lmstudio` by default |
| `programs.lmstudio.bionic.enable` | Install Bionic as well |
| `programs.lmstudio.server.enable` | Run the daemon as a user service; `server.port` sets its port, 1234 by default, and `server.autostart` starts it on login |

Every option, with its type and default: [docs/OPTIONS.md](docs/OPTIONS.md).

## GPU

LM Studio downloads its own llama.cpp engines. The packages supply the
libraries and the GPU driver path those engines need to find your GPU.

After the first start, go to Settings > Runtime, download the engine for your
GPU and select it as the active GGUF runtime. That is CUDA for NVIDIA, ROCm for
AMD on x86-64, or Vulkan as the cross-vendor fallback on x86-64. The "Update"
and "Download" buttons there are the app managing its own engines, which is
normal and not a packaging issue.

## Known limits

- The arm64 packages carry no ROCm libraries.
- The server is upstream's generic `full` bundle. The `full+cuda12` variant
  upstream's installer picks on newer NVIDIA drivers is not packaged.
- The Vulkan engine hides the integrated GPU when a discrete GPU is present,
  and it shows "No live GPU info available" for AMD. Prefer the ROCm engine to
  use an AMD integrated GPU.
- The Home Manager module sets `home` only when no LM Studio home exists yet.
  A legacy home gets a warning naming the directory to move.
- Run `lms server start` by hand only when `llmster` or the app is already up.

## When something does not work

To make the Vulkan engine use one particular GPU, name it for that launch. The
trailing `!` is required.

```bash
MESA_VK_DEVICE_SELECT=<vendor:device>! lmstudio
```

## More

- [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md): architectures and GPU setup
- [docs/DESIGN.md](docs/DESIGN.md): unpatched binaries, state, the daemon
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): building, checks, daily updates

## License

- Nix packaging: Licensed under the [MIT License](LICENSE).
- LM Studio software: Proprietary. This repository does **not** distribute the LM Studio binary -- it only provides instructions to fetch and package it. Your use of LM Studio is subject to the [license terms](https://lmstudio.ai/terms) of LM Studio.
- Unfree: the flake's own outputs (`nix run`, `nix build`, `inputs.lmstudio.packages`) need no setting, because the flake allows unfree for them. The overlay packages, which both modules use by default, require `nixpkgs.config.allowUnfree = true` in your Nix configuration.
