{ numen, vosk-model-small-en-us }:
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.numen;
in
{
  options.services.numen = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    package = mkOption {
      type = types.package;
      default = numen;
    };

    # models = mkOption {
    #   type = types.uniq types.listOf types.package;
    #   default = [vosk-model-small-en-us];
    #   example = "[vosk-model-small-en-us]";
    #   description = ''
    #     List of vosk models to be loaded by numen. They can be referred to using the index, eg. model0 or model1.
    #   '';
    # };

    model = mkOption {
      type = types.pathInStore;
      default = "${vosk-model-small-en-us}/usr/share/vosk-models/small-en-us/";
      example = "vosk-model-small-en-us";
      description = ''
        Vosk model to be loaded by numen.
      '';
    };

    phrases = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        Phrases to be loaded by numen. If empty, the default phrases are used.
      '';
    };

    extraArgs = mkOption {
      type = types.singleLineStr;
      default = "";
      description = ''
        Additional arguments to be passed to numen.
      '';
    };

    xkbLayout = mkOption {
      type = types.singleLineStr;
      default = "en";
      description = ''
        The XKB keyboard layout that should be used by dotool.
      '';
    };

    xkbVariant = mkOption {
      type = types.singleLineStr;
      default = "";
      description = ''
        The XKB keyboard variant that should be used by dotool.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      let
        wake = pkgs.writeShellApplication {
          name = "numen-wake";
          text = ''
            statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/numen"
            phrases="${lib.strings.concatStringsSep " " cfg.phrases}"
            if [ -z "$phrases" ]; then
              # shellcheck disable=SC2086
              phrases="$(echo ''${XDG_CONFIG_HOME:-$HOME/.config}/numen/phrases/*.phrases)"
            fi
            rm -f "$statedir/paused"
            echo "load $phrases" | numenc
          '';
        };
      in
      [
        cfg.package
        wake
      ];
    systemd.user.services.numen =
      let
        # We need a separate file, because if we pass nothing, the default phrases are loaded
        # We cannot wake numen, because it triggers too often.
        paused = pkgs.writeText "numen-paused" ''
          talon wake: run notify-send "Numen not listening" \
                      load
        '';
        reload = pkgs.writeShellApplication {
          name = "numen-reload";
          text = ''
            statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/numen"
            phrases="${lib.strings.concatStringsSep " " cfg.phrases}"
            if [ -e "$statedir/paused" ]; then
              phrases="${paused}"
            fi
            # shellcheck disable=SC2086
            ${cfg.package}/bin/numen ${cfg.extraArgs} $phrases
          '';
        };
      in
      {
        Unit = {
          Description = "Numen voice control";
          After = [ "graphical-session-pre.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service.Environment = [
          "DOTOOL_XKB_LAYOUT=${cfg.xkbLayout}"
          "DOTOOL_XKB_VARIANT=${cfg.xkbVariant}"
          "NUMEN_MODEL=${cfg.model}"
          "NUMEN_SCRIPTS_DIR=${cfg.package}/etc/numen/scripts"
        ];
        Service.ExecStart = "${reload}/bin/numen-reload";
      };
  };
}
