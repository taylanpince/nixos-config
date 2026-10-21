{ warpPackage, ... }:

{
  services.cloudflare-warp = {
    enable = true;
    openFirewall = true;
    # From the dedicated `nixpkgs-warp` pin (see flake.nix) so the client
    # stays current without moving the system nixpkgs.
    package = warpPackage;
  };
}
