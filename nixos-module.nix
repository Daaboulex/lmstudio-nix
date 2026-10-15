{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.lmstudio;
in
{
  options.services.lmstudio = {
    enable = lib.mkEnableOption "LM Studio server (system-level daemon)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.lmstudio-server;
      defaultText = lib.literalExpression "pkgs.lmstudio-server";
      description = "The LM Studio server package to use.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 1234;
      description = "Port for the LM Studio API server.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address the LM Studio API server binds to; 0.0.0.0 accepts connections from the network.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for the LM Studio API port.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/lmstudio";
      description = "The daemon's home directory; LM Studio keeps its models, engines and settings under it.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          !cfg.openFirewall
          || !(lib.hasPrefix "127." cfg.host || cfg.host == "::1" || cfg.host == "localhost");
        message = "services.lmstudio.openFirewall opens port ${toString cfg.port}, but services.lmstudio.host = ${cfg.host} binds the API server to loopback only; set host to an address on the network, such as 0.0.0.0.";
      }
    ];

    users.users.lmstudio = {
      isSystemUser = true;
      group = "lmstudio";
      home = cfg.dataDir;
      description = "LM Studio daemon user";
    };

    users.groups.lmstudio = { };

    systemd.services.lmstudio = {
      description = "LM Studio daemon (llmster) and its API server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment.HOME = cfg.dataDir;

      serviceConfig =
        import ./service.nix {
          inherit lib;
          inherit (pkgs) writeShellScript;
          inherit (cfg) package port;
          bind = cfg.host;
        }
        // {
          User = "lmstudio";
          Group = "lmstudio";
          StateDirectory = "lmstudio";
        };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
