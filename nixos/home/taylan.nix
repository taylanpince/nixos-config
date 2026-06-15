{ config, pkgs, voxtype, ... }:

{
  imports = [
    voxtype.homeManagerModules.default
  ];

  home.username = "taylan";
  home.homeDirectory = "/home/taylan";

  # Required by home-manager
  home.stateVersion = "25.11";

  # Keep this minimal to start. We can migrate your dotfiles/configs here gradually.
  programs.home-manager.enable = true;

  # Voxtype: voice-to-text on the keyboard's dedicated mic key (Alt+C chord).
  # Vulkan variant for AMD Radeon 890M iGPU. Status indicator is provided by
  # a custom/voxtype Waybar module (see waybar/config.{single,dual}); the
  # heavier GTK4 OSD is intentionally not installed.
  programs.voxtype = {
    enable = true;
    package = voxtype.packages.${pkgs.system}.vulkan;
    engine = "whisper";
    model.name = "small";
    service.enable = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Taylan Pince";
      user.email = "taylanpince@gmail.com";
    };
  };

  xdg.enable = true;

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  # Manage Starship + Kitty configs via Home Manager (source-controlled in this repo).
  xdg.configFile."starship/starship.toml".source = ../../starship/starship.toml;
  xdg.configFile."kitty/kitty.conf".source = ../../kitty/kitty.conf;

  # Desktop config (Hyprland + bars/launchers/notifications)
  # NOTE: waybar is excluded - it uses mutable symlinks for display switching
  # (managed manually via: ln -s ~/config/waybar ~/.config/waybar)
  xdg.configFile."hypr".source = ../../hypr;
  xdg.configFile."swaync".source = ../../swaync;
  xdg.configFile."rofi".source = ../../rofi;
  xdg.configFile."wofi".source = ../../wofi;
  xdg.configFile."wlogout".source = ../../wlogout;
  xdg.configFile."wob".source = ../../wob;

  # Media/editor configs
  xdg.configFile."mpv".source = ../../mpv;
  xdg.configFile."nvim".source = ../../nvim;

  # User scripts
  # NOTE: the repo itself is checked out at ~/config, so we must NOT have Home Manager populate
  # anything under ~/config/* (it would collide with the git checkout). Instead, install scripts to
  # ~/.config/scripts and reference them from Hyprland via ~/.config/scripts/*.
  xdg.configFile."scripts".source = ../../scripts;

  # Needed by systemd user unit (hypr-mru-tracker.service)
  home.file.".local/bin/hypr-mru-tracker.sh".source = ../../scripts/hypr-mru-tracker.sh;

  # pnpm supply-chain hardening (pnpm 10+). 14-day publish-age quarantine
  # + engines.node strictness. pnpm 10+ no longer reads these from .npmrc,
  # so they must live in its own config.yaml.
  xdg.configFile."pnpm/config.yaml".source = ../../pnpm/config.yaml;

  programs.bash = {
    enable = true;
    enableCompletion = true;

    sessionVariables = {
      STARSHIP_CONFIG = "$HOME/.config/starship/starship.toml";
      PNPM_HOME = "$HOME/.local/share/pnpm";
      HISTSIZE = "200000";
      HISTFILESIZE = "400000";
      HISTCONTROL = "ignoredups:erasedups";

      # npm/pnpm hardening. Set via env (not ~/.npmrc) so that file stays
      # writable for `pnpm login` / `npm login` to manage auth tokens.
      npm_config_engine_strict = "true";
      npm_config_fund = "false";
      npm_config_audit_level = "moderate";
    };

    shellAliases = {
      ls = "eza -lah --group-directories-first --git";
      dv = "cd ~/development";
      devgo = "nix develop ~/config/nixos#go";
      devpy = "nix develop ~/config/nixos#python";
      devjs = "nix develop ~/config/nixos#node";
      devops = "nix develop ~/config/nixos#pulumi";
      devrust = "nix develop ~/config/nixos#rust";
      devllm = "nix develop ~/config/nixos#llm";
      devmobile = "nix develop ~/config/nixos#mobile";
    };

    initExtra = ''
      # GPG signing
      export GPG_TTY=$(tty)

      # PATH additions
      export PATH="$PNPM_HOME:$HOME/go/bin:$HOME/.local/bin:$PATH"

      # History settings
      shopt -s histappend
      PROMPT_COMMAND="history -a; history -c; history -r; ''${PROMPT_COMMAND:-:}"

      # Zoxide cd alias
      alias cd='z'
    '';
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  # CLI tools - home-manager handles shell integration automatically
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };
  programs.eza.enable = true;
  programs.bat.enable = true;

  programs.readline = {
    enable = true;
    variables = {
      editing-mode = "emacs";
      show-all-if-ambiguous = true;
      completion-ignore-case = true;
      mark-symlinked-directories = true;
      colored-stats = true;
      completion-display-width = 0;
    };
    bindings = {
      # History search with up/down
      "\\e[A" = "history-search-backward";
      "\\e[B" = "history-search-forward";

      # Word movement (Option/Alt + Left/Right)
      "\\e[1;3D" = "backward-word";
      "\\e[1;3C" = "forward-word";
      "\\e[1;9D" = "backward-word";
      "\\e[1;9C" = "forward-word";

      # Word movement (Ctrl + Left/Right)
      "\\e[1;5D" = "backward-word";
      "\\e[1;5C" = "forward-word";

      # Home/End
      "\\e[H" = "beginning-of-line";
      "\\e[F" = "end-of-line";
      "\\e[1~" = "beginning-of-line";
      "\\e[4~" = "end-of-line";

      # Delete word (Option/Alt + Backspace)
      "\\e\\b" = "backward-kill-word";
      "\\e\\x7f" = "backward-kill-word";
    };
  };

  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar";
      # Ensure the graphical session is up.
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.hypr-mru-tracker = {
    Unit = {
      Description = "Hyprland MRU tracker for window switcher";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "%h/.local/bin/hypr-mru-tracker.sh";
      Restart = "always";
      RestartSec = 1;
      Environment = "PATH=%h/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # (home.packages declared earlier in this file with the voxtype config.)
}
