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

      pkgs = import nixpkgs { inherit system; };

      goShells = import ./shells/go.nix { inherit pkgs; };
      pyShells = import ./shells/python.nix { inherit pkgs; };
      nodeShells = import ./shells/node.nix { inherit pkgs; };
      pulumiShells = import ./shells/pulumi.nix { inherit pkgs; };
      postgresShells = import ./shells/postgres.nix { inherit pkgs; };
      rustShells = import ./shells/rust.nix { inherit pkgs; };
    in
    {
      nixosConfigurations.bloomware = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
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
        // postgresShells
        // rustShells;
    };
}
