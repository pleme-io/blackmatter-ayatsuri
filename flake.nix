{
  description = "blackmatter-karakuri — Home-Manager module for karakuri macOS automation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    karakuri = {
      url = "github:pleme-io/karakuri";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.substrate.follows = "substrate";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      substrate,
      karakuri,
    }:
    {
      homeManagerModules.default = import ./module {
        hmHelpers = import "${substrate}/lib/hm-service-helpers.nix" { lib = nixpkgs.lib; };
        karakuriOverlay = karakuri.overlays.default;
      };
    };
}
