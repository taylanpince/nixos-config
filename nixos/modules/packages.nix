{ pkgs, ... }:

{
  # $ nix search to find packages
  environment.systemPackages = with pkgs; [
    # Development tools
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
    neovim
    tree-sitter
    codex
    claude-code
    websocat
    foundry
    solc
    aichat
    uv
    bash

    # GitHub
    git
    git-lfs
    lazygit
    gitui
    gh

    # Docker
    ctop
    lazydocker
    docker-compose # Alias to legacy name

    # Common native libs
    openssl
    zlib
    libffi
    sqlite
    bzip2
    xz

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

    # Nix ergonomics
    nix-output-monitor # `nom`
    nix-index

    # FIDO2
    pam_u2f
    libfido2

    # Hyprland UI
    waybar
    swaynotificationcenter
    dunst
    libnotify
    wl-clipboard
    cliphist
    xdg-utils
    polkit_gnome
    rofi
    wofi
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

    # GTK theming
    nwg-look
    adwaita-icon-theme
    catppuccin-gtk
    gsettings-desktop-schemas

    # Thumbnailers for file picker previews
    ffmpegthumbnailer
    evince
    webp-pixbuf-loader
    librsvg

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
    obs-studio
    obs-do
    showmethekey

    # Apps
    brave
    opencode
    slack
    obsidian
    code-cursor
    gthumb
    telegram-desktop
    kdePackages.kate
    gnome-text-editor
    zoom-us

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

    # Falcon + Kolide
    stdenv.cc.cc
    libnl
    libcap
    systemd
    util-linux
    acl
    attr
    libxml2
    libsodium
    libssh
    zstd
  ];
}
