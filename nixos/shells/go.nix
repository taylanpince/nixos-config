{ pkgs }:

{
  go = pkgs.mkShell {
    name = "go";
    packages = with pkgs; [
      go
      gopls
      delve
      golangci-lint
    ];
  };

  go-cgo = pkgs.mkShell {
    name = "go-cgo";
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
}

