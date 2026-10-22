{ lib, pkgs, warpPackage, ... }:

{
  services.cloudflare-warp = {
    enable = true;
    openFirewall = true;
    # From the dedicated `nixpkgs-warp` pin (see flake.nix) so the client
    # stays current without moving the system nixpkgs.
    package = warpPackage;
  };

  # WARP >= 2026.8 execs the absolute FHS path /usr/sbin/nft to load its
  # firewall; without it every connect fails with "Permission denied" and
  # drops back to Disconnected. Backported from the nixos-unstable module —
  # drop this once the system nixpkgs' cloudflare-warp module has it.
  systemd.services.cloudflare-warp.serviceConfig.BindReadOnlyPaths = [
    "${lib.getExe pkgs.nftables}:/usr/sbin/nft"
  ];
}
