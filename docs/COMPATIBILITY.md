# Compatibility

What is packaged for each architecture, and how each kind of GPU is reached.

## Architectures

Each channel is pinned per architecture in [`sources.json`](../sources.json),
because upstream publishes one artifact per architecture and may move them
independently. The package for a system reads its own pin.

| | `x86_64-linux` | `aarch64-linux` |
|---|---|---|
| Desktop artifact | `LM-Studio-<version>-x64.AppImage` | `LM-Studio-<version>-arm64.AppImage` |
| Bionic artifact | `Bionic-<version>-x64.AppImage` | `Bionic-<version>-arm64.AppImage` |
| Server artifact | `<version>-linux-x64.full.tar.gz` | `<version>-linux-arm64.full.tar.gz` |
| ROCm 6 libraries injected into the desktop and Bionic packages | yes | no |

The x86-64 server bundle is upstream's generic `full` variant. Upstream's
installer script picks a `full+cuda12` variant instead on hosts whose NVIDIA
driver is 550.54.14 or newer. That variant is not packaged here.

## GPU acceleration

LM Studio manages its own inference backends (llama.cpp engines) internally in
its home directory. The package provides the GPU runtime libraries so these
backends can detect and use your GPU, and the GPU driver is injected
automatically.

| Engine | For | Architectures |
|---|---|---|
| CUDA llama.cpp | NVIDIA | both |
| ROCm llama.cpp | AMD | x86-64 only |
| Vulkan llama.cpp | the cross-vendor fallback | x86-64 |

### AMD GPUs (ROCm, x86-64 only)

ROCm 6 runtime libraries are bundled in the x86-64 desktop package. After
launching LM Studio:

1. Go to Settings > Runtime
2. Download the ROCm llama.cpp engine
3. Select it as the active GGUF runtime

For full ROCm support, also add the ROCm ICD to your NixOS configuration:

```nix
hardware.graphics.extraPackages = with pkgs; [
  rocmPackages.clr.icd
];
```

The arm64 packages carry no ROCm libraries.

### NVIDIA GPUs (CUDA)

CUDA's driver library is loaded at runtime from the NVIDIA driver through the
driver path on the library path. After launching:

1. Go to Settings > Runtime
2. Download the CUDA llama.cpp engine
3. Select it as the active GGUF runtime

### Vulkan

Vulkan support is included via `vulkan-loader`. The Vulkan llama.cpp engine is
the cross-vendor fallback on x86-64.

### Runtime engines

LM Studio downloads and manages its own llama.cpp inference engines in its home
directory. These include CPU-only, Vulkan, CUDA, and ROCm variants where
upstream builds them for the architecture. The "Update" and "Download" buttons
in Settings > Runtime are the app managing its own backends. This is normal,
not a packaging issue.

### GPU detection notes

The package provides the system libraries LM Studio's bundled ROCm runtime
dlopens (`numactl`, `libdrm`, `elfutils`, `zlib`, `zstd`), so the ROCm engine
loads and enumerates AMD GPUs, including integrated Radeon graphics, with their
VRAM.

The Vulkan engine hides the integrated GPU when a discrete GPU is present. This
is an upstream ggml-vulkan behavior. Prefer the ROCm engine to use an AMD
integrated GPU. Or, for Vulkan, force one device per launch:

```bash
MESA_VK_DEVICE_SELECT=<vendor:device>! lmstudio
```

The trailing `!` is required and overrides any system-wide
`MESA_VK_DEVICE_SELECT`.

The live GPU-memory readout depends on the active engine. The ROCm engine
reports AMD VRAM. The Vulkan engine reads it via NVML, which is NVIDIA-only,
and shows "No live GPU info available" for AMD. Use `amdgpu_top` or `rocm-smi`
for live AMD VRAM on Vulkan. Neither command comes with these packages.
