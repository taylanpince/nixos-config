{ config, pkgs, ... }:

let
  # Pin the repo (recommended). Get sha256 via:
  # nix-shell -p nix-prefetch
  # nix-prefetch-url --unpack https://github.com/kolide/nix-agent/archive/refs/heads/main.tar.gz
  kolideSrc = builtins.fetchTarball {
    url = "https://github.com/kolide/nix-agent/archive/refs/heads/main.tar.gz";
    sha256 = "0g9694ckraaqm2bcqwdfn7gb23rpnw59clc1pca2c2sxgfgj5285";
  };
in
{
  nixpkgs.config.allowUnfree = true;

  imports = [
    "${kolideSrc}/modules/kolide-launcher"
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/dpkg 0755 root root -"
    "f /var/lib/dpkg/status 0644 root root - Package: falcon-sensor\\nStatus: install ok installed\\nPriority: optional\\nSection: misc\\nInstalled-Size: 0\\nMaintainer: CrowdStrike\\nArchitecture: amd64\\nVersion: 7.31.0-18410\\nDescription: CrowdStrike Falcon Sensor (shim for Kolide/osquery on NixOS)\\n"
  ];

  systemd.services.kolide-launcher.path = with pkgs; [ dpkg ];

  services.kolide-launcher.enable = true;
}

