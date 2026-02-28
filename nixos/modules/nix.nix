{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.settings = {
    ssl-cert-file = "/etc/ssl/certs/ca-certificates.crt";
  };

  nixpkgs.config.allowUnfree = true;

  # nix-index: provides `nix-locate` and optional command-not-found integration
  programs.nix-index.enable = true;

  # Needed for Falcon compat
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
    libuuid
    libcap
    libgcc
    curl
  ];

  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bash}/bin/bash"
  ];
}
