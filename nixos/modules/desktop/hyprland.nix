{ pkgs, ... }:

{
  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    libva
    libva-vdpau-driver
    libvdpau-va-gl
  ];

  # Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # Electron / X11
    withUWSM = true; # recommended: starts graphical-session.target
  };

  programs.dconf.enable = true;

  environment.pathsToLink = [ "/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" ];
  environment.sessionVariables.XDG_DATA_DIRS = [
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
  ];

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
      };
    };
  };

  security.polkit.enable = true;

  # Polkit agent (GUI <> system auth)
  systemd.user.services.polkit-gnome-agent = {
    description = "polkit-gnome-agent";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
