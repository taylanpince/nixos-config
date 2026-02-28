{ config, pkgs, ... }:

{
  home.username = "taylan";
  home.homeDirectory = "/home/taylan";

  # Required by home-manager
  home.stateVersion = "25.11";

  # Keep this minimal to start. We can migrate your dotfiles/configs here gradually.
  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Taylan Pince";
    userEmail = "taylanpince@gmail.com";
  };

  programs.starship.enable = true;

  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  # A few CLI niceties (matches what you already install system-wide)
  programs.fzf.enable = true;
  programs.zoxide.enable = true;
  programs.eza.enable = true;
  programs.bat.enable = true;

  # Let home-manager manage user packages as you decide. Starting empty.
  home.packages = [ ];
}
