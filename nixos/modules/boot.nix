{ pkgs, ... }:

{
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

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
