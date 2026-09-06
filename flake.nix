{
  description = "LM Studio, LM Studio Bionic and the headless llmster server for x86-64 and arm64 Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # LM Studio's ROCm engine is built against the ROCm 6 ABI; nixos-unstable carries ROCm 7.
    nixpkgs-rocm6.url = "github:NixOS/nixpkgs/nixos-25.11";

    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    std = {
      url = "github:Daaboulex/nix-packaging-standard?ref=v2.34.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [ inputs.std.flakeModules.base ];

      flake.overlays.default =
        final: _prev:
        let
          rocm6 = import inputs.nixpkgs-rocm6 { localSystem.system = final.stdenv.hostPlatform.system; };
        in
        {
          lmstudio = final.callPackage ./stable.nix { inherit rocm6; };
          lmstudio-beta = final.callPackage ./beta.nix { inherit rocm6; };
          lmstudio-bionic = final.callPackage ./bionic.nix { inherit rocm6; };
          lmstudio-server = final.callPackage ./server.nix { };
        };
      flake.nixosModules.default = import ./nixos-module.nix;
      flake.homeModules.default = import ./hm-module.nix;

      perSystem =
        { system, self', ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          rocm6 = import inputs.nixpkgs-rocm6 { inherit system; };
        in
        {
          packages.stable = pkgs.callPackage ./stable.nix { inherit rocm6; };
          packages.beta = pkgs.callPackage ./beta.nix { inherit rocm6; };
          packages.bionic = pkgs.callPackage ./bionic.nix { inherit rocm6; };
          packages.lmstudio = self'.packages.stable;
          packages.lmstudio-beta = self'.packages.beta;
          packages.lmstudio-bionic = self'.packages.bionic;
          packages.lmstudio-server = pkgs.callPackage ./server.nix { };
          packages.default = self'.packages.lmstudio;

          apps.lmstudio = {
            type = "app";
            program = "${self'.packages.lmstudio}/bin/lmstudio";
            meta.description = "LM Studio desktop application, stable channel";
          };
          apps.lmstudio-beta = {
            type = "app";
            program = "${self'.packages.lmstudio-beta}/bin/lmstudio";
            meta.description = "LM Studio desktop application, beta channel";
          };
          apps.lmstudio-bionic = {
            type = "app";
            program = "${self'.packages.lmstudio-bionic}/bin/lmstudio-bionic";
            meta.description = "LM Studio Bionic, the agent desktop application";
          };
          apps.lmstudio-server = {
            type = "app";
            program = "${self'.packages.lmstudio-server}/bin/lms";
            meta.description = "LM Studio headless server (lms) for serving local models";
          };
          apps.default = self'.apps.lmstudio;

          checks.module-eval-nixos = inputs.std.lib.nixosModuleCheck {
            inherit (inputs) nixpkgs;
            inherit system;
            overlays = [ self.overlays.default ];
            module = ./nixos-module.nix;
            config = {
              nixpkgs.config.allowUnfree = true;
              services.lmstudio.enable = true;
            };
          };
          checks.module-eval-hm = inputs.std.lib.homeModuleCheck {
            inherit (inputs) nixpkgs home-manager;
            inherit system;
            overlays = [ self.overlays.default ];
            module = ./hm-module.nix;
            config.programs.lmstudio = {
              enable = true;
              bionic.enable = true;
              server.enable = true;
            };
          };
        };
    };
}
