{
  description = "LM Studio — local LLM inference desktop app and server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # ROCm 6.4.3 libs — LM Studio's ROCm llama.cpp engine is compiled against ROCm 6.x.
    # nixpkgs-unstable has ROCm 7.x (ABI-incompatible). nixos-25.11 has ROCm 6.4.3
    # which is the first version with full RDNA 4 (gfx1201) support.
    # Remove this input once LM Studio ships a ROCm 7.x engine.
    nixpkgs-rocm6.url = "github:NixOS/nixpkgs/nixos-25.11";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-rocm6,
      git-hooks,
    }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      # ROCm 6.x packages for LM Studio's pre-compiled ROCm engine
      rocm6Pkgs = system: import nixpkgs-rocm6 { localSystem.system = system; };
    in
    {
      overlays.default = final: _prev: {
        lmstudio = final.callPackage ./stable.nix {
          rocm6 = rocm6Pkgs final.stdenv.hostPlatform.system;
        };
        lmstudio-beta = final.callPackage ./beta.nix {
          rocm6 = rocm6Pkgs final.stdenv.hostPlatform.system;
        };
        lmstudio-server = final.callPackage ./server.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            localSystem.system = system;
            config.allowUnfree = true;
          };
          rocm6 = rocm6Pkgs system;
        in
        {
          stable = pkgs.callPackage ./stable.nix { inherit rocm6; };
          beta = pkgs.callPackage ./beta.nix { inherit rocm6; };
          lmstudio = self.packages.${system}.stable;
          lmstudio-beta = self.packages.${system}.beta;
          lmstudio-server = pkgs.callPackage ./server.nix { };
          default = self.packages.${system}.lmstudio;
        }
      );

      apps = forAllSystems (system: {
        lmstudio = {
          type = "app";
          program = "${self.packages.${system}.lmstudio}/bin/lmstudio";
        };
        lmstudio-beta = {
          type = "app";
          program = "${self.packages.${system}.lmstudio-beta}/bin/lmstudio";
        };
        lmstudio-server = {
          type = "app";
          program = "${self.packages.${system}.lmstudio-server}/bin/lms";
        };
        default = self.apps.${system}.lmstudio;
      });

      nixosModules.default = import ./nixos-module.nix;

      homeManagerModules.default = import ./hm-module.nix;

      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { localSystem.system = system; };
        in
        pkgs.nixfmt
      );

      checks = forAllSystems (system: {
        pre-commit-check = git-hooks.lib.${system}.run {
          src = self;
          hooks.nixfmt-rfc-style.enable = true;
            hooks.typos.enable = true;
            hooks.rumdl.enable = true;
            hooks.check-readme-sections = {
              enable = true;
              name = "check-readme-sections";
              entry = "bash scripts/check-readme-sections.sh";
              files = "README\.md$";
              language = "system";
            };
        };
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { localSystem.system = system; };
        in
        {
          default = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
            packages = with pkgs; [ nil ];
          };
        }
      );
    };
}
