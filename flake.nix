{
  description = "Blackmatter Ayatsuri — home-manager module for ayatsuri macOS automation";

  inputs = {
    nixpkgs.follows = "substrate/nixpkgs";
    substrate = {
      url = "github:pleme-io/substrate";
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
