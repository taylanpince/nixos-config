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
    settings = {
      user.name = "Taylan Pince";
      user.email = "taylanpince@gmail.com";
    };
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;

    sessionVariables = {
      STARSHIP_CONFIG = "$HOME/.config/starship/starship.toml";
      PNPM_HOME = "$HOME/.local/share/pnpm";
      HISTSIZE = "200000";
      HISTFILESIZE = "400000";
      HISTCONTROL = "ignoredups:erasedups";
    };

    shellAliases = {
      ls = "eza -lah --group-directories-first --git";
      dv = "cd ~/development";
      devgo = "nix develop ~/config/nixos#go";
      devpy = "nix develop ~/config/nixos#python";
      devjs = "nix develop ~/config/nixos#node";
      devops = "nix develop ~/config/nixos#pulumi";
    };

    initExtra = ''
      # PATH additions
      export PATH="$PNPM_HOME:$HOME/go/bin:$PATH"

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

  # Let home-manager manage user packages as you decide. Starting empty.
  home.packages = [ ];
}
