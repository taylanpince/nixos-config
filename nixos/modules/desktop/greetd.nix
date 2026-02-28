{ pkgs, ... }:

{
  # Enable the X11 windowing system
  services.xserver.enable = true;

  # GDM and GNOME Desktop Environment
  services.displayManager.gdm.enable = false;
  services.desktopManager.gnome.enable = false;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable greetd + ReGreet
  services.greetd.enable = true;
  programs.regreet.enable = true;

  programs.regreet.settings =
    builtins.fromTOML (builtins.readFile ../../greetd/regreet.toml);

  programs.regreet.extraCss =
    builtins.readFile ../../greetd/regreet.css;

  environment.etc."greetd/background.png".source = ../../greetd/background.png;

  # Run ReGreet inside Cage (simple + robust)
  services.greetd.settings.default_session = {
    user = "greeter";
    command = "${pkgs.cage}/bin/cage -s -mlast -- ${pkgs.regreet}/bin/regreet";
  };
}
