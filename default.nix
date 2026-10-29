{
  pkgs ? import <nixpkgs> { },
}:
let
  packages = pkgs: rec {
    vosk-bin = pkgs.callPackage ./pkgs/vosk-bin.nix { };
    vosk-model-small-en-us = pkgs.callPackage ./pkgs/vosk-model-small-en-us.nix { };
    numen = pkgs.callPackage ./pkgs/numen.nix { inherit vosk-bin vosk-model-small-en-us; };
  };
in
packages pkgs
// {
  overlay = final: prev: packages final;
  homeManagerModule = ./modules/home-manager/numen-nix.nix;
}
