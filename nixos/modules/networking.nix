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

  # Polygon go/ links: bare "go" hits the golinks proxy, which 301s to
  # https://go.polygon.org/<path>. WARP's DNS doesn't answer for "go" here.
  networking.hosts."34.54.162.223" = [ "go" ];

  systemd.services.NetworkManager.serviceConfig = {
    TimeoutStopSec = "10s";
    SendSIGKILL = true;
  };

  security.pki.certificateFiles = [
    ../../certs/wintermute-root-ca.crt
    ../../certs/polygon-cloud-ca.pem
  ];

  # LocalSend: LAN device discovery + file transfer on its default port
  networking.firewall.allowedTCPPorts = [ 53317 ];
  networking.firewall.allowedUDPPorts = [ 53317 ];
}
