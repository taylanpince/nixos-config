{ pkgs }:

{
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
}

