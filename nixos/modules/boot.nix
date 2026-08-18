{ pkgs, kernelPackages, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel — 6.18 series, sourced from the dedicated `nixpkgs-kernel` pin
  # (see flake.nix) so we track the latest 6.18.x point release for CVE
  # backports without moving the rest of the system. Staying on 6.18 keeps
  # CrowdStrike Falcon eBPF working; linuxPackages_latest (7.x) breaks it.
  boot.kernelPackages = kernelPackages;

  boot.kernel.sysctl = {
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "net.ipv6.conf.default.disable_ipv6" = 1;

    "kernel.sysrq" = 1;
    "kernel.hung_task_timeout_secs" = 120;
  };

  boot.extraModprobeConfig = ''
    options mt7925e disable_aspm=1
  '';
}
