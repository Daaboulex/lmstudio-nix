{
  description = "LM Studio — local LLM inference desktop app and server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # ROCm 6.4.3 libs — LM Studio's ROCm llama.cpp engine is compiled against
    # ROCm 6.x. nixpkgs-unstable has ROCm 7.x (ABI-incompatible); nixos-25.11 has
    # ROCm 6.4.3 (first with full RDNA 4 / gfx1201). Remove once LM Studio ships
    # a ROCm 7.x engine.
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
      url = "github:Daaboulex/nix-packaging-standard?ref=v2.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ inputs.std.flakeModules.base ];

      flake.overlays.default = final: _prev: {
        lmstudio = final.callPackage ./stable.nix {
          rocm6 = import inputs.nixpkgs-rocm6 { localSystem.system = final.stdenv.hostPlatform.system; };
        };
        lmstudio-beta = final.callPackage ./beta.nix {
          rocm6 = import inputs.nixpkgs-rocm6 { localSystem.system = final.stdenv.hostPlatform.system; };
        };
        lmstudio-server = final.callPackage ./server.nix { };
      };
      flake.nixosModules.default = import ./nixos-module.nix;
      flake.homeManagerModules.default = import ./hm-module.nix;

      perSystem =
        { system, self', ... }:
        let
          # LM Studio is an unfree prebuilt app; rocm6 from nixos-25.11.
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          rocm6 = import inputs.nixpkgs-rocm6 { inherit system; };
        in
        {
          packages.stable = pkgs.callPackage ./stable.nix { inherit rocm6; };
          packages.beta = pkgs.callPackage ./beta.nix { inherit rocm6; };
          packages.lmstudio = self'.packages.stable;
          packages.lmstudio-beta = self'.packages.beta;
          packages.lmstudio-server = pkgs.callPackage ./server.nix { };
          packages.default = self'.packages.lmstudio;

          apps.lmstudio = {
            type = "app";
            program = "${self'.packages.lmstudio}/bin/lmstudio";
          };
          apps.lmstudio-beta = {
            type = "app";
            program = "${self'.packages.lmstudio-beta}/bin/lmstudio";
          };
          apps.lmstudio-server = {
            type = "app";
            program = "${self'.packages.lmstudio-server}/bin/lms";
          };
          apps.default = self'.apps.lmstudio;

          checks.module-eval-nixos = inputs.std.lib.nixosModuleCheck {
            inherit (inputs) nixpkgs;
            inherit system;
            overlays = [ self.overlays.default ];
            module = ./nixos-module.nix;
            config = {
              nixpkgs.config.allowUnfree = true; # lmstudio-server is unfree
              services.lmstudio.enable = true;
            };
          };
          checks.module-eval-hm = inputs.std.lib.homeModuleCheck {
            inherit (inputs) nixpkgs home-manager;
            inherit system;
            overlays = [ self.overlays.default ];
            module = ./hm-module.nix;
            config.programs.lmstudio.enable = true;
          };
        };
    };
}
