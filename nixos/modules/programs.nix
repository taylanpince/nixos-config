{ pkgs, ... }:

{
  # GPG agent for signed commits
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };
  security.pki.installCACerts = true;

  # Install firefox
  programs.firefox = {
    enable = true;
    # Trust CAs from the system store (security.pki.certificateFiles).
    policies.Certificates.ImportEnterpriseRoots = true;
  };

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

  # nix-ld: provides /lib64/ld-linux-x86-64.so.2 shim for unpatched binaries (e.g. workerd)
  programs.nix-ld.enable = true;
}
