{ ... }:

{
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  networking.wireless.iwd.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.enable = false;

  # Ensure /etc/resolv.conf contains real upstream DNS (not 127.0.0.x)
  services.resolved.enable = false;
  networking.resolvconf.enable = true;
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  systemd.services.NetworkManager.serviceConfig = {
    TimeoutStopSec = "10s";
    SendSIGKILL = true;
  };
}
