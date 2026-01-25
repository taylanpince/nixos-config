# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "bloomware";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_CA.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_CA.UTF-8";
    LC_IDENTIFICATION = "en_CA.UTF-8";
    LC_MEASUREMENT = "en_CA.UTF-8";
    LC_MONETARY = "en_CA.UTF-8";
    LC_NAME = "en_CA.UTF-8";
    LC_NUMERIC = "en_CA.UTF-8";
    LC_PAPER = "en_CA.UTF-8";
    LC_TELEPHONE = "en_CA.UTF-8";
    LC_TIME = "en_CA.UTF-8";
  };

  hardware.graphics.enable = true;
  hardware.graphics.extraPackages = with pkgs; [
    libva
    libva-vdpau-driver
    libvdpau-va-gl
  ];

  # Enable the X11 windowing system
  services.xserver.enable = true;

  # GDM and GNOME Desktop Environment
  services.displayManager.gdm.enable = false;
  services.desktopManager.gnome.enable = false;

  # Enable greetd + ReGreet
  services.greetd.enable = true;
  programs.regreet.enable = true;

  programs.regreet.settings =
    builtins.fromTOML (builtins.readFile ./greetd/regreet.toml);

  programs.regreet.extraCss =
    builtins.readFile ./greetd/regreet.css;

  environment.etc."greetd/background.png".source = ./greetd/background.png;

  # Run ReGreet inside Cage (simple + robust)
  services.greetd.settings.default_session = {
    user = "greeter";
    command = "${pkgs.cage}/bin/cage -s -mlast -- ${pkgs.regreet}/bin/regreet";
  };

  # Thunderbolt
  services.hardware.bolt.enable = true;

  # BIOS Updates
  services.fwupd.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Enable sound with pipewire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Docker
  virtualisation.docker.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.taylan = {
    isNormalUser = true;
    description = "Taylan Pince";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" ];
    packages = with pkgs; [
    #  thunderbird
    ];
  };

  # Install firefox
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = ["taylan"];
  };

  # Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true; # Electron / X11
    withUWSM = true;  # recommended: starts graphical-session.target
  };

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
  };

  services.fprintd.enable = true;

  # Enable fingerprint auth for common PAM flows
  #security.pam.services.login.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.polkit-1.fprintAuth = true;

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

  # $ nix search to find packages
  environment.systemPackages = with pkgs; [
    # Development tools
    git
    curl
    vim
    wget
    jq
    jless
    gnumake
    pkg-config
    cmake
    ninja
    unzip
    zip
    mkcert
    nssTools
    postgresql
    gh

    # Docker
    ctop
    lazydocker
    docker-compose # Alias to legacy name

    # Compilers
    gcc
    clang
    binutils

    # Common native libs
    openssl
    zlib
    libffi
    sqlite
    bzip2
    xz

    # JS Tooling
    yarn
    nodejs_22
    nodePackages.pnpm

    # Go Tooling
    go
    gopls
    delve
    gotools
    golangci-lint

    # Python Tooling
    python3
    python3Packages.pip
    python3Packages.virtualenv
    python3Packages.setuptools
    python3Packages.wheel

    # Bash and Terminal
    kitty
    starship
    bash-completion
    fzf
    ripgrep
    bat
    eza
    fd
    zoxide

    # Hyprland UI
    waybar
    dunst
    libnotify
    wl-clipboard
    cliphist
    xdg-utils
    polkit_gnome
    rofi
    hyprlock
    hypridle
    pavucontrol
    pulseaudio
    networkmanagerapplet
    wireplumber
    hyprpaper
    coreutils
    findutils
    brightnessctl
    bluez
    blueman
    glib # provides gsettings
    wlogout
    socat
    yazi

    # Fingerprint support
    fprintd
    libfprint

    # Key bindings
    wob
    brightnessctl

    # Screen recording
    grim
    slurp
    swappy
    satty
    wf-recorder

    # Apps
    brave
    opencode
    slack
    obsidian
    code-cursor
    gthumb

    # Video
    mpv
    ffmpeg-full
    celluloid

    # Image management
    imagemagick
    oxipng
    pngquant
    libwebp

    # Hardware
    btop
    power-profiles-daemon
    libva-utils
  ];

  fonts.packages = with pkgs; [
    inter
    nerd-fonts.jetbrains-mono
  ];

  services.power-profiles-daemon.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
