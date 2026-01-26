{ config, pkgs, ... }:

let
  # Pin the repo (recommended). Get sha256 via:
  # nix-shell -p nix-prefetch
  # nix-prefetch-url --unpack https://github.com/kolide/nix-agent/archive/refs/heads/main.tar.gz
  kolideSrc = builtins.fetchTarball {
    url = "https://github.com/kolide/nix-agent/archive/refs/heads/main.tar.gz";
    sha256 = "1d52jvm8rk7sb1x61h8wkmfldif3xcabwssvbz006clr72afnb2j";
  };
in
{
  nixpkgs.config.allowUnfree = true;

  imports = [
    "${kolideSrc}/modules/kolide-launcher"
  ];

  systemd.services.kolide-launcher.path = with pkgs; [ dpkg ];

  services.kolide-launcher.enable = true;
}

