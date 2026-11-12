# Development

Building, the checks and how the pins are kept current.

## Commands

| Command | What it does |
|---|---|
| `nix develop` | Enter the dev shell, which installs the git hooks |
| `nix build` | Build the desktop app, stable channel, the default |
| `nix build .#lmstudio-beta` | Build the desktop app, beta channel |
| `nix build .#lmstudio-bionic` | Build LM Studio Bionic |
| `nix build .#lmstudio-server` | Build the server |
| `nix run` | Run the desktop app |
| `nix run .#lmstudio-server -- --help` | Run the server CLI |
| `nix fmt` | Format the code |
| `nix flake check` | Run all checks for this system |
| `scripts/update.sh` | Pull the latest upstream pins and verify them |

The flake's own nixpkgs input is `nixos-unstable`, and its own packages are
built with unfree allowed.

## Checks

The flake declares two checks of its own. `module-eval-nixos` evaluates the
NixOS module with `services.lmstudio.enable`. `module-eval-hm` evaluates the
Home Manager module with the app, Bionic and the user daemon switched on.

The flake imports the base module of the packaging standard
(`inputs.std.flakeModules.base`), which supplies the dev shell, the formatter
and the git hooks, and adds a check that builds each package.

Every package builds on `x86_64-linux` and `aarch64-linux` from the AppImage or
tarball upstream publishes for that architecture. CI
([`ci.yml`](../.github/workflows/ci.yml)) proves both on native runners.

## Upstream

| | |
|---|---|
| Project | [lmstudio.ai](https://lmstudio.ai) |
| License | Proprietary |
| Tracked | Custom update script, [`scripts/update.sh`](../scripts/update.sh) |

## Updates

[`update.yml`](../.github/workflows/update.yml) runs daily at 06:00 UTC and on
manual dispatch. Daily is the default. The repository variable
`UPDATE_CADENCE` can limit the schedule to the Sunday run.

The check covers four channels (stable, beta, bionic, server) on both
architectures:

1. It resolves the latest stable, beta and Bionic version per architecture
   from the `lmstudio.ai` download redirects, and the latest server version
   from the `APP_VERSION` upstream's own installer script pins.
2. It prefetches every artifact whose pin moved and, for the server, checks the
   download against the `.sha512` upstream publishes next to it.
3. It writes the new pins to [`sources.json`](../sources.json).
4. It runs the verification chain below.
5. On success it pushes to `main` silently. On failure it creates a GitHub
   issue with the log and a recovery branch.

## The verification chain

Everything here is green before a new pin is pushed:

1. Every system evaluates.
2. The full check suite passes for the runner's architecture.
3. Every package builds for the runner's architecture. A desktop package fails
   to build when its AppImage holds no desktop file, so a build also proves
   the desktop files are present.
4. The built `lms` runs `lms version` offline, and the built `llmster` reports
   the pinned version from `llmster version`.
