{
  description = "LM Studio — local LLM inference desktop app and server";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
    }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      overlays.default = final: _prev: {
        lmstudio = final.callPackage ./stable.nix { };
        lmstudio-beta = final.callPackage ./beta.nix { };
        lmstudio-server = final.callPackage ./server.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            localSystem.system = system;
            config.allowUnfree = true;
          };
        in
        {
          stable = pkgs.callPackage ./stable.nix { };
          beta = pkgs.callPackage ./beta.nix { };
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
        pkgs.nixfmt-rfc-style
      );

      checks = forAllSystems (system: {
        pre-commit-check = git-hooks.lib.${system}.run {
          src = self;
          hooks.nixfmt-rfc-style.enable = true;
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
