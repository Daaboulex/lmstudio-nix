{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.lmstudio;
in
{
  options.programs.lmstudio = {
    enable = lib.mkEnableOption "LM Studio desktop app";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.lmstudio;
      defaultText = lib.literalExpression "pkgs.lmstudio";
      description = "The LM Studio desktop package to use.";
    };

    server = {
      enable = lib.mkEnableOption "LM Studio user daemon";

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

      autostart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to start the LM Studio daemon on login.";
      };
    };
  };

  config = lib.mkMerge [
    # Desktop app
    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];
    })

    # User daemon
    (lib.mkIf cfg.server.enable {
      systemd.user.services.lmstudio = {
        Unit = {
          Description = "LM Studio Server (user)";
          After = [ "default.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${cfg.server.package}/bin/lms server start --port ${toString cfg.server.port}";
          ExecStop = "${cfg.server.package}/bin/lms server stop";
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install = lib.mkIf cfg.server.autostart {
          WantedBy = [ "default.target" ];
        };
      };
    })
  ];
}
