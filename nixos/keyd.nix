{ config, lib, pkgs, ... }:

{
  services.keyd.enable = true;

  # Optional: silence the setgid warning (nice to have, not required for functionality)
  users.groups.keyd = {};
  systemd.services.keyd.serviceConfig = {
    CapabilityBoundingSet = [ "CAP_SETGID" ];
    AmbientCapabilities = [ "CAP_SETGID" ];
  };

  environment.etc."keyd/default.conf".text = ''
    [ids]
    *

    [main]
    # Keep leftcontrol as normal control (so Hyprland $mod stuff stays intact).
    # Turn *right* control into its own layer key.
    rightcontrol = layer(rctrl)

    # --- Left Ctrl: compact Keychron has no grave/tilde key ---
    # Ctrl+Esc types ~ (keyd drops the Ctrl while emitting the binding).
    [control]
    esc = S-grave

    # Alt+Esc types `. keyd sees keys before Hyprland's altwin:swap_lalt_lwin,
    # so the key that acts as Alt is still Meta here.
    [meta]
    esc = grave

    # --- Right Ctrl: line/doc navigation ---
    # rctrl behaves like Control for everything *except* what we override here.
    [rctrl:C]
    left  = home
    right = end
    up    = C-home
    down  = C-end
    esc   = S-grave
  '';
}

