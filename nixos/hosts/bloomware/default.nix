{ ... }:

{
  imports = [
    ../../hardware-configuration.nix
    ../../falcon.nix
    ../../kolide.nix

    ../../modules/boot.nix
    ../../modules/networking.nix
    ../../modules/locale.nix
    ../../modules/nix.nix
    ../../modules/users.nix
    ../../modules/virtualisation.nix
    ../../modules/programs.nix
    ../../modules/services.nix
    ../../modules/desktop/greetd.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/packages.nix
    ../../modules/fonts.nix
    ../../nordvpn.nix
    ../../modules/cloudflare-warp.nix
    ../../modules/logging.nix
    ../../modules/power.nix
  ];

  networking.hostName = "bloomware";

  # NixOS release compatibility.
  system.stateVersion = "25.11";
}
