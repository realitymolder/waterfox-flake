{
  pkgs ? import <nixpkgs> {},
  system ? pkgs.stdenv.hostPlatform.system,
}: let
  mkWaterfox = name: entry: let
    variant = (builtins.fromJSON (builtins.readFile ./sources.json)).${entry}.${system};
  in
    pkgs.callPackage ./package.nix {
      inherit name variant;
    };
in rec {
  waterfox-unwrapped = mkWaterfox "main" "main";

  waterfox = pkgs.wrapFirefox waterfox-unwrapped {};

  default = waterfox;
}
