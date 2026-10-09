{ ... }:

{
  # Tailscale: reach the Pennyworth board from the phone away from home
  # (`tailscale serve` in front of the board's LAN port; see the Pennyworth README).
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # Only trust traffic arriving over the tailnet interface; nothing else is exposed.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
