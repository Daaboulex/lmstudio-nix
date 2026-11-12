# Options

Every option the modules of this flake declare. This file is generated from the module sources: change a description there, then run `nix run .#std-write-option-reference`.

## Home Manager module

Declared in [hm-module.nix](../hm-module.nix).

### `programs.lmstudio.enable`

Whether to enable LM Studio desktop app.

Type: `boolean`. Default: `false`.

### `programs.lmstudio.package`

The LM Studio desktop package to use.

Type: `package`. Default: `pkgs.lmstudio`.

### `programs.lmstudio.bionic.enable`

Whether to enable LM Studio Bionic, the agent desktop app.

Type: `boolean`. Default: `false`.

### `programs.lmstudio.bionic.package`

The LM Studio Bionic package to use.

Type: `package`. Default: `pkgs.lmstudio-bionic`.

### `programs.lmstudio.home`

Where LM Studio, Bionic, lms and llmster keep models, engines and settings.
Written to the pointer file they all read at start, ~/.lmstudio-home-pointer,
when neither that pointer nor a legacy home (~/.lmstudio or ~/.cache/lm-studio)
exists yet; from then on the apps own the pointer.

Type: `absolute path`. Default: `"${config.xdg.dataHome}/lmstudio"`.

### `programs.lmstudio.server.enable`

Whether to enable the LM Studio user daemon, llmster, serving the API on localhost.

Type: `boolean`. Default: `false`.

### `programs.lmstudio.server.package`

The LM Studio server package to use.

Type: `package`. Default: `pkgs.lmstudio-server`.

### `programs.lmstudio.server.autostart`

Whether to start the LM Studio daemon on login.

Type: `boolean`. Default: `false`.

### `programs.lmstudio.server.port`

Port for the LM Studio API server.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`. Default: `1234`.

## NixOS module

Declared in [nixos-module.nix](../nixos-module.nix).

### `services.lmstudio.enable`

Whether to enable LM Studio server (system-level daemon).

Type: `boolean`. Default: `false`.

### `services.lmstudio.package`

The LM Studio server package to use.

Type: `package`. Default: `pkgs.lmstudio-server`.

### `services.lmstudio.dataDir`

The daemon's home directory; LM Studio keeps its models, engines and settings under it.

Type: `absolute path`. Default: `"/var/lib/lmstudio"`.

### `services.lmstudio.host`

Address the LM Studio API server binds to; 0.0.0.0 accepts connections from the network.

Type: `string`. Default: `"127.0.0.1"`. Example: `"0.0.0.0"`.

### `services.lmstudio.openFirewall`

Whether to open the firewall for the LM Studio API port.

Type: `boolean`. Default: `false`.

### `services.lmstudio.port`

Port for the LM Studio API server.

Type: `16 bit unsigned integer; between 0 and 65535 (both inclusive)`. Default: `1234`.
