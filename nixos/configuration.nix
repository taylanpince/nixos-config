{ ... }:

{
  # Keep this file as a thin entry-point.
  # Host-specific wiring lives under nixos/hosts/.
  imports = [
    ./hosts/bloomware
  ];
}
