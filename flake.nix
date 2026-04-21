{
  description = "Blackmatter Ayatsuri — home-manager module for ayatsuri macOS automation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ayatsuri = {
      url = "github:pleme-io/ayatsuri";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.substrate.follows = "substrate";
    };
  };

  outputs = inputs @ { self, nixpkgs, substrate, ayatsuri, ... }:
    (import "${substrate}/lib/blackmatter-component-flake.nix") {
      inherit self nixpkgs;
      name = "blackmatter-ayatsuri";
      description = "home-manager module for ayatsuri — macOS window manager + automation";
      modules.homeManager = import ./module {
        hmHelpers = import "${substrate}/lib/hm-service-helpers.nix" { lib = nixpkgs.lib; };
        ayatsuriOverlay = ayatsuri.overlays.default;
      };
    };
}
