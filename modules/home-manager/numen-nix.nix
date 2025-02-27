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

    pausedPhrase = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "numen-paused" ''
        please: set a echo 1
        wake: eval [ "$a" ] && echo set b echo 1
        up: run [ "$b" ] && numen-wake
        <complete>: set a : \
                    set b :
      '';
      description = ''
        This phrase file is loaded when Numen is paused. See https://lists.sr.ht/~geb/numen/%3C55fe1488feeb1cee2627d61b9b7e16a74ef5fca0.camel@dalibo.com%3E
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
        runtimeInputs = with pkgs; [
          libnotify
          coreutils
          inotify-tools
          gnugrep
        ];
        text = ''
          statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/numen"
          phrasefile="$statedir/phraselog"
          linefile="$statedir/line"
          linecountfile="$statedir/linecount"
            
          touch "$phrasefile" # make sure it exists
          linecount="$(wc -l "$phrasefile" | cut -d' ' -f1)"
          if [ ! -f "$linefile" ]; then
            echo -n "$linecount" > "$linefile"
          fi
          if [ ! -f "$linecountfile" ]; then
            echo -n "$linecount" > "$linecountfile"
          fi

          inotifywait -m "$phrasefile" -e modify | while read -r _ _ _; do
            linecount="$(wc -l "$phrasefile" | cut -d' ' -f1)"

            if [ -f "$statedir/paused" ]; then
              echo -n "$linecount" > "$linefile"
              echo -n "$linecount" > "$linecountfile"
              continue
            fi

            CURRENT_TIME="$(date +%s)"
            LAST_NOTIFICATION_TIME="$(date -r "$linecountfile" +%s || echo 0)"
            
            line="$(cat "$linefile")"

            # Reset line counter if numen was restarted
            if [ "$linecount" -lt "$line" ]; then
              line="0"
              echo -n "$line" > "$linefile"
              echo -n "$line" > "$linecountfile"
            fi
            
            if [[ $((CURRENT_TIME - LAST_NOTIFICATION_TIME)) -gt 5 ]]; then
              # We need to use the value from the last run, otherwise it does not work correctly
              # when multiple phrases are written to the log at the same time.
              line="$(cat "$linecountfile")"
              line=$((line + 1)) # We counted the lines before the current word was added
              echo -n "$line" > "$linefile"
            fi
            echo -n "$linecount" > "$linecountfile"

            phrase="$(tail -n +"$line" "$phrasefile" | grep -v huh | tr '\n' ' ' || true)"
            [ -z "$phrase" ] && continue

            NOTIFICATION_ID=9999

            notify-send -r "$NOTIFICATION_ID" "$phrase"
          done
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
      numen-sleep = pkgs.writeShellApplication {
        name = "numen-sleep";
        runtimeInputs = with pkgs; [
          libnotify
          coreutils
        ];
        text = ''
          statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/numen"
          notify-send "Numen paused"
          touch "$statedir/paused"
          echo "load ${cfg.pausedPhrase}" | numenc
        '';
      };

    in
    lib.mkIf cfg.enable {
      home.packages = [
        cfg.package
        numen-wake
        numen-sleep
        numen-subtitles
      ];
      systemd.user.services.numen =
        let
          numen-wrapper = pkgs.writeShellApplication {
            name = "numen-wrapper";
            text = ''
              statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/numen"
              phrases="${lib.strings.concatStringsSep " " cfg.phrases}"
              if [ -e "$statedir/paused" ]; then
                phrases="${cfg.pausedPhrase}"
              fi
              # shellcheck disable=SC2086
              ${cfg.package}/bin/numen ${cfg.extraArgs} ${lib.optionalString cfg.subtitles.enable "--phraselog $statedir/phraselog"} $phrases
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
            "PATH=${
              lib.makeBinPath [
                cfg.package
                numen-wake
                numen-sleep
              ]
            }"
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
