{ config, pkgs, ... }:

let
  # Pinned to an immutable commit so a moving `main` branch can't drift the
  # tarball out from under a rebuild (which silently breaks with a hash
  # mismatch). Bump by updating both rev and sha256; get the sha256 via:
  #   nix-prefetch-url --unpack https://github.com/kolide/nix-agent/archive/<rev>.tar.gz
  kolideSrc = builtins.fetchTarball {
    url = "https://github.com/kolide/nix-agent/archive/c323b0ab830bdfef89edf0765ae35ce6d9362784.tar.gz";
    sha256 = "04yn63rilab7jfav87rkk4j112x9wlsimxsijzh8i724ihb34738";
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

