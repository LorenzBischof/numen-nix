{
  description = "A flake for building numen";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      numen-nix = import ./. { inherit pkgs; };
    in
    {
      packages.x86_64-linux = {
        inherit (numen-nix) vosk-bin vosk-model-small-en-us numen;
        default = numen-nix.numen;
      };
      overlays.default = numen-nix.overlay;
      homeManagerModules.numen-nix = numen-nix.homeManagerModule;
      homeManagerModule = self.homeManagerModules.numen-nix;
      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
    };
}
