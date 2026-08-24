{ pkgs, ... }:

{
  # Flatpak
  services.flatpak.enable = true;

  # gvfs backend for GUI file managers (Nemo): Trash, removable-drive/USB
  # mounting, MTP (phones), and network shares (SMB/SFTP).
  services.gvfs.enable = true;

  # BIOS Updates
  services.fwupd.enable = true;

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # mDNS / .local hostname resolution
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  # Enable sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # OBS for screen recording
  programs.obs-studio = {
    enable = true;
    plugins = [
      pkgs.obs-studio-plugins."input-overlay"
      pkgs.obs-studio-plugins.obs-pipewire-audio-capture
    ];
  };

  # make PAM unlock the keyring on login
  security.pam.services.regreet.enableGnomeKeyring = true;

  services.fprintd.enable = true;

  # Ledger hardware wallet
  hardware.ledger.enable = true;

  # Fingerprint auth for common PAM flows
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.polkit-1.fprintAuth = true;

  # Disable fingerprint for hyprlock (uses swaylock PAM service) — fprintd
  # waits ~30s for a scan before falling back to password, causing unlock delay
  security.pam.services.swaylock.fprintAuth = false;
}
