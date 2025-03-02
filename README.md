# Numen Nix

A nix flake that builds [numen](https://git.sr.ht/~geb/numen), a voice control system.

## Prerequisites

To run this as a non-root user, you'll need to add a udev rule for [dotool](https://git.sr.ht/~geb/dotool) and make yourself a member of `input` in your Nix configuration:

```nix
services.udev.packages = [ pkgs.dotool ];
users.users.<user> = {
  extraGroups = [
    "input"
  ];
};
```

## Home Manager Module

The module provides a systemd service to run numen and configure various aspects of its operation.

### Basic Usage

Add this repository as an input:
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    numen = {
      url = "github:LorenzBischof/numen-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, numen }: 
    homeConfiguration.yourHostname = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        ./configuration.nix
        numen.homeManagerModule
      ];
    };
  };
}
```
Add the following to your home-manager configuration:

```nix
services.numen.enable = true;
```

### Configuration Options

- `enable` (boolean): Enable the numen service. Default: `false`
- `package` (package): The numen package to use. Default: `numen` from flake
- `model` (path): Path to the Vosk model. Default: Uses `vosk-model-small-en-us`
- `phrases` (list of paths): Custom phrase files to load. Default: `[]` (uses default phrases or `~/.config/numen/phrases`)
- `pausedPhrase` (path): This phrase file is loaded when Numen is paused. Default: `please wake up` (see implementation to configure)
- `extraArgs` (string): Additional command-line arguments for numen. Default: `""`
- `xkbLayout` (string): XKB keyboard layout for dotool. Default: `"en"`
- `xkbVariant` (string): XKB keyboard variant for dotool. Default: `""`
- `subtitles.enable` (boolean): Enable on-screen display of recognized phrases. Default: `false`
- `updateCommand` (package): Script that is run after pausing or resuming Numen. Default: `null`

### Example Configuration

```nix
{
  services.numen = {
    enable = true;
    xkbLayout = "us";
    phrases = [ 
      ./my-custom-phrases.phrases 
    ];
    subtitles.enable = true;
  };
}
```

### Utilities

The module provides several utility scripts:

- `numen-sleep`: Pauses voice recognition. Survives Systemd service restart.
- `numen-wake`: Resumes voice recognition
- `numen-subtitles`: Displays recognized phrases as a notification (can be manually run, when subtitles are disabled)

### Automatically reload phrases

For local development you can use direnv to automatically reload the phrases whenever you make changes.

```sh
watch_file phrases/*

statedir="${XDG_STATE_HOME:-$HOME/.local/state}/numen"

if [ -e "$statedir/paused" ]; then
  echo "Numen paused. Not reloading."
else
  echo load $PWD/phrases/* | numenc
  echo "Reloaded phrases."
fi
```

### i3status-rust

```nix
  services.numen = {
    enable = true;
    updateCommand = pkgs.writeShellApplication {
      name = "reload-i3status";
      text = "pkill -SIGRTMIN+4 i3status-rs";
    };
  };
  programs.i3status-rust = {
    enable = true;
    bars.default = {
      theme = "native";
      icons = "awesome6";
      blocks = [
        {
          block = "custom";
          signal = 4;
          command = ''
            if ! systemctl --user is-active numen > /dev/null; then 
                echo 
            else 
              if [ -f "$HOME/.local/state/numen/paused" ]; then 
                echo 
              else 
                echo 
              fi; 
            fi
          '';
          interval = 5;
        }
      ];
    };
  };
```
