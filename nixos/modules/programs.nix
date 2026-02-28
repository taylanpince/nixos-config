{ ... }:

{
  security.pki.installCACerts = true;

  # Install firefox
  programs.firefox.enable = true;

  # direnv
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "taylan" ];
  };

  # keyring + secret service
  services.gnome.gnome-keyring.enable = true;

  # handy for debugging keyring contents
  programs.seahorse.enable = true;
}
