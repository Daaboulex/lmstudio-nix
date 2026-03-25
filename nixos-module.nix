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

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for the LM Studio API port.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/lmstudio";
      description = "Directory for LM Studio data and models.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.lmstudio = {
      isSystemUser = true;
      group = "lmstudio";
      home = cfg.dataDir;
      description = "LM Studio daemon user";
    };

    users.groups.lmstudio = { };

    systemd.services.lmstudio = {
      description = "LM Studio Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HOME = cfg.dataDir;
        LMSTUDIO_HOME = cfg.dataDir;
      };

      serviceConfig = {
        Type = "simple";
        User = "lmstudio";
        Group = "lmstudio";
        ExecStart = "${cfg.package}/bin/lms server start --port ${toString cfg.port}";
        ExecStop = "${cfg.package}/bin/lms server stop";
        StateDirectory = "lmstudio";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
