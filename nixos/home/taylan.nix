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
    settings.output.notification.on_transcription = false;
    settings.osd.enabled = false;
    # Audible cue when the mic actually opens — avoids losing first words
    # while PipeWire spins up the capture stream (waybar icon flips before
    # the audio device is ready).
    settings.audio.feedback.enabled = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Taylan Pince";
      user.email = "taylanpince@gmail.com";
    };
  };

  xdg.enable = true;

  # Open folders in Nemo (xdg-open ., "reveal in file manager" from other apps).
  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = "nemo.desktop";
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  # Manage Starship config via Home Manager (source-controlled in this repo).
  xdg.configFile."starship/starship.toml".source = ../../starship/starship.toml;

  # Desktop config. hypr/wlogout stay declarative. waybar was already excluded
  # (mutable symlinks for display switching); kitty/wofi/rofi/wob/swaync are now
  # ALSO excluded and symlinked from the checkout so theme.sh can swap theme
  # files at runtime:
  #   for a in waybar kitty wofi rofi wob swaync; do ln -sfn ~/config/$a ~/.config/$a; done
  xdg.configFile."hypr".source = ../../hypr;
  xdg.configFile."wlogout".source = ../../wlogout;

  # Media/editor configs
  xdg.configFile."mpv".source = ../../mpv;
  xdg.configFile."nvim".source = ../../nvim;

  # User scripts
  # NOTE: the repo itself is checked out at ~/config, so we must NOT have Home Manager populate
  # anything under ~/config/* (it would collide with the git checkout). Instead, install scripts to
  # ~/.config/scripts and reference them from Hyprland via ~/.config/scripts/*.
  xdg.configFile."scripts".source = ../../scripts;

  # Needed by systemd user unit (hypr-mru-tracker.service). Must be
  # executable — the unit execs it directly (ExecStart), so a read-only
  # store copy fails with EACCES ("Permission denied").
  home.file.".local/bin/hypr-mru-tracker.sh" = {
    source = ../../scripts/hypr-mru-tracker.sh;
    executable = true;
  };

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
      devkurtosis = "nix develop ~/config/nixos#kurtosis";
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

  # Trust the Wintermute local CA in the user NSS DB used by Chromium/Brave.
  # Firefox picks up the system trust via ImportEnterpriseRoots (NixOS module).
  home.activation.trustWintermuteCA =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      set -eu
      CERT=${../../certs/wintermute-root-ca.crt}
      DB="$HOME/.pki/nssdb"
      CERTUTIL=${pkgs.nss.tools}/bin/certutil
      NICK=wintermute

      mkdir -p "$DB"
      if [ ! -f "$DB/cert9.db" ]; then
        $CERTUTIL -N -d "sql:$DB" --empty-password
      fi
      $CERTUTIL -d "sql:$DB" -D -n "$NICK" 2>/dev/null || true
      $CERTUTIL -d "sql:$DB" -A -t "C,," -n "$NICK" -i "$CERT"
    '';
}
