{
  description = "dev flakes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.${system} = {
        go = pkgs.mkShell {
          packages = with pkgs; [
            go
            gopls
            delve
            golangci-lint
          ];
        };

        go-cgo = pkgs.mkShell {
          packages = with pkgs; [
            go
            gopls
            delve
            golangci-lint
            gcc
            pkg-config
            openssl
            zlib
            sqlite
          ];
        };
      };
    };
}

