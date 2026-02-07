{
  description = "NixOS system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      goShells = import ./shells/go.nix { inherit pkgs; };
      pyShells = import ./shells/python.nix { inherit pkgs; };
      nodeShells = import ./shells/node.nix { inherit pkgs; };
    in
    {
      nixosConfigurations.bloomware = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
        ];
      };

      devShells.${system} =
        goShells
        // pyShells
        // nodeShells;
    };
}
