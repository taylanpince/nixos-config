export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"
eval "$(starship init bash)"
eval "$(direnv hook bash)"

export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$HOME/go/bin:$PATH"

# --- completion ---
if [ -r /etc/profile.d/bash_completion.sh ]; then
  source /etc/profile.d/bash_completion.sh
fi
if [ -r /etc/profile.d/fzf.sh ]; then
  source /etc/profile.d/fzf.sh
fi

# --- aliases ---
command -v eza >/dev/null && alias ls='eza -lah --group-directories-first --git' || alias ls='ls -lha'
alias dv='cd ~/development'

# --- history ---
export HISTSIZE=200000
export HISTFILESIZE=400000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r; ${PROMPT_COMMAND:-:}"

# --- zoxide ---
command -v zoxide >/dev/null && eval "$(zoxide init bash)" && alias cd='z'

alias devgo='nix develop ~/config/nixos#go'
alias devpython='nix develop ~/config/nixos#python'
alias devnode='nix develop ~/config/nixos#node'
