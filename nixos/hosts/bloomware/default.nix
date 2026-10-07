{ ... }:

{
  imports = [
    ../../hardware-configuration.nix
    ../../falcon.nix
    ../../kolide.nix
    ../../keyd.nix

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
    ../../modules/whisper-models.nix
    ../../modules/fonts.nix
    ../../nordvpn.nix
    ../../modules/cloudflare-warp.nix
    ../../modules/logging.nix
    ../../modules/power.nix
    ../../modules/pennyworth-mdns.nix
  ];

  networking.hostName = "bloomware";

  # pennyworth.local for the Pennyworth board on the home Wi-Fi (phones; paired devices only).
  services.pennyworth-mdns = {
    enable = true;
    ssid = "Mimi";
  };

  # NixOS release compatibility.
  system.stateVersion = "25.11";
}
