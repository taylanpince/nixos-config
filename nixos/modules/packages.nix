{ pkgs, ... }:

let
  polycli = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "polycli";
    version = "0.1.115";

    src = pkgs.fetchurl {
      url = "https://github.com/0xPolygon/polygon-cli/releases/download/v${version}/polycli_v${version}_linux_amd64.tar.gz";
      hash = "sha256-1T73ZUSO+xqeAZbONGwCeIgyY3cUEAAi34cOR+d6Bzs=";
    };

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      install -Dm755 polycli_v${version}_linux_amd64 $out/bin/polycli
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "Polygon CLI - Swiss army knife for Polygon/EVM chains";
      homepage = "https://github.com/0xPolygon/polygon-cli";
      license = licenses.lgpl3Only;
      platforms = [ "x86_64-linux" ];
      mainProgram = "polycli";
    };
  };
in
{
  # $ nix search to find packages
  environment.systemPackages = with pkgs; [
    polycli

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
    gnupg
    pinentry-curses

    # Docker
    ctop
    lazydocker
    docker-compose # Alias to legacy name
    docker-buildx

    # Common native libs
    openssl
    zlib
    libffi
    sqlite
    bzip2
    xz

    # Bash and Terminal
    kitty
    tmux
    starship
    bash-completion
    fzf
    ripgrep
    bat
    eza
    fd
    zoxide
    glow

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
    claude-desktop-fhs # FHS variant for MCP support (from claude-desktop flake)
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

    # Audio transcription
    whisper-cpp

    # Image management
    imagemagick
    oxipng
    pngquant
    libwebp

    # PDF tools
    poppler-utils

    # Hardware
    btop
    power-profiles-daemon
    libva-utils
    ledger-live-desktop

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
