{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.lmstudio;

  # Electron implements no xdg_toplevel_icon, so KWin resolves a Wayland window's icon from the user's icon theme directories.
  iconFiles =
    package: iconName:
    builtins.listToAttrs (
      map
        (size: {
          name = "icons/hicolor/${size}/apps/${iconName}.png";
          value.source = "${package}/share/icons/hicolor/${size}/apps/${iconName}.png";
        })
        [
          "16x16"
          "32x32"
          "48x48"
          "64x64"
          "128x128"
          "256x256"
        ]
    );
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

    home = lib.mkOption {
      type = lib.types.path;
      default = "${config.xdg.dataHome}/lmstudio";
      defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/lmstudio"'';
      description = ''
        Where LM Studio, Bionic, lms and llmster keep models, engines and settings.
        Written to the pointer file they all read at start, ~/.lmstudio-home-pointer,
        when neither that pointer nor a legacy home (~/.lmstudio or ~/.cache/lm-studio)
        exists yet; from then on the apps own the pointer.
      '';
    };

    bionic = {
      enable = lib.mkEnableOption "LM Studio Bionic, the agent desktop app";

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.lmstudio-bionic;
        defaultText = lib.literalExpression "pkgs.lmstudio-bionic";
        description = "The LM Studio Bionic package to use.";
      };
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
    (lib.mkIf cfg.enable {
      home.packages = [ cfg.package ];
      xdg.dataFile = iconFiles cfg.package "lm-studio";
    })

    (lib.mkIf cfg.bionic.enable {
      home.packages = [ cfg.bionic.package ];
      xdg.dataFile = iconFiles cfg.bionic.package "bionic";
    })

    (lib.mkIf (cfg.enable || cfg.bionic.enable || cfg.server.enable) {
      home.activation.lmstudioHomePointer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        pointer="$HOME/.lmstudio-home-pointer"
        if [ ! -e "$pointer" ] && [ ! -e "$HOME/.lmstudio" ] && [ ! -e "$HOME/.cache/lm-studio" ]; then
          if [[ -v DRY_RUN ]]; then
            echo "would seed $pointer with ${cfg.home}"
          else
            printf '%s' "${cfg.home}" >"$pointer"
          fi
        fi
      '';
    })

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
