{ numen, vosk-model-small-en-us }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.numen;
in
{
  options.services.numen = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
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

    model = lib.mkOption {
      type = lib.types.pathInStore;
      default = "${vosk-model-small-en-us}/usr/share/vosk-models/small-en-us/";
      example = "vosk-model-small-en-us";
      description = ''
        Vosk model to be loaded by numen.
      '';
    };

    phrases = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = ''
        Phrases to be loaded by numen. If empty, the default phrases are used.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.singleLineStr;
      default = "";
      description = ''
        Additional arguments to be passed to numen.
      '';
    };

    xkbLayout = lib.mkOption {
      type = lib.types.singleLineStr;
      default = "en";
      description = ''
        The XKB keyboard layout that should be used by dotool.
      '';
    };

    xkbVariant = lib.mkOption {
      type = lib.types.singleLineStr;
      default = "";
      description = ''
        The XKB keyboard variant that should be used by dotool.
      '';
    };
    subtitles.enable = lib.mkEnableOption "subtitles";
  };

  config =
    let
      numen-subtitles = pkgs.writeShellApplication {
        name = "numen-subtitles";
        runtimeInputs = [
          pkgs.entr
        ];
        text = ''
          statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/numen"
          echo "$statedir/phrase" | entr -npa ${numen-subtitles-notify}/bin/numen-subtitles-notify
        '';
      };
      numen-subtitles-notify = pkgs.writeShellApplication {
        name = "numen-subtitles-notify";
        runtimeInputs = [
          pkgs.libnotify
          pkgs.coreutils
        ];
        text = ''
          statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/numen"
          phrasefile="$statedir/phrase"
          bufferfile="$statedir/phrasebuffer"

          phrase="$(cat "$phrasefile")"

          NOTIFICATION_ID=9999
          CURRENT_TIME="$(date +%s)"
          LAST_NOTIFICATION_TIME="$(date -r "$bufferfile" +%s || echo 0)"

          if [[ $((CURRENT_TIME - LAST_NOTIFICATION_TIME)) -le 5 ]]; then
              # If last phrase was within 5 seconds, append to buffer
              printf ' %s' "$phrase" >> "$bufferfile"
              notify-send -r "$NOTIFICATION_ID" "$(cat "$bufferfile")"
          else
              # Clear buffer and start fresh
              printf '%s' "$phrase" > "$bufferfile"
              notify-send -r "$NOTIFICATION_ID" "$phrase"
          fi
        '';
      };
      numen-wake = pkgs.writeShellApplication {
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
    lib.mkIf cfg.enable {
      home.packages = [
        cfg.package
        numen-wake
        numen-subtitles
      ];
      systemd.user.services.numen =
        let
          # We need a separate file, because if we pass nothing, the default phrases are loaded
          # We cannot wake numen, because it triggers too often.
          paused = pkgs.writeText "numen-paused" ''
            talon wake: run notify-send "Numen not listening" \
                        load
          '';
          numen-wrapper = pkgs.writeShellApplication {
            name = "numen-wrapper";
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
          Service.ExecStart = "${numen-wrapper}/bin/numen-wrapper";
        };

      systemd.user.services.numen-subtitles = lib.optionalAttrs cfg.subtitles.enable {
        Unit = {
          Description = "File monitor with notifications";
          After = [ "numen.service" ];
          Requires = [ "numen.service" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${numen-subtitles}/bin/numen-subtitles";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
}
