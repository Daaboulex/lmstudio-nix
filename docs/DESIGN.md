# Design

Why the packages and the two modules are built the way they are.

## Vendor binaries run as shipped

`lms` is a standalone JavaScript runtime binary that locates its bundled
program by reading its own executable file. Rewriting its ELF interpreter or
rpath moves that payload and the binary fails at start ("Could not find
standalone binary section", or a segfault).

So nothing in the AppImage or the server tarball is patched. The server bundle
is installed with fixup disabled, and its build compares `lms` and `llmster`
byte for byte against the tarball. Every entry point (`lmstudio`,
`lmstudio-bionic`, `lms`, `llmster`) runs inside an FHS environment whose own
loader starts the pristine binary.

The environment carries Vulkan (`vulkan-loader`), OpenCL (`ocl-icd`) and the
libraries LM Studio's bundled ROCm runtime dlopens (`numactl`, `libdrm`,
`elfutils`, `zlib`, `zstd`). The host's GPU driver is on the library path. So
the llama.cpp engines LM Studio downloads later find the FHS layout they were
built for.

On x86-64 the desktop and Bionic packages also put ROCm 6 libraries on the
library path and set `HSA_ENABLE_SDMA=0`. Those libraries come from a second
nixpkgs input, `nixpkgs-rocm6`, which is dropped once LM Studio ships a ROCm 7
engine. The x86-64 server environment also carries `libxcrypt-legacy`.

Bionic is the agent desktop app on the same runtime, and it is packaged the
same way. The `lmstudio` and `lmstudio-beta` packages install the `lms` their
AppImage carries next to the app. The Bionic package installs no `lms`.

## Desktop integration

Each desktop package installs the `.desktop` file and the icon it finds in the
AppImage, the icon resized to six sizes. The desktop file is named after its
own `Name=` field, because that is the Wayland app_id KWin and GNOME use to
find the window icon. A build fails when the AppImage holds no desktop file, no
icon, or desktop files that differ.

The launcher adds the Wayland flags only when both `NIXOS_OZONE_WL` and
`WAYLAND_DISPLAY` are set.

The Home Manager module also links the icons into the user's icon theme
directories. Electron implements no xdg_toplevel_icon, so KWin resolves a
Wayland window's icon from there.

## Two ways to integrate

The NixOS module, `services.lmstudio`, runs LM Studio as a system-level daemon
for multi-user or server deployments. It creates a dedicated `lmstudio` user
and group and a systemd service, and optionally opens the firewall port. It
refuses `openFirewall` together with a loopback `host`.

The Home Manager module, `programs.lmstudio`, is the user-level path. It
installs the desktop app and Bionic, with the channel chosen through `package`
(stable or beta), sets the LM Studio home directory and offers an optional user
daemon with autostart.

## Where LM Studio keeps its state

LM Studio, Bionic, `lms` and `llmster` share one home directory for models,
engines and settings. Upstream decides it in `findLMStudioHome` (lmstudio-js,
`packages/lms-common-server/src/findLMStudioHome.ts`):

1. the content of `~/.lmstudio-home-pointer` when that file exists,
2. else a legacy `~/.cache/lm-studio` when that directory exists,
3. else `~/.lmstudio`.

In the last two cases the app writes the pointer itself. No environment
variable and no XDG variable is read.

The Home Manager module therefore seeds the pointer with
`programs.lmstudio.home` (default: `$XDG_DATA_HOME/lmstudio`) at activation,
only when the pointer, `~/.cache/lm-studio` and `~/.lmstudio` are all absent.
When the pointer is absent and one of those two directories exists, it prints a
warning naming the directory to move and does not seed. It never changes an
existing pointer.

The same activation step looks at `settings.json` in that home, for the app and
for Bionic. When `downloadsFolder` there still points into `~/.lmstudio` or
`~/.cache/lm-studio`, it rewrites it to the `models` directory of the home.
While LM Studio is running it only prints a warning, which asks you to quit the
app and activate again.

The NixOS daemon runs with `dataDir` as its `HOME`, so its state lives under
it, `/var/lib/lmstudio` by default. The module creates that directory through
systemd-tmpfiles, owned by the `lmstudio` user and group, wherever `dataDir`
points.

## How the daemon runs

Both modules run the same unit ([`service.nix`](../service.nix)). The service's
main process is `llmster` itself, which stays in the foreground, so systemd
supervises the daemon and restarts it if it fails. Once `lms daemon status`
reports it running, `lms server start` attaches the API server to it on the
configured port. Stopping the service runs `lms daemon down`.

The unit does not start the server with `lms server start` alone. That command
expects a daemon to be running already, and without one it wakes the install it
last recorded in the LM Studio home. With the desktop app in the same home that
is the desktop app, which cannot start inside a service with no display. Run
`lms server start` by hand only when `llmster` or the app is already up.

The user daemon runs as a systemd user service in the user's LM Studio home, so
the desktop app and the daemon share models, engines and settings. It is given
a port and no bind address. The system daemon is also given `host` as its bind
address.
