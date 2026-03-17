{
  description = "NixOS system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";

      # Override claude-code to latest npm version
      overlay = final: prev: {
        claude-code = prev.claude-code.overrideAttrs (old: rec {
          version = "2.1.72";
          src = prev.fetchurl {
            url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
            hash = "sha512-GhoUURM5xUPL+DSn0jMPXDEkWvocl5lqCs/wnyYDUliY0fBlXm7LxWnjLCBPZ0LoeUnr2e6MFRBxyUFrgrRp0A==";
          };
        });
      };

      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };

      goShells = import ./shells/go.nix { inherit pkgs; };
      pyShells = import ./shells/python.nix { inherit pkgs; };
      nodeShells = import ./shells/node.nix { inherit pkgs; };
      pulumiShells = import ./shells/pulumi.nix { inherit pkgs; };
      postgresShells = import ./shells/postgres.nix { inherit pkgs; };
    in
    {
      nixosConfigurations.bloomware = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          { nixpkgs.overlays = [ overlay ]; }
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.taylan = import ./home/taylan.nix;
          }
        ];
      };

      devShells.${system} =
        goShells
        // pyShells
        // nodeShells
        // pulumiShells
        // postgresShells;
    };
}
