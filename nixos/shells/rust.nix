{ pkgs }:

{
  rust = pkgs.mkShell {
    name = "rust";
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
