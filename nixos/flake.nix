{
  description = "NixOS system config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      nixosConfigurations.bloomware = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
        ];
      };

      devShells.${system} = {
        go = pkgs.mkShell {
          packages = with pkgs; [
            go gopls delve golangci-lint
          ];
        };

        go-cgo = pkgs.mkShell {
          packages = with pkgs; [
            go gopls delve golangci-lint
            gcc pkg-config openssl zlib sqlite
          ];
        };
      };
    };
}
