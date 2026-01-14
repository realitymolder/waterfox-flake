{
  description = "Waterfox";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
  }: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-darwin"
    ];

    forAllSystems = f:
      nixpkgs.lib.genAttrs supportedSystems (
        system: f nixpkgs.legacyPackages.${system}
      );
  in {
    packages = forAllSystems (pkgs: import ./default.nix {inherit pkgs;});

    formatter = forAllSystems (pkgs: pkgs.alejandra);

    homeModules = {
      waterfox = import ./hm-module.nix {
        inherit self home-manager;
        name = "main";
      };
      default = self.homeModules.waterfox;
    };
  };
}
