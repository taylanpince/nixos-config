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
      pkg-config
      openssl
      llvmPackages.libclang
    ];

    LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.llvmPackages.libclang.lib}/lib/clang/${pkgs.llvmPackages.libclang.version}/include -isystem ${pkgs.glibc.dev}/include";
  };
}
