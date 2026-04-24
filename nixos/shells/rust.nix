{ pkgs }:

{
  rust = pkgs.mkShell {
    packages = with pkgs; [
      rustup
      protobuf
      cargo-nextest
      cargo-make
      cargo-insta
      go
    ];
  };
}
